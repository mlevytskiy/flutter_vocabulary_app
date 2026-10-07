// The story feature's routes, all behind the app secret (`public: false`, sad §5, AC-18).
// This file holds the offered AI list and grouping; the run routes join it later.

import { jsonResponse } from "../http";
import type { RouteContext, RouteDefinition } from "../routing";
import { groupWords, parseGroupingRequest } from "./grouping.ts";
import { defaults, offeredModels, pricesAsOf } from "./models.ts";

/** GET /story/models -- the offered AIs with prices and the defaults (ADR-0004). Owner-only fields stay out. */
async function handleModels(): Promise<Response> {
  const models = offeredModels.map(({ provisional: _provisional, ...model }) => model);
  return jsonResponse({ pricesAsOf, defaults, models });
}

/** POST /story/grouping -- the fixed AI's split of the words, returned unchanged (ADR-0005, S-01). */
async function handleGrouping({ request, env }: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON" }, 400);
  }
  const parsed = parseGroupingRequest(body);
  if ("error" in parsed) return jsonResponse({ error: parsed.error }, 400);

  const groups = await groupWords(env, parsed);
  if (!groups) return jsonResponse({ error: "Could not group the words", code: "grouping_failed" }, 502);
  return jsonResponse(groups);
}

export const storyRoutes: RouteDefinition[] = [
  { method: "GET", pattern: /^\/story\/models$/, public: false, handler: handleModels },
  { method: "POST", pattern: /^\/story\/grouping$/, public: false, handler: handleGrouping },
];
