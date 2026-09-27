import { lookUpCached } from "../define";
import { jsonResponse } from "../http";
import { logEvent } from "../log";
import type { RouteContext, RouteDefinition } from "../routing";
import { badRequest, gone, pageError, readPageBody, refusedCellWrite, writeCell } from "../session/edit";
import { isLiveSession } from "../session/store";
import { ID_PATTERN, MAX_FIELD_CHARS, isId } from "../session/types";
import { takeAutofillUnit } from "./meter";

/**
 * POST /s/:id/define -- public, a page write. `{ rowId }` -> the row's
 * Definition cell filled from the dictionary: `200 { rowId, field, value, rev }`.
 * Or `{ error, code }`:
 *   429 autofill_paused `{ reason: "page" | "all_pages", resumesAt }` (AC-18, AC-18b)
 *   422 nothing_found -- the unit stays spent (AC-20)
 *   409 conflict      -- the cell has text (no unit spent) or got it meanwhile (AC-19)
 *   503 dictionary_unavailable, 404 unknown_row / gone, 400 bad_request
 * The word and the definition are never logged.
 */
async function handleDefineRow({ request, env, params }: RouteContext): Promise<Response> {
  const read = await readPageBody(request);
  if (!read.ok) return read.response;
  const { rowId } = read.body;
  if (!isId(rowId)) return badRequest("`rowId` must be a row id.");
  if (!(await isLiveSession(env, params.id))) return gone();

  const row = await env.DB.prepare(
    `SELECT word, definition, definition_rev, deleted_at_rev FROM rows WHERE session_id = ?1 AND id = ?2`
  )
    .bind(params.id, rowId)
    .first<{ word: string; definition: string; definition_rev: number; deleted_at_rev: number | null }>();
  if (!row) return pageError(404, "unknown_row", "There is no such row in this list.");
  if (row.deleted_at_rev !== null) return refusedCellWrite({ outcome: "deleted" }, "definition");
  // A filled cell stays as it is, and asking costs nothing (AC-19).
  if (row.definition !== "") {
    return refusedCellWrite({ outcome: "conflict", value: row.definition, rev: row.definition_rev }, "definition");
  }
  const word = row.word.trim();
  if (!word) return badRequest("This row has no word to look up.");

  const take = await takeAutofillUnit(env, params.id);
  if (take.outcome === "paused") {
    logEvent("autofill paused", { session: params.id, reason: take.reason });
    return pageError(
      429,
      "autofill_paused",
      "Definition autofill is paused for today. You can still type the definition.",
      { reason: take.reason, resumesAt: take.resumesAt }
    );
  }

  // Every lookup counts from here on, found or not (AC-20).
  const { result, cached } = await lookUpCached(env, word);
  if (result.outcome === "unavailable") {
    logEvent("dictionary unavailable", { session: params.id, route: "page" });
    return pageError(503, "dictionary_unavailable", "The dictionary is not answering. Try again later.");
  }
  const sense = result.outcome === "senses" ? result.senses.find((s) => s.length <= MAX_FIELD_CHARS) : undefined;
  if (!sense) {
    logEvent("autofill nothing found", { session: params.id, row: rowId });
    return pageError(422, "nothing_found", "Nothing was found for this word.");
  }

  const written = await writeCell(env, params.id, rowId, "definition", sense, { onlyIfEmpty: true });
  if (written.outcome !== "saved") {
    logEvent("autofill refused", { session: params.id, row: rowId, code: written.outcome });
    return refusedCellWrite(written, "definition");
  }
  logEvent("autofill filled", { session: params.id, row: rowId, rev: written.rev, cached });
  return jsonResponse({ rowId, field: "definition", value: sense, rev: written.rev });
}

export const autofillRoutes: RouteDefinition[] = [
  {
    method: "POST",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/define$`),
    public: true,
    pageWrite: true,
    handler: handleDefineRow,
  },
];
