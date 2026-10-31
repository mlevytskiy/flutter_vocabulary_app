// learn-welcome T6: the 50 topics and POST /learn/topics (spec AC-03, ADR-0003, owner brief Q5-Q7). The topic
// list and the pure rules run directly; the route runs against the local Worker, whose AI is
// test/anthropic-stub.mjs (the last three topics by default, markers in the first word).
import assert from "node:assert/strict";
import { test } from "node:test";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";
import { keywordScore, parseTopicsRequest, pickTopics, rankByKeywords, readTopicIds, resolveTopicId, TOPIC_ALIASES, TOPIC_GROUPS, TOPICS, topicsPrompt } from "../src/learn/topics.ts";
import { parseTalkRequest } from "../src/learn/talk.ts";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();

// ---- the topics ----

test("Q5: 50 topics, kebab-case unique ids, titles of at most 4 words, one-sentence descriptions, 5-10 lowercase keywords", () => {
  assert.equal(TOPICS.length, 50);
  assert.equal(new Set(TOPICS.map((t) => t.id)).size, 50);
  for (const t of TOPICS) {
    assert.match(t.id, /^[a-z]+(-[a-z]+)*$/, t.id);
    const words = t.title.trim().split(/\s+/);
    assert.ok(words.length >= 1 && words.length <= 4, `${t.id}: ${t.title}`);
    assert.match(t.description, /^[A-Z][^.!?]*[.!?]$/, `${t.id}: one sentence`);
    assert.ok(t.keywords.length >= 5 && t.keywords.length <= 10, `${t.id}: ${t.keywords.length} keywords`);
    for (const k of t.keywords) assert.match(k, /^[a-z]+$/, `${t.id}: ${k}`);
    assert.equal(new Set(t.keywords).size, t.keywords.length, `${t.id}: no repeated keyword`);
  }
});

// learn-warm-up-v2 T2: the revised catalog (AC-14) and the permanent aliases of the merged ids (AC-15, ADR-0006).

test("AC-14: 8 groups in order, each topic in one of them, every group used", () => {
  assert.deepEqual(TOPIC_GROUPS, ["Everyday life", "People", "Work and study", "Travel and transport", "Places and nature",
    "Leisure and ideas", "Technology and services", "Health and getting help"]);
  for (const t of TOPICS) assert.ok(TOPIC_GROUPS.includes(t.group), `${t.id}: ${t.group}`);
  for (const g of TOPIC_GROUPS) assert.ok(TOPICS.some((t) => t.group === g), `${g} has topics`);
});

test("AC-14: every topic has an example situation (hook): one sentence of at most 20 words", () => {
  for (const t of TOPICS) {
    assert.equal(typeof t.hook, "string", t.id);
    assert.match(t.hook, /^[A-Z][^.!?]*[.!?]$/, `${t.id}: one sentence`);
    assert.ok(t.hook.trim().split(/\s+/).length <= 20, `${t.id}: at most 20 words`);
  }
});

test("AC-14: the six new topics are in the catalog", () => {
  const titles = TOPICS.map((t) => t.title);
  for (const title of ["Meeting new people", "Meetings and presenting ideas", "Helping customers", "Online shopping and deliveries",
    "Invitations and making plans", "Favours and polite boundaries"]) assert.ok(titles.includes(title), title);
});

test("AC-15: the alias map is pinned -- the six merged-away ids, never removed", () => {
  assert.deepEqual(TOPIC_ALIASES, {
    "pharmacy-visit": "at-the-doctor",
    "camping-trip": "nature-walk",
    "saving-and-budget": "money-and-banking",
    "computer-problems": "phones-and-gadgets",
    "watching-a-match": "sport-and-fitness",
    "university-life": "school-days",
  });
  const ids = new Set(TOPICS.map((t) => t.id));
  for (const [old, merged] of Object.entries(TOPIC_ALIASES)) {
    assert.ok(!ids.has(old), `${old} is gone from the catalog`);
    assert.ok(ids.has(merged), `${merged} is a topic`);
    assert.equal(resolveTopicId(old), merged);
  }
  assert.equal(resolveTopicId("travel"), "travel");
  assert.equal(resolveTopicId("own-made-up"), "own-made-up");
});

test("AC-15: a talk started on a merged-away id runs (and is logged) on the merged topic", () => {
  const words = ["shore", "tide", "fog", "gale", "pier", "anchor", "mast", "deck"].map((word) => ({ word, translation: "t" }));
  const start = { kind: "start", scene: "Sea words", words, target: "shore", history: [] };
  const parsed = parseTalkRequest({ ...start, topic: { id: "camping-trip", text: "Camping trip" } });
  assert.equal(parsed.error, undefined);
  assert.deepEqual(parsed.topic, { id: "nature-walk", text: "Camping trip" });
  assert.deepEqual(parseTalkRequest({ ...start, topic: { id: "travel", text: "Travel" } }).topic, { id: "travel", text: "Travel" });
});

test("AC-03: the app's bundled fallback topics are the first three and win a keyword tie", () => {
  assert.deepEqual(TOPICS.slice(0, 3).map((t) => t.title), ["Daily routine", "Food and cooking", "Travel"]);
  assert.deepEqual(TOPICS.slice(0, 3).map((t) => t.id), ["daily-routine", "food-and-cooking", "travel"]);
  assert.deepEqual(rankByKeywords(["zzzz"]).slice(0, 3), ["daily-routine", "food-and-cooking", "travel"]);
});

// ---- the pure rules ----

test("AC-03: the body is 1 to 60 non-empty words of at most 100 characters", () => {
  assert.deepEqual(parseTopicsRequest({ words: [" tide ", "shore"] }), { words: ["tide", "shore"] });
  const bad = [null, [], {}, { words: [] }, { words: "tide" }, { words: [""] }, { words: ["  "] }, { words: [3] },
    { words: ["x".repeat(101)] }, { words: Array.from({ length: 61 }, (_, i) => `w${i}`) }];
  for (const body of bad) assert.equal(typeof parseTopicsRequest(body).error, "string", JSON.stringify(body)?.slice(0, 60));
});

test("ADR-0003: the keyword score counts touched keywords by shared stem", () => {
  const beach = TOPICS.find((t) => t.id === "beach-holiday");
  assert.equal(keywordScore(beach, ["tide", "Shores", "seashell", "fog"]), 2, "tide and shore (shores); 'seashell' is not 'shell'");
  assert.equal(keywordScore(beach, ["sea", "se"]), 1, "short words count only when equal");
  assert.equal(rankByKeywords(["doctor", "fever", "cough", "pill"])[0], "at-the-doctor");
  assert.equal(rankByKeywords(["Recipes", "baking", "spices"])[0], "food-and-cooking");
});

test("ADR-0003: the model's answer keeps real ids once each, in order; prose gives none", () => {
  assert.deepEqual(readTopicIds('```json\n{"ids": ["travel", "nope", "travel", " at-the-doctor ", 4]}\n```'), ["travel", "at-the-doctor"]);
  assert.deepEqual(readTopicIds('{"ids": ["camping-trip", "nature-walk"]}'), ["nature-walk"], "an alias counts as its merged id");
  assert.deepEqual(readTopicIds("Travel is nice."), []);
  assert.deepEqual(readTopicIds('{"topics": ["travel"]}'), []);
});

test("ADR-0003: 3 topics -- the model's ids first, missing ones filled by keyword score", () => {
  const words = ["doctor", "fever", "cough", "pill", "pharmacy", "dose"];
  assert.deepEqual(pickTopics(["travel", "beach-holiday", "nature-walk", "city-life"], words).map((t) => t.id), ["travel", "beach-holiday", "nature-walk"]);
  assert.deepEqual(pickTopics(["travel"], words).map((t) => t.id), ["travel", "at-the-doctor", "daily-routine"]);
  assert.deepEqual(pickTopics(["at-the-doctor"], words).map((t) => t.id), ["at-the-doctor", "daily-routine", "food-and-cooking"]);
  assert.deepEqual(pickTopics([], words).map((t) => t.id), ["at-the-doctor", "daily-routine", "food-and-cooking"]);
});

test("ADR-0003: the prompt sends the words and every topic's id and keywords, nothing more", () => {
  const { system, user } = topicsPrompt(["tide"]);
  assert.match(system, /conversation topics/);
  assert.doesNotMatch(system, /English conversation partner/, "not taken for a talk turn");
  const data = JSON.parse(user);
  assert.deepEqual(data.words, ["tide"]);
  assert.equal(data.topics.length, 50);
  assert.deepEqual(Object.keys(data.topics[0]), ["id", "keywords"]);
});

// ---- the route ----

const today = () => new Date().toISOString().slice(0, 10);
const talksUsed = () => d1(`SELECT used FROM all_learn_talks WHERE utc_day = '${today()}'`)[0]?.used ?? 0;
const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/learn/topics`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });
const ids = (body) => body.topics.map((t) => t.id);

test("AC-03: without the app secret nothing is asked", async () => {
  const before = (await stubCalls()).count;
  assert.equal((await post({ words: ["tide"] }, { "content-type": "application/json" })).status, 401);
  assert.equal((await stubCalls()).count, before);
});

test("AC-03: bad bodies get 400 bad_request without an AI call", async () => {
  const before = (await stubCalls()).count;
  for (const body of ["not json", { words: [] }, { words: ["x".repeat(101)] }]) {
    const res = await post(body);
    assert.equal(res.status, 400);
    assert.equal((await res.json()).code, "bad_request");
  }
  assert.equal((await stubCalls()).count, before);
});

test("AC-03: the route asks the talk mission's model once and returns its 3 topics with title and description; no talk is counted", async () => {
  const keep = talksUsed();
  const before = (await stubCalls()).count;
  const res = await post({ words: ["tide", "shore", "fog", "harbour"] });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(ids(body), TOPICS.slice(-3).map((t) => t.id));
  for (const t of body.topics) {
    assert.deepEqual(Object.keys(t), ["id", "title", "description"]);
    const own = TOPICS.find((x) => x.id === t.id);
    assert.equal(t.title, own.title);
    assert.equal(t.description, own.description);
  }
  const calls = await stubCalls();
  assert.equal(calls.count, before + 1);
  assert.equal(calls.last.model, "claude-haiku-4-5-20251001", "the talk mission's model");
  assert.deepEqual(JSON.parse(calls.last.messages[0].content).words, ["tide", "shore", "fog", "harbour"]);
  assert.equal(talksUsed(), keep, "the daily talk counter is untouched");
});

test("ADR-0003: an unknown or repeated id is filled from the keyword score", async () => {
  const res = await post({ words: ["STUB:partial", "tide", "shore", "sand", "waves"] });
  assert.equal(res.status, 200);
  assert.deepEqual(ids(await res.json()), [TOPICS[5].id, "beach-holiday", "daily-routine"]);
});

test("AC-03: a model failure, a prose answer or a late answer still gives 3 topics by keyword score", async () => {
  const keep = talksUsed();
  for (const marker of ["STUB:error", "STUB:malformed", "STUB:slow"]) {
    const res = await post({ words: [marker, "doctor", "fever", "cough", "pill"] });
    assert.equal(res.status, 200, marker);
    assert.deepEqual(ids(await res.json()), ["at-the-doctor", "daily-routine", "food-and-cooking"], marker);
  }
  assert.equal(talksUsed(), keep);
});
