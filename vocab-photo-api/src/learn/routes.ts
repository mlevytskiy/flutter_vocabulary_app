import { htmlResponse } from "../http";
import type { RouteContext, RouteDefinition } from "../routing";
import { pageAssets, pageHeaders } from "../session/assets";
import { renderNotFoundPage } from "../session/page";
import { loadSession } from "../session/store";
import { EXERCISES, findAvailable, isWordToLearn } from "./exercises";
import { renderComingSoonPage, renderLearnPage, renderNoWordsPage } from "./page";

/** The same "gone" answer as a dead shared link (AC-09): one body, one set of headers. */
async function gonePage(): Promise<Response> {
  return htmlResponse(renderNotFoundPage(), 404, await pageHeaders());
}

/** The `pick` values that name an available exercise, once each, in plan order; the rest is ignored (AC-06). */
function validPicks(url: URL): string[] {
  const asked = new Set(url.searchParams.getAll("pick"));
  return EXERCISES.filter((e) => e.available && asked.has(e.id)).map((e) => e.id);
}

/** GET /s/:id/learn -- public. Session live? -> any word to learn? -> render (sad §6 S-04). */
async function handleLearnPage({ env, url, params }: RouteContext): Promise<Response> {
  const session = await loadSession(env, params.id);
  if (!session) return gonePage();
  const wordCount = session.rows.filter(isWordToLearn).length;
  const { learnScriptPath } = await pageAssets();
  const html =
    wordCount === 0
      ? renderNoWordsPage(session.id)
      : renderLearnPage(session.id, wordCount, validPicks(url), learnScriptPath);
  return htmlResponse(html, 200, await pageHeaders());
}

/** GET /s/:id/learn/:exercise -- public. Session live? -> exercise known and available? -> render. */
async function handleComingSoonPage({ env, url, params }: RouteContext): Promise<Response> {
  const session = await loadSession(env, params.id);
  if (!session) return gonePage();
  const exercise = findAvailable(params.exercise);
  if (!exercise) return gonePage();
  // OQ-1 (provisional): a live session whose rows hold no word to learn any more still gets
  // this 200 page, as the contract says; the owner may resolve it the other way.
  const { learnScriptPath } = await pageAssets();
  return htmlResponse(renderComingSoonPage(session.id, exercise, validPicks(url), learnScriptPath), 200, await pageHeaders());
}

export const learnRoutes: RouteDefinition[] = [
  { method: "GET", pattern: /^\/s\/(?<id>[^/]+)\/learn$/, public: true, handler: handleLearnPage },
  { method: "GET", pattern: /^\/s\/(?<id>[^/]+)\/learn\/(?<exercise>[^/]+)$/, public: true, handler: handleComingSoonPage },
];
