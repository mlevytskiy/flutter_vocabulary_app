import type { Env } from "../env";
import { jsonResponse } from "../http";
import { logEvent } from "../log";
import type { RouteContext, RouteDefinition } from "../routing";
import { isLiveSession } from "./store";
import {
  ID_PATTERN,
  MAX_ENTRIES,
  MAX_FIELD_CHARS,
  MAX_SESSION_JSON_BYTES,
  isCellField,
  isId,
  isRev,
  type CellField,
} from "./types";

/**
 * The shared page's editing API (good-looking-web, ADR-0004). Public: the link
 * is the credential (sad §8). Every write raises the session revision and
 * stamps the cells it changed with it, inside one D1 batch (one transaction),
 * and applies only while the cell is still at the revision the page saw -- so
 * a save either lands or comes back as a conflict, never lost (AC-11).
 *
 * Errors are `{ error, code }`: `error` in plain words for the partner, `code`
 * for the script (sad §8).
 */

/** A page request carries one cell at most; anything this big is not from the page. */
const MAX_PAGE_BODY_BYTES = 16 * 1024;

export function pageError(status: number, code: string, error: string, extra: Record<string, unknown> = {}): Response {
  return jsonResponse({ error, code, ...extra }, status);
}

/** Unknown and expired ids answer the same (AC-32). */
export function gone(): Response {
  return pageError(404, "gone", "This word list is gone.");
}

export function badRequest(error: string): Response {
  return pageError(400, "bad_request", error);
}

type Body = { ok: true; body: Record<string, unknown> } | { ok: false; response: Response };

export async function readPageBody(request: Request): Promise<Body> {
  const text = await request.text();
  if (text.length > MAX_PAGE_BODY_BYTES) {
    return { ok: false, response: pageError(413, "bad_request", "The request is too large.") };
  }
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return { ok: false, response: badRequest("The body must be JSON.") };
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return { ok: false, response: badRequest("The body must be a JSON object.") };
  }
  return { ok: true, body: body as Record<string, unknown> };
}

const FIELD_NAMES: Record<CellField, string> = {
  word: "word",
  translation: "translation",
  definition: "definition",
};

/** AC-10: the partner is told which field and by how much; nothing is written. */
export function fieldTooLong(field: CellField, value: string): Response | null {
  if (value.length <= MAX_FIELD_CHARS) return null;
  const overflow = value.length - MAX_FIELD_CHARS;
  return pageError(
    422,
    "field_too_long",
    `The ${FIELD_NAMES[field]} is ${overflow} character${overflow === 1 ? "" : "s"} too long ` +
      `(at most ${MAX_FIELD_CHARS}).`,
    { field, limit: MAX_FIELD_CHARS, overflow }
  );
}

/** AC-38: the list would go over the most text a session may hold. */
export function listFull(): Response {
  return pageError(422, "list_full", "The list is full: it cannot hold more text.", {
    limit: MAX_SESSION_JSON_BYTES,
  });
}

/**
 * UTF-8 bytes of every live cell of session ?1 -- the 256 KB the session may
 * hold (AC-38). `CAST(... AS BLOB)` makes `length` count bytes, not characters.
 */
const LIVE_TEXT_BYTES = `(SELECT coalesce(sum(
    length(CAST(s.word AS BLOB)) + length(CAST(s.translation AS BLOB)) + length(CAST(s.definition AS BLOB))
  ), 0) FROM rows AS s WHERE s.session_id = ?1 AND s.deleted_at_rev IS NULL)`;

/** When a cell may be written: still at the revision the page saw, or (autofill) still empty. */
export type CellGuard = { baseRev: number } | { onlyIfEmpty: true };

export type CellWrite =
  | { outcome: "saved"; rev: number }
  | { outcome: "conflict"; value: string; rev: number }
  | { outcome: "deleted" }
  | { outcome: "unknown_row" }
  | { outcome: "list_full" };

/**
 * Writes one cell of a live row when `guard` still holds and the session stays
 * within 256 KB (a write that shrinks the text always may). The first
 * statement raises the session revision only when every condition holds; the
 * second writes the cell at that revision under the same conditions -- the
 * batch is one transaction, so the two agree. `source_id` is never touched
 * (AC-34). The value is stored as given: escaping happens on output (AC-33).
 */
export async function writeCell(
  env: Env,
  sessionId: string,
  rowId: string,
  field: CellField,
  value: string,
  guard: CellGuard
): Promise<CellWrite> {
  const guardSql = "baseRev" in guard ? `r.${field}_rev = ?4` : `r.${field} = ''`;
  const target = `EXISTS (SELECT 1 FROM rows AS r
    WHERE r.session_id = ?1 AND r.id = ?2 AND r.deleted_at_rev IS NULL AND ${guardSql}
      AND (length(CAST(?3 AS BLOB)) <= length(CAST(r.${field} AS BLOB))
        OR ${LIVE_TEXT_BYTES} - length(CAST(r.${field} AS BLOB)) + length(CAST(?3 AS BLOB)) <= ${MAX_SESSION_JSON_BYTES}))`;
  const params: (string | number)[] = "baseRev" in guard ? [sessionId, rowId, value, guard.baseRev] : [sessionId, rowId, value];

  const [, updated, session] = await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1 WHERE id = ?1 AND ${target}`).bind(...params),
    env.DB.prepare(
      `UPDATE rows SET ${field} = ?3, ${field}_rev = (SELECT rev FROM sessions WHERE id = ?1)
       WHERE session_id = ?1 AND id = ?2 AND ${target}`
    ).bind(...params),
    env.DB.prepare(`SELECT rev FROM sessions WHERE id = ?1`).bind(sessionId),
  ]);
  if (updated.meta.changes === 1) {
    return { outcome: "saved", rev: (session.results as { rev: number }[])[0].rev };
  }

  // Not written: read the row once to say why. Revisions only go up, so a
  // cell seen past the guard stays past it.
  const row = await env.DB.prepare(
    `SELECT ${field} AS value, ${field}_rev AS rev, deleted_at_rev FROM rows WHERE session_id = ?1 AND id = ?2`
  )
    .bind(sessionId, rowId)
    .first<{ value: string; rev: number; deleted_at_rev: number | null }>();
  if (!row) return { outcome: "unknown_row" };
  if (row.deleted_at_rev !== null) return { outcome: "deleted" };
  const guardHolds = "baseRev" in guard ? row.rev === guard.baseRev : row.value === "";
  if (!guardHolds) return { outcome: "conflict", value: row.value, rev: row.rev };
  return { outcome: "list_full" };
}

/** The answer to a cell write that did not land, shared by save and autofill. */
export function refusedCellWrite(result: Exclude<CellWrite, { outcome: "saved" }>, field: CellField): Response {
  switch (result.outcome) {
    case "conflict":
      return pageError(409, "conflict", "Someone else changed this cell meanwhile.", {
        field,
        value: result.value,
        rev: result.rev,
      });
    case "deleted":
      return pageError(409, "conflict", "This row was deleted meanwhile.", { field, deleted: true });
    case "unknown_row":
      return pageError(404, "unknown_row", "There is no such row in this list.");
    case "list_full":
      return listFull();
  }
}

/**
 * POST /s/:id/cells -- public. `{ rowId, field, value, baseRev }` ->
 * `200 { rowId, field, rev }`, or `{ error, code }`: `409 conflict` with the
 * saved `value` and `rev` (or `deleted: true`), `422 field_too_long` /
 * `list_full`, `404 unknown_row` / `gone`, `400 bad_request`.
 */
async function handleSaveCell({ request, env, params }: RouteContext): Promise<Response> {
  const read = await readPageBody(request);
  if (!read.ok) return read.response;
  const { rowId, field, value, baseRev } = read.body;
  if (!isId(rowId)) return badRequest("`rowId` must be a row id.");
  if (!isCellField(field)) return badRequest("`field` must be one of: word, translation, definition.");
  if (typeof value !== "string") return badRequest("`value` must be a string.");
  if (!isRev(baseRev)) return badRequest("`baseRev` must be a non-negative integer.");

  const tooLong = fieldTooLong(field, value);
  if (tooLong) {
    logEvent("cell rejected", { session: params.id, row: rowId, field, code: "field_too_long" });
    return tooLong;
  }
  if (!(await isLiveSession(env, params.id))) return gone();

  const result = await writeCell(env, params.id, rowId, field, value, { baseRev });
  if (result.outcome === "saved") {
    logEvent("cell saved", { session: params.id, row: rowId, field, rev: result.rev });
    return jsonResponse({ rowId, field, rev: result.rev });
  }
  logEvent(result.outcome === "list_full" ? "cell rejected" : "cell conflict", {
    session: params.id,
    row: rowId,
    field,
    code: result.outcome,
  });
  return refusedCellWrite(result, field);
}

interface RowRecord {
  word: string;
  word_rev: number;
  translation: string;
  translation_rev: number;
  definition: string;
  definition_rev: number;
  deleted_at_rev: number | null;
}

function readRow(env: Env, sessionId: string, rowId: string): Promise<RowRecord | null> {
  return env.DB.prepare(
    `SELECT word, word_rev, translation, translation_rev, definition, definition_rev, deleted_at_rev
     FROM rows WHERE session_id = ?1 AND id = ?2`
  )
    .bind(sessionId, rowId)
    .first<RowRecord>();
}

/** A row as the page needs it to restore it or re-base on it after a refusal. */
function rowState(rowId: string, row: RowRecord) {
  return {
    rowId,
    word: row.word,
    translation: row.translation,
    definition: row.definition,
    revs: { word: row.word_rev, translation: row.translation_rev, definition: row.definition_rev },
  };
}

/**
 * POST /s/:id/rows -- public. `{ rowId, field, value }`: the page's plus button
 * made the row with its own id, and it is stored when its first cell gets text
 * (AC-13), at the end of the table, every cell at the new revision.
 * -> `200 { rowId, rev }`, or `422 rows_full` at 500 rows (AC-14), `422
 * field_too_long` / `list_full`, `409 conflict` when the id is taken.
 * Repeating an add that already landed answers the same `200`.
 */
async function handleAddRow({ request, env, params }: RouteContext): Promise<Response> {
  const read = await readPageBody(request);
  if (!read.ok) return read.response;
  const { rowId, field, value } = read.body;
  if (!isId(rowId)) return badRequest("`rowId` must be a row id.");
  if (!isCellField(field)) return badRequest("`field` must be one of: word, translation, definition.");
  if (typeof value !== "string" || value === "") {
    return badRequest("`value` must be the text of the row's first cell.");
  }
  const tooLong = fieldTooLong(field, value);
  if (tooLong) return tooLong;
  if (!(await isLiveSession(env, params.id))) return gone();

  // Same conditions in both statements, one transaction: the revision goes up
  // only when the row goes in.
  const target = `NOT EXISTS (SELECT 1 FROM rows AS r WHERE r.session_id = ?1 AND r.id = ?2)
    AND (SELECT count(*) FROM rows AS r WHERE r.session_id = ?1 AND r.deleted_at_rev IS NULL) < ${MAX_ENTRIES}
    AND ${LIVE_TEXT_BYTES} + length(CAST(?3 AS BLOB)) <= ${MAX_SESSION_JSON_BYTES}`;
  const [, inserted, session] = await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1 WHERE id = ?1 AND ${target}`).bind(params.id, rowId, value),
    env.DB.prepare(
      `INSERT INTO rows (session_id, id, position, ${field}, word_rev, translation_rev, definition_rev)
       SELECT ?1, ?2, (SELECT coalesce(max(position), -1) + 1 FROM rows WHERE session_id = ?1), ?3, s.rev, s.rev, s.rev
       FROM sessions AS s WHERE s.id = ?1 AND ${target}`
    ).bind(params.id, rowId, value),
    env.DB.prepare(`SELECT rev FROM sessions WHERE id = ?1`).bind(params.id),
  ]);
  if (inserted.meta.changes === 1) {
    const rev = (session.results as { rev: number }[])[0].rev;
    logEvent("row added", { session: params.id, row: rowId, rev });
    return jsonResponse({ rowId, rev });
  }

  const existing = await readRow(env, params.id, rowId);
  if (existing) {
    // A retry of an add that landed: the same first cell, untouched since.
    const revs = [existing.word_rev, existing.translation_rev, existing.definition_rev];
    const untouched = revs.every((rev) => rev === revs[0]) && existing[field] === value;
    if (existing.deleted_at_rev === null && untouched) return jsonResponse({ rowId, rev: existing.word_rev });
    return pageError(409, "conflict", "This row id is already taken.", {
      ...(existing.deleted_at_rev === null ? rowState(rowId, existing) : { rowId, deleted: true }),
    });
  }
  const live = await env.DB.prepare(`SELECT count(*) AS n FROM rows WHERE session_id = ?1 AND deleted_at_rev IS NULL`)
    .bind(params.id)
    .first<{ n: number }>();
  if ((live?.n ?? 0) >= MAX_ENTRIES) {
    logEvent("row rejected", { session: params.id, code: "rows_full" });
    return pageError(422, "rows_full", `The list is full: it holds at most ${MAX_ENTRIES} rows.`, {
      limit: MAX_ENTRIES,
    });
  }
  logEvent("row rejected", { session: params.id, code: "list_full" });
  return listFull();
}

/**
 * POST /s/:id/rows/delete -- public. `{ rowId, revs: { word, translation,
 * definition } }`, sent when the page's 5-second Undo ends (AC-15). Applies
 * only while all three cells are at those revisions; otherwise `409 conflict`
 * with the row as it is now, and the row stays (AC-15b). -> `200 { rowId, rev }`
 * (`rev` is the delete's revision); a row already deleted answers `200` too.
 */
async function handleDeleteRow({ request, env, params }: RouteContext): Promise<Response> {
  const read = await readPageBody(request);
  if (!read.ok) return read.response;
  const { rowId, revs } = read.body;
  if (!isId(rowId)) return badRequest("`rowId` must be a row id.");
  const r = (typeof revs === "object" && revs !== null ? revs : {}) as Record<string, unknown>;
  if (!isRev(r.word) || !isRev(r.translation) || !isRev(r.definition)) {
    return badRequest("`revs` must hold the word, translation and definition revisions.");
  }
  if (!(await isLiveSession(env, params.id))) return gone();

  const target = `EXISTS (SELECT 1 FROM rows AS r WHERE r.session_id = ?1 AND r.id = ?2 AND r.deleted_at_rev IS NULL
    AND r.word_rev = ?3 AND r.translation_rev = ?4 AND r.definition_rev = ?5)`;
  const bind = [params.id, rowId, r.word, r.translation, r.definition];
  const [, deleted] = await env.DB.batch([
    env.DB.prepare(`UPDATE sessions SET rev = rev + 1 WHERE id = ?1 AND ${target}`).bind(...bind),
    env.DB.prepare(
      `UPDATE rows SET deleted_at_rev = (SELECT rev FROM sessions WHERE id = ?1)
       WHERE session_id = ?1 AND id = ?2 AND ${target}`
    ).bind(...bind),
  ]);

  const row = await readRow(env, params.id, rowId);
  if (!row) return pageError(404, "unknown_row", "There is no such row in this list.");
  if (row.deleted_at_rev !== null) {
    if (deleted.meta.changes === 1) logEvent("row deleted", { session: params.id, row: rowId, rev: row.deleted_at_rev });
    return jsonResponse({ rowId, rev: row.deleted_at_rev });
  }
  logEvent("row delete refused", { session: params.id, row: rowId });
  return pageError(409, "conflict", "Someone changed this row meanwhile, so it was not deleted.", rowState(rowId, row));
}

export const editRoutes: RouteDefinition[] = [
  {
    method: "POST",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/cells$`),
    public: true,
    pageWrite: true,
    handler: handleSaveCell,
  },
  {
    method: "POST",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/rows$`),
    public: true,
    pageWrite: true,
    handler: handleAddRow,
  },
  {
    method: "POST",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/rows/delete$`),
    public: true,
    pageWrite: true,
    handler: handleDeleteRow,
  },
];
