import type { Env } from "../env";
import { isAllowedMediaType } from "../http";
import { matchPlaces } from "../story/word-check";
import { isId } from "./types";

/**
 * Film dialogues of a published session (get-words-from-subtitles-improvment,
 * ADR-0005; D1 tables in `migrations/0005_film_dialogues.sql`). A dialogue is a
 * few lines with the session's rows it is about. This file holds the bounds and
 * the D1 writes; publish and republish call it with the rows' ids.
 */

/** Same bounds as the subtitle reply check (`src/subtitles/dialogues.ts`). */
export const MAX_DIALOGUES_PER_IMPORT = 10;
export const MAX_DIALOGUE_LINES = 8;
export const MAX_DIALOGUE_LINE_CHARS = 200;
/** A publish carries every import's dialogues; this bounds the sum. The body limit bounds the bytes. */
export const MAX_DIALOGUES_PER_SESSION = 100;

/** The import a dialogue came from when the app does not say (a first publish). */
const NO_IMPORT = "";

export interface DeclaredDialogue {
  id: string;
  importId: string;
  lines: string[];
  /** Indexes into the entries list as the app sent it. */
  entries: number[];
  /** The scene picture, declared like a photo; its bytes follow. */
  pictureMediaType: string | null;
}

export type ParsedDialogues = { ok: true; dialogues: DeclaredDialogue[] } | { ok: false; error: string };

/**
 * Validates the optional `dialogues` of a publish. `keptEntryIndexes` are the
 * positions, in the list the app sent, of the entries that were kept (blank
 * rows are dropped); a dialogue's `entries` must name kept ones. Absent or
 * null is no dialogues, so older apps publish as before.
 */
export function parseDialogues(value: unknown, keptEntryIndexes: readonly number[]): ParsedDialogues {
  if (value === undefined || value === null) return { ok: true, dialogues: [] };
  if (!Array.isArray(value)) return { ok: false, error: "`dialogues` must be an array" };
  if (value.length > MAX_DIALOGUES_PER_SESSION) {
    return { ok: false, error: `At most ${MAX_DIALOGUES_PER_SESSION} dialogues per session` };
  }
  const kept = new Set(keptEntryIndexes);
  const dialogues: DeclaredDialogue[] = [];
  const perImport = new Map<string, number>();
  for (const item of value) {
    if (typeof item !== "object" || item === null) {
      return { ok: false, error: "Each dialogue must be an object with `id`, `lines` and `entries`" };
    }
    const record = item as Record<string, unknown>;
    if (!isId(record.id)) return { ok: false, error: "A dialogue `id` must be 1-64 letters, digits or dashes" };
    if (dialogues.some((d) => d.id === record.id)) return { ok: false, error: "Each dialogue needs a distinct `id`" };

    let importId = NO_IMPORT;
    if (record.importId !== undefined && record.importId !== null) {
      if (!isId(record.importId)) {
        return { ok: false, error: "A dialogue `importId` must be 1-64 letters, digits or dashes" };
      }
      importId = record.importId;
    }
    const count = (perImport.get(importId) ?? 0) + 1;
    if (count > MAX_DIALOGUES_PER_IMPORT) {
      return { ok: false, error: `At most ${MAX_DIALOGUES_PER_IMPORT} dialogues per import` };
    }
    perImport.set(importId, count);

    const lines = record.lines;
    if (!Array.isArray(lines) || lines.length < 1 || lines.length > MAX_DIALOGUE_LINES) {
      return { ok: false, error: `A dialogue needs 1-${MAX_DIALOGUE_LINES} lines` };
    }
    for (const line of lines) {
      if (typeof line !== "string" || line.trim() === "" || line.length > MAX_DIALOGUE_LINE_CHARS) {
        return { ok: false, error: `Each dialogue line must be 1-${MAX_DIALOGUE_LINE_CHARS} characters` };
      }
    }

    const entries = record.entries;
    if (!Array.isArray(entries) || entries.length === 0) {
      return { ok: false, error: "A dialogue needs at least one entry" };
    }
    for (const index of entries) {
      if (typeof index !== "number" || !Number.isInteger(index) || !kept.has(index)) {
        return { ok: false, error: "A dialogue entry must be the position of an entry in `entries`" };
      }
    }

    let pictureMediaType: string | null = null;
    if (record.picture !== undefined && record.picture !== null) {
      const picture = record.picture as Record<string, unknown>;
      if (typeof picture !== "object" || !isAllowedMediaType(picture.mediaType)) {
        return { ok: false, error: "A dialogue picture `mediaType` must be one of: image/jpeg, image/png, image/webp" };
      }
      pictureMediaType = picture.mediaType;
    }

    dialogues.push({
      id: record.id,
      importId,
      lines: [...(lines as string[])],
      entries: [...new Set(entries as number[])],
      pictureMediaType,
    });
  }
  return { ok: true, dialogues };
}

const INSERT_DIALOGUE = `INSERT INTO dialogues
  (session_id, id, position, lines_json, import_id, added_rev, picture_media_type)
  VALUES (?1, ?2, ?3, ?4, ?5, (SELECT rev FROM sessions WHERE id = ?1), ?6)`;
// An append puts its dialogues after the ones the session already has; each insert looks at what the
// one before it wrote, so the order holds without reading first.
const INSERT_DIALOGUE_AFTER_EXISTING = `INSERT INTO dialogues
  (session_id, id, position, lines_json, import_id, added_rev, picture_media_type)
  VALUES (?1, ?2, (SELECT coalesce(max(position), -1) + 1 FROM dialogues WHERE session_id = ?1), ?3, ?4,
    (SELECT rev FROM sessions WHERE id = ?1), ?5)`;
const INSERT_DIALOGUE_WORD = `INSERT INTO dialogue_words (session_id, dialogue_id, row_id) VALUES (?1, ?2, ?3)`;

/**
 * Statements storing `dialogues` for a session whose rows were just inserted.
 * `rowIdByEntryIndex` maps an app-side entry position to its row id. They run
 * in the publish batch, after the session's revision is set, so `added_rev` is
 * the revision of that publish. With `afterExisting` (an append) the positions
 * continue after the session's current dialogues instead of starting at 0.
 */
export function insertDialogueStatements(
  env: Env,
  sessionId: string,
  dialogues: readonly DeclaredDialogue[],
  rowIdByEntryIndex: ReadonlyMap<number, string>,
  { afterExisting = false }: { afterExisting?: boolean } = {}
): D1PreparedStatement[] {
  return dialogues.flatMap((dialogue, position) => [
    afterExisting
      ? env.DB.prepare(INSERT_DIALOGUE_AFTER_EXISTING).bind(
          sessionId,
          dialogue.id,
          JSON.stringify(dialogue.lines),
          dialogue.importId,
          dialogue.pictureMediaType
        )
      : env.DB.prepare(INSERT_DIALOGUE).bind(
          sessionId,
          dialogue.id,
          position,
          JSON.stringify(dialogue.lines),
          dialogue.importId,
          dialogue.pictureMediaType
        ),
    ...dialogue.entries.map((index) =>
      env.DB.prepare(INSERT_DIALOGUE_WORD).bind(sessionId, dialogue.id, rowIdByEntryIndex.get(index))
    ),
  ]);
}

/** A republish drops the old dialogues with the old rows (ADR-0008). Words go first, whatever the FK pragma says. */
export function deleteDialogueStatements(env: Env, sessionId: string): D1PreparedStatement[] {
  return [
    env.DB.prepare(`DELETE FROM dialogue_words WHERE session_id = ?1`).bind(sessionId),
    env.DB.prepare(`DELETE FROM dialogues WHERE session_id = ?1`).bind(sessionId),
  ];
}

/** The R2 key of a dialogue's scene picture, under its session's prefix like the photos. */
export const pictureKey = (sessionId: string, dialogueId: string) =>
  `sessions/${sessionId}/dialogues/${dialogueId}/picture`;

/** Whether this session already has an import with this id, or a dialogue with any of these ids. */
export async function isRepeatAppend(
  env: Env,
  sessionId: string,
  importId: string,
  dialogueIds: readonly string[]
): Promise<boolean> {
  const imported = await env.DB.prepare(`SELECT 1 AS found FROM dialogue_imports WHERE session_id = ?1 AND import_id = ?2`)
    .bind(sessionId, importId)
    .all();
  if (imported.results.length > 0) return true;
  for (const dialogueId of dialogueIds) {
    const known = await env.DB.prepare(`SELECT 1 AS found FROM dialogues WHERE session_id = ?1 AND id = ?2`)
      .bind(sessionId, dialogueId)
      .all();
    if (known.results.length > 0) return true;
  }
  return false;
}

/** One word of a dialogue as the page and the change feed show it (the places are per line). */
export interface DialogueWordView {
  rowId: string;
  word: string;
  translation: string;
  definition: string;
  places: [number, number][][];
}

/** A dialogue as the page renders it and the change feed sends it: one shape, so the script can re-render from feed data. */
export interface DialogueView {
  id: string;
  position: number;
  lines: string[];
  picture: { mediaType: string | null; rev: number } | null;
  words: DialogueWordView[];
}

/** A dialogue as read from D1, before its words are matched. */
export interface DialogueRecord {
  id: string;
  position: number;
  lines: string[];
  pictureArrivedRev: number | null;
  pictureMediaType: string | null;
}

/**
 * The dialogue's current state, or null when no linked word is left (AC-11, AC-26): a word stays
 * only where it still appears in some line (checked line by line, a phrase never spans two lines),
 * with its places per line (AC-05).
 */
export function presentDialogue(
  dialogue: DialogueRecord,
  rows: readonly { row_id: string; word: string; translation: string; definition: string }[]
): DialogueView | null {
  const words: DialogueWordView[] = [];
  for (const row of rows) {
    const places = dialogue.lines.map((line) => matchPlaces(line, row.word));
    if (places.every((inLine) => inLine.length === 0)) continue;
    words.push({ rowId: row.row_id, word: row.word, translation: row.translation, definition: row.definition, places });
  }
  if (words.length === 0) return null;
  return {
    id: dialogue.id,
    position: dialogue.position,
    lines: dialogue.lines,
    picture:
      dialogue.pictureArrivedRev === null
        ? null
        : { mediaType: dialogue.pictureMediaType, rev: dialogue.pictureArrivedRev },
    words,
  };
}
