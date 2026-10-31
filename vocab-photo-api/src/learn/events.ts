// POST /learn/events -- the warm-up and talk counts (learn-warm-up-v2 AC-17, ADR-0007). Up to 20 events per
// batch, each a name from the fixed list with, where the name takes them, a value from its fixed list or a
// whole number. Anything else -- an unknown name, a free string, an extra field -- rejects the whole batch,
// so no word, answer, topic text or message can reach the logs. The Worker only logs; nothing is stored.
//
// Imports carry the `.ts` extension so the Node tests can load this module directly.

import { jsonResponse } from "../http.ts";
import { logEvent } from "../log.ts";
import type { RouteContext, RouteDefinition } from "../routing";

/** The warm-up steps an event can name (the step bar's parts; "difficulty" is the Hard/Easy step). */
const STEPS = ["intro", "mood", "goal", "daily", "grammar", "topic", "difficulty"] as const;

interface EventRule {
  /** The event's fixed values; set means a value is required. */
  values?: readonly string[];
  /** Whether the event carries a whole number `n` (required when true). */
  n?: boolean;
}

/** The fixed list (AC-17): warm-up part shown / answered / left, finished with the parts answered, the grammar
 * answer, the topic kind, the talk's end, another talk from the results, and thumbs up/down. */
export const EVENT_SCHEMA = {
  warm_up_shown: { values: STEPS },
  warm_up_answered: { values: STEPS },
  warm_up_left: { values: STEPS },
  warm_up_finished: { n: true },
  grammar_answer: { values: ["rule", "none"] },
  topic_picked: { values: ["suggested", "own"] },
  talk_end: { values: ["finished", "ended"] },
  talk_again: {},
  talk_rating: { values: ["up", "down"] },
} as const satisfies Record<string, EventRule>;

export type EventName = keyof typeof EVENT_SCHEMA;
export interface LearnEvent {
  name: EventName;
  value?: string;
  n?: number;
}

export const MAX_EVENTS = 20;
const MAX_N = 1000;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** Why one event is not on the fixed list, or undefined when it is. */
function eventError(event: unknown): string | undefined {
  if (!isRecord(event)) return "An event is a JSON object";
  const { name } = event;
  if (typeof name !== "string" || !Object.prototype.hasOwnProperty.call(EVENT_SCHEMA, name)) return "Unknown event name";
  const rule: EventRule = EVENT_SCHEMA[name as EventName];
  for (const key of Object.keys(event)) {
    if (key !== "name" && key !== "value" && key !== "n") return `Unknown field ${key}`;
  }
  if (rule.values) {
    if (typeof event.value !== "string" || !rule.values.includes(event.value)) return `${name} takes one of ${rule.values.join(", ")}`;
  } else if ("value" in event) return `${name} takes no value`;
  if (rule.n) {
    const { n } = event;
    if (typeof n !== "number" || !Number.isInteger(n) || n < 0 || n > MAX_N) return `${name} takes a whole number 0 to ${MAX_N}`;
  } else if ("n" in event) return `${name} takes no number`;
  return undefined;
}

/** The events, or the reason the batch is rejected: 1 to 20 events, all on the fixed list. */
export function parseEventsRequest(body: unknown): { events: LearnEvent[]; error?: undefined } | { error: string } {
  if (!isRecord(body)) return { error: "Body must be a JSON object" };
  const { events } = body;
  if (!Array.isArray(events) || events.length < 1 || events.length > MAX_EVENTS) return { error: `Send 1 to ${MAX_EVENTS} events` };
  for (const event of events) {
    const error = eventError(event);
    if (error !== undefined) return { error };
  }
  return { events: events as LearnEvent[] };
}

/** One event's log fields: its name and its fixed value or number, nothing else. */
export function eventLogFields(event: LearnEvent): Record<string, string | number> {
  return {
    name: event.name,
    ...(event.value !== undefined ? { value: event.value } : {}),
    ...(event.n !== undefined ? { n: event.n } : {}),
  };
}

async function handleEvents({ request }: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Body must be JSON", code: "bad_request" }, 400);
  }
  const parsed = parseEventsRequest(body);
  if (parsed.error !== undefined) return jsonResponse({ error: parsed.error, code: "bad_request" }, 400);
  for (const event of parsed.events) logEvent("learn event", eventLogFields(event));
  return jsonResponse({ ok: true });
}

export const learnEventsRoute: RouteDefinition = { method: "POST", pattern: /^\/learn\/events$/, public: false, handler: handleEvents };
