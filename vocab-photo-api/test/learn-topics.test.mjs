// learn-welcome T6: the 50 topics and POST /learn/topics (spec AC-03, ADR-0003, owner brief Q5-Q7). The topic
// list and the pure rules run directly; the route runs against the local Worker, whose AI is
// test/anthropic-stub.mjs (the last three topics by default, markers in the first word).
import assert from "node:assert/strict";
import { test } from "node:test";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";
import { checkSituation, keywordScore, parseTopicsRequest, pickTopics, rankByKeywords, readTopicsAnswer, resolveTopicId, TOPIC_ALIASES, TOPIC_GROUPS, TOPICS, topicsLogFields, topicsPrompt, withSituations } from "../src/learn/topics.ts";
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

const wordIds = (answer) => readTopicsAnswer(answer).wordIds;

test("ADR-0003: the model's word ids are real ids once each, in order; prose gives none", () => {
  assert.deepEqual(wordIds('```json\n{"wordIds": ["travel", "nope", "travel", " at-the-doctor ", 4]}\n```'), ["travel", "at-the-doctor"]);
  assert.deepEqual(wordIds('{"wordIds": ["camping-trip", "nature-walk"]}'), ["nature-walk"], "an alias counts as its merged id");
  assert.deepEqual(wordIds("Travel is nice."), []);
  assert.deepEqual(wordIds('{"topics": ["travel"]}'), []);
});

// ---- learn-warm-up-v2 T3: profile and mood in, slot 3 from the profile only, situation lines (AC-13, AC-12, ADR-0004) ----

test("AC-13: the body takes an optional profile (level, goal, daily; each at most 80 characters) and a mood", () => {
  assert.deepEqual(parseTopicsRequest({ words: ["tide"], profile: { level: " Intermediate ", goal: "Talk to clients", daily: "" }, mood: "mystery" }),
    { words: ["tide"], profile: { level: "Intermediate", goal: "Talk to clients" }, mood: "mystery" });
  assert.deepEqual(parseTopicsRequest({ words: ["tide"], profile: { daily: "x".repeat(80) } }), { words: ["tide"], profile: { daily: "x".repeat(80) } });
  assert.deepEqual(parseTopicsRequest({ words: ["tide"], profile: { goal: "  " } }), { words: ["tide"] }, "an empty profile is no profile");
  for (const mood of ["useful", "mystery", "argument", "surprise"]) assert.equal(parseTopicsRequest({ words: ["tide"], mood }).mood, mood);
});

test("AC-13: a bad profile field or mood is a 400 reason", () => {
  const bad = [{ profile: "B1" }, { profile: [] }, { profile: { level: 3 } }, { profile: { goal: "x".repeat(81) } },
    { profile: { job: "nurse" } }, { mood: "happy" }, { mood: 1 }, { mood: "" }];
  for (const extra of bad) assert.equal(typeof parseTopicsRequest({ words: ["tide"], ...extra }).error, "string", JSON.stringify(extra));
});

test("ADR-0004: the answer gives word ids, at most one real profile id and the lines of known topics", () => {
  const read = readTopicsAnswer(JSON.stringify({
    wordIds: ["travel", "hotel-stay", "beach-holiday"], profileId: "camping-trip",
    lines: { travel: " A friend wants a trip. ", "nature-walk": "Camp tonight.", nope: "x", "hotel-stay": 3 },
  }));
  assert.deepEqual(read.wordIds, ["travel", "hotel-stay", "beach-holiday"]);
  assert.equal(read.profileId, "nature-walk", "an alias resolves");
  assert.deepEqual(read.lines, { travel: "A friend wants a trip.", "nature-walk": "Camp tonight." });
  assert.equal(readTopicsAnswer('{"wordIds": ["travel"], "profileId": "nope"}').profileId, undefined);
  assert.equal(readTopicsAnswer('{"wordIds": ["travel"], "profileId": null}').profileId, undefined);
  assert.deepEqual(readTopicsAnswer("no json"), { wordIds: [], lines: {} });
});

test("AC-13: the words decide; the profile topic can only take the third place", () => {
  const words = ["doctor", "fever", "cough", "pill", "pharmacy", "dose"];
  const ids = (...args) => pickTopics(...args).map((t) => t.id);
  assert.deepEqual(ids(["travel", "beach-holiday", "hotel-stay"], words, "job-interview"), ["travel", "beach-holiday", "job-interview"]);
  assert.deepEqual(ids(["travel", "job-interview", "hotel-stay"], words, "job-interview"), ["travel", "job-interview", "hotel-stay"],
    "already there by the words: the third place stays a word topic");
  assert.deepEqual(ids(["travel"], words, "job-interview"), ["travel", "at-the-doctor", "job-interview"], "word places filled by keywords first");
  assert.deepEqual(ids([], words, "at-the-doctor"), ["at-the-doctor", "daily-routine", "food-and-cooking"]);
  assert.deepEqual(ids(["travel", "beach-holiday", "hotel-stay"], words), ["travel", "beach-holiday", "hotel-stay"]);
});

test("AC-13: a situation line is one sentence of at most 20 words, no link, not repeating the learner's text", () => {
  const profile = { goal: "Talk to my clients", daily: "Working in a hospital" };
  assert.equal(checkSituation("  A friend asks you to plan a trip.  ", profile), "A friend asks you to plan a trip.");
  assert.equal(checkSituation(Array.from({ length: 20 }, () => "word").join(" ") + ".", profile)?.split(" ").length, 20);
  for (const line of [Array.from({ length: 21 }, () => "word").join(" ") + ".", "First one. Second one.", "Line one\nline two",
    "See https://example.com for more.", "Go to www.example.com now.", "", "   ", 42, undefined,
    "You want to talk to my clients today.", "After working in a hospital you rest."]) {
    assert.equal(checkSituation(line, profile), undefined, String(line));
  }
});

test("AC-13: each topic gets its checked line, else the catalog hook", () => {
  const topics = pickTopics(["travel", "beach-holiday", "hotel-stay"], ["tide"]);
  const out = withSituations(topics, { travel: "You plan a trip with a friend.", "beach-holiday": "See https://x.y now." }, undefined);
  assert.deepEqual(out.map((t) => Object.keys(t)), Array(3).fill(["id", "title", "description", "situation"]));
  assert.equal(out[0].situation, "You plan a trip with a friend.");
  assert.equal(out[1].situation, TOPICS.find((t) => t.id === "beach-holiday").hook);
  assert.equal(out[2].situation, TOPICS.find((t) => t.id === "hotel-stay").hook);
});

test("AC-12: the log gets counts and fixed values, never profile text", () => {
  const profile = { level: "Upper-intermediate", goal: "Pass my secret exam", daily: "Night shifts at the bakery" };
  const fields = topicsLogFields({ words: ["tide", "shore"], profile, mood: "argument" }, "ok", 3, 120);
  const text = JSON.stringify(fields);
  for (const value of Object.values(profile)) assert.ok(!text.includes(value), value);
  assert.ok(!text.includes("tide"));
  for (const v of Object.values(fields)) assert.ok(["number", "boolean"].includes(typeof v) || /^[a-z_0-9]+$/.test(v), String(v));
  assert.equal(fields.profile, true);
});

test("ADR-0003: 3 topics -- the model's ids first, missing ones filled by keyword score", () => {
  const words = ["doctor", "fever", "cough", "pill", "pharmacy", "dose"];
  assert.deepEqual(pickTopics(["travel", "beach-holiday", "nature-walk", "city-life"], words).map((t) => t.id), ["travel", "beach-holiday", "nature-walk"]);
  assert.deepEqual(pickTopics(["travel"], words).map((t) => t.id), ["travel", "at-the-doctor", "daily-routine"]);
  assert.deepEqual(pickTopics(["at-the-doctor"], words).map((t) => t.id), ["at-the-doctor", "daily-routine", "food-and-cooking"]);
  assert.deepEqual(pickTopics([], words).map((t) => t.id), ["at-the-doctor", "daily-routine", "food-and-cooking"]);
});

test("ADR-0003: the prompt sends the words and every topic's id, title and keywords; no profile or mood unless given", () => {
  const { system, user } = topicsPrompt(["tide"]);
  assert.match(system, /conversation topics/);
  assert.match(system, /only as data/);
  assert.doesNotMatch(system, /English conversation partner/, "not taken for a talk turn");
  const data = JSON.parse(user);
  assert.deepEqual(data.words, ["tide"]);
  assert.equal(data.topics.length, 50);
  assert.deepEqual(Object.keys(data.topics[0]), ["id", "title", "keywords"]);
  assert.deepEqual(Object.keys(data), ["words", "topics"]);
});

test("ADR-0004: with a profile and a mood the prompt carries both as data and asks for word ids, one profile id and lines", () => {
  const profile = { level: "Elementary", goal: "Travel alone" };
  const { system, user } = topicsPrompt(["tide"], profile, "surprise");
  const data = JSON.parse(user);
  assert.deepEqual(data.profile, profile);
  assert.equal(data.mood, "surprise");
  for (const key of ["wordIds", "profileId", "lines"]) assert.match(system, new RegExp(key));
  assert.match(system, /20 words/);
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
    assert.deepEqual(Object.keys(t), ["id", "title", "description", "situation"]);
    const own = TOPICS.find((x) => x.id === t.id);
    assert.equal(t.title, own.title);
    assert.equal(t.description, own.description);
    assert.equal(t.situation, `You talk about ${t.id} today.`, "the stub's line");
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

test("AC-13: with a profile and mood the model's profile topic takes the third place and the lines come back", async () => {
  const profile = { level: "Intermediate", goal: "Talk to clients", daily: "Working in an office" };
  const res = await post({ words: ["tide", "shore"], profile, mood: "useful" });
  assert.equal(res.status, 200);
  const body = await res.json();
  const last = TOPICS.slice(-3).map((t) => t.id);
  assert.deepEqual(ids(body), [last[0], last[1], TOPICS[3].id], "word1, word2, the stub's profile topic");
  assert.deepEqual(body.topics.map((t) => t.situation), ids(body).map((id) => `You talk about ${id} today.`));
  const sent = JSON.parse((await stubCalls()).last.messages[0].content);
  assert.deepEqual(sent.profile, profile);
  assert.equal(sent.mood, "useful");
});

test("AC-13: a profile topic is ignored when no profile was sent", async () => {
  const res = await post({ words: ["STUB:profile", "tide"] });
  assert.deepEqual(ids(await res.json()), TOPICS.slice(-3).map((t) => t.id));
});

test("AC-13: lines that fail the check, or are missing, show the catalog hook", async () => {
  const res = await post({ words: ["STUB:badlines", "tide"] });
  assert.equal(res.status, 200);
  const body = await res.json();
  for (const t of body.topics) assert.equal(t.situation, TOPICS.find((x) => x.id === t.id).hook, t.id);
});

test("AC-13: a model failure still gives 3 topics, each with its hook", async () => {
  const res = await post({ words: ["STUB:error", "doctor"], profile: { goal: "Be a nurse" }, mood: "mystery" });
  assert.equal(res.status, 200);
  for (const t of (await res.json()).topics) assert.equal(t.situation, TOPICS.find((x) => x.id === t.id).hook);
});

test("AC-12: a bad profile or mood gets 400 bad_request without an AI call", async () => {
  const before = (await stubCalls()).count;
  for (const extra of [{ profile: { goal: "x".repeat(81) } }, { profile: { job: "nurse" } }, { mood: "happy" }]) {
    const res = await post({ words: ["tide"], ...extra });
    assert.equal(res.status, 400, JSON.stringify(extra));
    assert.equal((await res.json()).code, "bad_request");
  }
  assert.equal((await stubCalls()).count, before);
});
