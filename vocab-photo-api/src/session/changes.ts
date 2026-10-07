import type { Env } from "../env";
import { jsonResponse } from "../http";
import type { RouteContext, RouteDefinition } from "../routing";
import { presentDialogue } from "./dialogues";
import { isLiveSession } from "./store";
import { CELL_FIELDS, ID_PATTERN, type CellField } from "./types";

/**
 * The change feed the shared page polls (ADR-0005): everything of a session
 * whose revision is above the page's cursor, read in one D1 batch so the
 * answer is one consistent snapshot. Public and not rate-limited -- polling is
 * a read (sad §8, AC-35).
 *
 * A row whose three cells are all above the cursor goes out whole (`rows`):
 * every add stamps all three with its revision, so this covers each row added
 * after the cursor, even one edited since; an old row whose three cells were
 * all edited is sent whole too, which the page applies the same way. Any other
 * live row sends only its changed cells (`cells`); a deleted one sends a
 * tombstone (`deleted`) -- writes to a deleted row are refused, so a tombstone
 * has no later cell changes. `sources` are photo slots whose bytes arrived.
 *
 * Film dialogues (get-words-from-subtitles-improvment, AC-20/AC-21): a dialogue
 * is sent whole, in its current state, when it was added after the cursor, its
 * scene picture arrived after it, or any row linked to it changed after it.
 * Its words are the linked rows still alive whose word still appears in a line
 * (the AC-05 rule), each with its bold places per line. A changed dialogue left
 * with no words goes out as `removedDialogues`. The keys `dialogues` and
 * `removedDialogues` are present only when non-empty, so an answer without
 * dialogue changes is exactly what it was before.
 */

interface ChangedRow {
  id: string;
  position: number;
  source_id: string | null;
  word: string;
  word_rev: number;
  translation: string;
  translation_rev: number;
  definition: string;
  definition_rev: number;
  deleted_at_rev: number | null;
}

interface ArrivedSource {
  id: string;
  ord: number;
  media_type: string;
  arrived_rev: number;
}

interface ChangedDialogue {
  id: string;
  position: number;
  lines_json: string;
  picture_arrived_rev: number | null;
  picture_media_type: string | null;
}

interface DialogueWordRow {
  dialogue_id: string;
  row_id: string;
  word: string;
  translation: string;
  definition: string;
}

interface SessionRevs {
  rev: number;
  replaced_rev: number;
  expires_at: string;
}

const SINCE_RE = /^(0|[1-9][0-9]{0,15})$/;

// A dialogue the cursor has not seen: new, its picture arrived, or a linked row changed. The row
// test is the expression of rows_changed_idx, as above.
const DIALOGUE_CHANGED = `d.session_id = ?1 AND (
  d.added_rev > ?2
  OR coalesce(d.picture_arrived_rev, 0) > ?2
  OR EXISTS (
    SELECT 1 FROM dialogue_words dw JOIN rows r ON r.session_id = dw.session_id AND r.id = dw.row_id
    WHERE dw.session_id = d.session_id AND dw.dialogue_id = d.id
      AND max(r.word_rev, r.translation_rev, r.definition_rev, coalesce(r.deleted_at_rev, 0)) > ?2
  )
)`;

function readFeed(env: Env, sessionId: string, since: number) {
  return env.DB.batch([
    env.DB.prepare(`SELECT rev, replaced_rev, expires_at FROM sessions WHERE id = ?1`).bind(sessionId),
    // The exact expression of rows_changed_idx, so the read uses the index.
    env.DB.prepare(
      `SELECT id, position, source_id, word, word_rev, translation, translation_rev,
              definition, definition_rev, deleted_at_rev
       FROM rows
       WHERE session_id = ?1
         AND max(word_rev, translation_rev, definition_rev, coalesce(deleted_at_rev, 0)) > ?2
       ORDER BY position`
    ).bind(sessionId, since),
    env.DB.prepare(
      `SELECT id, ord, media_type, arrived_rev FROM sources
       WHERE session_id = ?1 AND kind = 'photo' AND status = 'arrived' AND arrived_rev > ?2
       ORDER BY ord`
    ).bind(sessionId, since),
    env.DB.prepare(
      `SELECT d.id, d.position, d.lines_json, d.picture_arrived_rev, d.picture_media_type
       FROM dialogues d WHERE ${DIALOGUE_CHANGED} ORDER BY d.position`
    ).bind(sessionId, since),
    // The words of those dialogues: linked rows still alive, read in the same batch as the rows.
    env.DB.prepare(
      `SELECT dw.dialogue_id, r.id AS row_id, r.word, r.translation, r.definition
       FROM dialogue_words dw
       JOIN dialogues d ON d.session_id = dw.session_id AND d.id = dw.dialogue_id
       JOIN rows r ON r.session_id = dw.session_id AND r.id = dw.row_id
       WHERE ${DIALOGUE_CHANGED} AND r.deleted_at_rev IS NULL
       ORDER BY r.position`
    ).bind(sessionId, since),
  ]);
}

/**
 * Each changed dialogue as its current state, or its id when no linked word is left (AC-11, AC-26):
 * a word stays only where it still appears in some line, with its places per line.
 */
function* dialogueChanges(changed: ChangedDialogue[], wordsByDialogue: Map<string, DialogueWordRow[]>) {
  for (const dialogue of changed) {
    yield (
      presentDialogue(
        {
          id: dialogue.id,
          position: dialogue.position,
          lines: JSON.parse(dialogue.lines_json) as string[],
          pictureArrivedRev: dialogue.picture_arrived_rev,
          pictureMediaType: dialogue.picture_media_type,
        },
        wordsByDialogue.get(dialogue.id) ?? []
      ) ?? dialogue.id
    );
  }
}

async function handleChanges({ url, env, params }: RouteContext): Promise<Response> {
  const sinceParam = url.searchParams.get("since") ?? "";
  if (!SINCE_RE.test(sinceParam) || !Number.isSafeInteger(Number(sinceParam))) {
    return jsonResponse({ error: "since must be a revision (a whole number from 0).", code: "bad_request" }, 400);
  }
  const since = Number(sinceParam);
  const gone = () => jsonResponse({ error: "This word list is gone.", code: "gone" }, 404);

  let [sessionRead, rowsRead, sourcesRead, dialoguesRead, dialogueWordsRead] = await readFeed(env, params.id, since);
  let session = (sessionRead.results as SessionRevs[])[0];
  if (!session) {
    // A link still only in KV: loading it imports it into D1 (T4).
    if (!(await isLiveSession(env, params.id))) return gone();
    [sessionRead, rowsRead, sourcesRead, dialoguesRead, dialogueWordsRead] = await readFeed(env, params.id, since);
    session = (sessionRead.results as SessionRevs[])[0];
    if (!session) return gone();
  }
  if (Date.parse(session.expires_at) <= Date.now()) return gone();

  // A cursor from before a republish, or one this list never reached, is from
  // another version of the list: the page reloads it whole (ADR-0008).
  if (since < session.replaced_rev || since > session.rev) {
    return jsonResponse({ rev: session.rev, reload: true });
  }

  const cells: { rowId: string; field: CellField; value: string; rev: number }[] = [];
  const rows: unknown[] = [];
  const deleted: { rowId: string; rev: number }[] = [];
  for (const row of rowsRead.results as ChangedRow[]) {
    if (row.deleted_at_rev !== null) {
      deleted.push({ rowId: row.id, rev: row.deleted_at_rev });
    } else if (Math.min(row.word_rev, row.translation_rev, row.definition_rev) > since) {
      rows.push({
        rowId: row.id,
        position: row.position,
        sourceId: row.source_id,
        word: row.word,
        translation: row.translation,
        definition: row.definition,
        revs: { word: row.word_rev, translation: row.translation_rev, definition: row.definition_rev },
      });
    } else {
      for (const field of CELL_FIELDS) {
        const rev = row[`${field}_rev`];
        if (rev > since) cells.push({ rowId: row.id, field, value: row[field], rev });
      }
    }
  }
  const sources = (sourcesRead.results as ArrivedSource[]).map((source) => ({
    id: source.id,
    ord: source.ord,
    mediaType: source.media_type,
    rev: source.arrived_rev,
  }));
  const wordsByDialogue = new Map<string, DialogueWordRow[]>();
  for (const word of dialogueWordsRead.results as DialogueWordRow[]) {
    const list = wordsByDialogue.get(word.dialogue_id) ?? [];
    list.push(word);
    wordsByDialogue.set(word.dialogue_id, list);
  }
  const dialogues: unknown[] = [];
  const removedDialogues: string[] = [];
  for (const dialogue of dialogueChanges(dialoguesRead.results as ChangedDialogue[], wordsByDialogue)) {
    if (typeof dialogue === "string") removedDialogues.push(dialogue);
    else dialogues.push(dialogue);
  }
  return jsonResponse({
    rev: session.rev,
    cells,
    rows,
    deleted,
    sources,
    ...(dialogues.length > 0 ? { dialogues } : {}),
    ...(removedDialogues.length > 0 ? { removedDialogues } : {}),
  });
}

export const changesRoutes: RouteDefinition[] = [
  {
    method: "GET",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/changes$`),
    public: true,
    handler: handleChanges,
  },
];
