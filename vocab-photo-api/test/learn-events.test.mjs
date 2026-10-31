// learn-warm-up-v2 T6: POST /learn/events -- counts with fixed names, fixed values and numbers only (spec AC-17,
// ADR-0007). The pure rules run directly; the route runs against the local Worker and never reaches the AI.
import assert from "node:assert/strict";
import { test } from "node:test";
import { appHeaders, baseUrl } from "./helpers.mjs";
import { EVENT_SCHEMA, eventLogFields, MAX_EVENTS, parseEventsRequest } from "../src/learn/events.ts";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();

// ---- the fixed list ----

test("AC-17: the fixed list names every count the spec asks for, with fixed values only", () => {
  assert.deepEqual(Object.keys(EVENT_SCHEMA), [
    "warm_up_shown", "warm_up_answered", "warm_up_left", "warm_up_finished",
    "grammar_answer", "topic_picked", "talk_end", "talk_again", "talk_rating",
  ]);
  const steps = ["intro", "mood", "goal", "daily", "grammar", "topic", "difficulty"];
  assert.deepEqual(EVENT_SCHEMA.warm_up_shown.values, steps);
  assert.deepEqual(EVENT_SCHEMA.warm_up_answered.values, steps);
  assert.deepEqual(EVENT_SCHEMA.warm_up_left.values, steps);
  assert.deepEqual(EVENT_SCHEMA.grammar_answer.values, ["rule", "none"]);
  assert.deepEqual(EVENT_SCHEMA.topic_picked.values, ["suggested", "own"]);
  assert.deepEqual(EVENT_SCHEMA.talk_end.values, ["finished", "ended"]);
  assert.deepEqual(EVENT_SCHEMA.talk_rating.values, ["up", "down"]);
  assert.equal(EVENT_SCHEMA.warm_up_finished.n, true);
  assert.equal(MAX_EVENTS, 20);
});

// ---- the pure rules ----

test("AC-17: 1 to 20 events of known names with their fixed values and whole numbers pass", () => {
  const events = [
    { name: "warm_up_shown", value: "intro" },
    { name: "warm_up_finished", n: 4 },
    { name: "grammar_answer", value: "none" },
    { name: "talk_again" },
    { name: "talk_rating", value: "up" },
  ];
  assert.deepEqual(parseEventsRequest({ events }), { events });
  const twenty = Array.from({ length: 20 }, () => ({ name: "talk_again" }));
  assert.deepEqual(parseEventsRequest({ events: twenty }), { events: twenty });
});

test("AC-17: an unknown name, a free string, a missing or extra value, a bad number or an extra field is rejected", () => {
  const bad = [
    null, [], {}, { events: "talk_again" }, { events: [] },
    { events: Array.from({ length: 21 }, () => ({ name: "talk_again" })) },
    { events: [{ name: "warm_up_answer_text", value: "intro" }] },
    { events: [{ name: "warm_up_shown", value: "I want to travel" }] },
    { events: [{ name: "topic_picked", value: "Trouble at the airport" }] },
    { events: [{ name: "warm_up_shown" }] },
    { events: [{ name: "talk_again", value: "up" }] },
    { events: [{ name: "warm_up_finished" }] },
    { events: [{ name: "warm_up_finished", n: 2.5 }] },
    { events: [{ name: "warm_up_finished", n: -1 }] },
    { events: [{ name: "warm_up_finished", n: 1001 }] },
    { events: [{ name: "warm_up_finished", n: "4" }] },
    { events: [{ name: "talk_rating", n: 1, value: "up" }] },
    { events: [{ name: "talk_rating", value: "up", text: "loved it" }] },
    { events: [{ name: "talk_again" }, "talk_again"] },
    { events: [{ name: 3 }] },
  ];
  for (const body of bad) assert.equal(typeof parseEventsRequest(body).error, "string", JSON.stringify(body)?.slice(0, 80));
});

test("AC-17: each log line holds the event's name and its fixed value or number only", () => {
  assert.deepEqual(eventLogFields({ name: "warm_up_left", value: "grammar" }), { name: "warm_up_left", value: "grammar" });
  assert.deepEqual(eventLogFields({ name: "warm_up_finished", n: 3 }), { name: "warm_up_finished", n: 3 });
  assert.deepEqual(eventLogFields({ name: "talk_again" }), { name: "talk_again" });
});

// ---- the route ----

const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/learn/events`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });

test("AC-17: without the app secret nothing is recorded", async () => {
  assert.equal((await post({ events: [{ name: "talk_again" }] }, { "content-type": "application/json" })).status, 401);
});

test("AC-17: a valid batch answers {ok: true} without an AI call", async () => {
  const before = (await stubCalls()).count;
  const res = await post({ events: [{ name: "talk_end", value: "ended" }, { name: "talk_rating", value: "down" }] });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true });
  assert.equal((await stubCalls()).count, before);
});

test("AC-17: a free string, an unknown name or a bad body gets 400 bad_request", async () => {
  for (const body of ["not json", { events: [{ name: "topic_picked", value: "my own topic" }] }, { events: [{ name: "answer" }] }]) {
    const res = await post(body);
    assert.equal(res.status, 400, JSON.stringify(body));
    assert.equal((await res.json()).code, "bad_request");
  }
});
