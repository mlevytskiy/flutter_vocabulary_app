import type { Env } from "../env";
import { jsonResponse } from "../http";
import type { RouteContext, RouteDefinition } from "../routing";
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

interface SessionRevs {
  rev: number;
  replaced_rev: number;
  expires_at: string;
}

const SINCE_RE = /^(0|[1-9][0-9]{0,15})$/;

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
  ]);
}

async function handleChanges({ url, env, params }: RouteContext): Promise<Response> {
  const sinceParam = url.searchParams.get("since") ?? "";
  if (!SINCE_RE.test(sinceParam) || !Number.isSafeInteger(Number(sinceParam))) {
    return jsonResponse({ error: "since must be a revision (a whole number from 0).", code: "bad_request" }, 400);
  }
  const since = Number(sinceParam);
  const gone = () => jsonResponse({ error: "This word list is gone.", code: "gone" }, 404);

  let [sessionRead, rowsRead, sourcesRead] = await readFeed(env, params.id, since);
  let session = (sessionRead.results as SessionRevs[])[0];
  if (!session) {
    // A link still only in KV: loading it imports it into D1 (T4).
    if (!(await isLiveSession(env, params.id))) return gone();
    [sessionRead, rowsRead, sourcesRead] = await readFeed(env, params.id, since);
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
  return jsonResponse({ rev: session.rev, cells, rows, deleted, sources });
}

export const changesRoutes: RouteDefinition[] = [
  {
    method: "GET",
    pattern: new RegExp(`^/s/(?<id>${ID_PATTERN})/changes$`),
    public: true,
    handler: handleChanges,
  },
];
