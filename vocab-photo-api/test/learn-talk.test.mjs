// learn-redesign T16: POST /learn/talk, the talk turn route, and its 20-talks-a-day counter (spec AC-23,
// AC-24, §6 talk cost row; ADR-0007; sad §6.4). The pure rules and the counter run directly (the counter
// against the real schema in node:sqlite); the route runs against the local Worker, whose AI is
// test/anthropic-stub.mjs and whose talk day row is seeded through d1() and put back afterwards.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { sqliteD1 } from "./sqlite-d1.mjs";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";
import { LEARN_TALK_DAY_LIMIT, takeLearnTalk } from "../src/learn/allowance.ts";
import { MISSION_KINDS, missionPrompt, nextTarget, parseMission, parseTalkRequest, readMission, talkPrompt } from "../src/learn/talk.ts";
import { parseTalkPictureRequest, TALK_PICTURE_MODEL } from "../src/learn/talk-picture.ts";
import { LEARN_TALK_PICTURE_DAY_LIMIT, takeLearnTalkPicture } from "../src/learn/allowance.ts";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();

const WORDS = [
  { word: "shore", translation: "берег" },
  { word: "tide", translation: "приплив" },
  { word: "fog", translation: "туман" },
];
const SCENE = "Two friends walk along a foggy beach at dawn.";
const start = (extra = {}) => ({ kind: "start", scene: SCENE, words: WORDS, target: "shore", history: [], ...extra });
const turns = (n, last = "I like the sea.") =>
  Array.from({ length: n }, (_, i) => (i % 2 === 0 ? { role: "ai", text: `Question ${i}?` } : { role: "learner", text: `Answer ${i}.` }))
    .map((t, i, all) => (i === all.length - 1 ? { role: "learner", text: last } : t));
const reply = (history = turns(2), extra = {}) => ({ ...start(), kind: "reply", history, ...extra });

// ---- the pure rules ----

test("ADR-0007: a valid start and a valid reply are accepted", () => {
  assert.deepEqual(parseTalkRequest(start()), start());
  assert.equal(parseTalkRequest(reply()).error, undefined);
  assert.equal(parseTalkRequest(reply(turns(24))).error, undefined, "24 history messages is the most");
  assert.equal(parseTalkRequest(start({ words: Array.from({ length: 19 }, (_, i) => ({ word: `w${i}`, translation: "t" })), target: "w3" })).error, undefined);
});

test("AC-24: a reply past 24 history messages, a start with history and other bad bodies are refused", () => {
  const bad = [
    null,
    [],
    start({ kind: "end" }),
    start({ history: turns(2) }),
    reply([]),
    reply(turns(25)),
    reply([{ role: "learner", text: "Hi." }, { role: "ai", text: "Hello?" }]),
    reply([{ role: "teacher", text: "Hi." }]),
    reply([{ role: "learner", text: "x".repeat(1001) }]),
    reply([{ role: "learner", text: "   " }]),
    start({ scene: "x".repeat(4001) }),
    start({ scene: 3 }),
    start({ words: [] }),
    start({ words: Array.from({ length: 20 }, (_, i) => ({ word: `w${i}`, translation: "t" })), target: "w0" }),
    start({ words: [{ word: "", translation: "t" }], target: "" }),
    start({ words: [{ word: "shore" }] }),
    start({ target: "harbour" }),
    start({ target: 1 }),
  ];
  for (const body of bad) assert.equal(typeof parseTalkRequest(body).error, "string", JSON.stringify(body)?.slice(0, 80));
  assert.equal(parseTalkRequest(start({ scene: "x".repeat(4000) })).error, undefined, "4000 exactly");
  assert.equal(parseTalkRequest(reply([{ role: "learner", text: "x".repeat(1000) }])).error, undefined, "1000 exactly");
});

test("ADR-0007: the target stays until the learner's last message uses it, then moves to the next word, wrapping", () => {
  assert.equal(nextTarget(start()), "shore", "a start keeps the target");
  assert.equal(nextTarget(reply(turns(2, "I like the sea."))), "shore");
  assert.equal(nextTarget(reply(turns(2, "We sat on the shore."))), "tide");
  assert.equal(nextTarget(reply(turns(2, "Shores everywhere!"))), "tide", "the shared word match: an inflected form counts");
  assert.equal(nextTarget(reply(turns(2, "Thick fog."), { target: "fog" })), "shore", "wraps to the first word");
  // Only the learner's last message counts, not an earlier one or the AI's.
  const history = [{ role: "learner", text: "The shore." }, { role: "ai", text: "The shore is nice?" }, { role: "learner", text: "Yes." }];
  assert.equal(nextTarget(reply(history)), "shore");
  assert.equal(nextTarget(reply(turns(2, "The shore."), { words: [WORDS[0]] })), "shore", "one word stays itself");
});

test("talk-mission: a reply's prompt plays the mission's character in turns of at most 18 words, steering without the target", () => {
  const { system, user } = talkPrompt(reply());
  assert.match(system, /English conversation partner/);
  assert.match(system, /Ukrainian/);
  assert.match(system, /without saying the target word/i);
  assert.match(system, /at most 18 words/);
  assert.match(system, /no storytelling/i);
  assert.match(system, /never claim which words the learner used/i);
  assert.match(system, /plain text only/i);
  const data = JSON.parse(user);
  assert.equal(data.scene, SCENE);
  assert.deepEqual(data.words, WORDS);
  assert.equal(data.target, "shore");
  assert.deepEqual(data.history, turns(2));
});

test("talk-mission: a start's prompt plans a fresh mission of the given kind on 4-6 of the words, as JSON", () => {
  const { system, user } = missionPrompt(start(), "a rescue");
  assert.match(system, /pick 4-6 of the words/i);
  assert.match(system, /not a story/i);
  assert.match(system, /hidden facts/);
  assert.match(system, /one JSON object only/);
  assert.deepEqual(JSON.parse(user), { topic: SCENE, words: WORDS, kind: "a rescue" });
  assert.ok(MISSION_KINDS.length >= 6);
});

const PLAN = { title: "Fog Rescue", role: "You are a lifeguard.", goal: "Find the lost swimmer.", brief: "A nervous fisherman saw him.", words: ["Tide", "fog", "anchor"], opening: "Help! Did you see anyone out there?", picture: "A foggy beach." };

test("talk-mission: parseMission keeps the learner's spelling of the known words and refuses a broken plan", () => {
  const got = parseMission("```json\n" + JSON.stringify(PLAN) + "\n```", WORDS);
  assert.equal(got.opening, PLAN.opening);
  assert.deepEqual(got.mission.words, ["tide", "fog"], "unknown words dropped, the learner's spelling kept");
  assert.equal(got.mission.brief, PLAN.brief);
  assert.equal(parseMission("Hello there!", WORDS), null, "prose");
  assert.equal(parseMission(JSON.stringify({ ...PLAN, goal: "" }), WORDS), null, "a missing field");
  assert.equal(parseMission(JSON.stringify({ ...PLAN, words: ["anchor"] }), WORDS), null, "none of the words");
  const many = Array.from({ length: 9 }, (_, i) => ({ word: `w${i}`, translation: "t" }));
  assert.equal(parseMission(JSON.stringify({ ...PLAN, words: many.map((w) => w.word) }), many).mission.words.length, 6, "at most 6");
});

test("talk-mission: readMission flattens an object brief, cuts long fields, takes inflected words and names what is missing", () => {
  const got = readMission(`Sure! ${JSON.stringify({ ...PLAN, brief: { character: "A fisherman", secret: "He hid the boat" }, title: "x".repeat(200), words: "tides, fog" })} Enjoy.`, WORDS);
  assert.equal(got.mission.brief, "character: A fisherman. secret: He hid the boat.");
  assert.ok(got.mission.title.length <= 81);
  assert.deepEqual(got.mission.words, ["tide", "fog"]);
  assert.equal(readMission("no json here", WORDS), "not_json");
  assert.equal(readMission(JSON.stringify({ ...PLAN, opening: undefined }), WORDS), "missing_opening");
  assert.equal(readMission(JSON.stringify({ ...PLAN, words: [] }), WORDS), "no_words");
});

test("talk-mission: a picture prompt is 1 to 600 characters", () => {
  assert.deepEqual(parseTalkPictureRequest({ prompt: " A pier. " }), { prompt: "A pier." });
  for (const body of [{}, { prompt: "" }, { prompt: "x".repeat(601) }, [], null]) assert.ok(parseTalkPictureRequest(body).error);
  assert.equal(TALK_PICTURE_MODEL, "grok-imagine-image");
});

test("talk-mission: 20 talk pictures a UTC day app-wide", async () => {
  assert.equal(LEARN_TALK_PICTURE_DAY_LIMIT, 20);
  const db = sqliteD1();
  const day = new Date("2026-10-23T12:00:00.000Z");
  for (let i = 0; i < 20; i += 1) assert.equal(await takeLearnTalkPicture({ DB: db }, day), true);
  assert.equal(await takeLearnTalkPicture({ DB: db }, day), false);
});

test("0010 reverts cleanly with its down file and forgets itself", () => {
  const db = sqliteD1();
  db.raw.exec("CREATE TABLE d1_migrations (name TEXT)");
  db.raw.exec("INSERT INTO d1_migrations VALUES ('0009_speech_allowance.sql'), ('0010_talk_picture_allowance.sql')");
  db.raw.exec(readFileSync(new URL("../migrations/down/0010_talk_picture_allowance.sql", import.meta.url), "utf8"));
  assert.equal(db.raw.prepare("SELECT 1 FROM sqlite_master WHERE name = 'all_learn_talk_pictures'").get(), undefined);
  assert.deepEqual(db.raw.prepare("SELECT name FROM d1_migrations").all().map((r) => r.name), ["0009_speech_allowance.sql"]);
});

// ---- the counter ----

const at = new Date("2026-10-23T23:59:59.000Z");
const used = (db) => db.raw.prepare("SELECT utc_day, used FROM all_learn_talks ORDER BY utc_day").all().map((r) => ({ ...r }));

test("AC-24: 20 talks a UTC day app-wide; the 21st start is refused; a new day starts at zero", async () => {
  assert.equal(LEARN_TALK_DAY_LIMIT, 20);
  const db = sqliteD1();
  const env = { DB: db };
  for (let i = 0; i < 20; i += 1) assert.equal(await takeLearnTalk(env, at), true, `talk ${i + 1}`);
  assert.equal(await takeLearnTalk(env, at), false, "the 21st");
  assert.deepEqual(used(db), [{ utc_day: "2026-10-23", used: 20 }]);
  assert.equal(await takeLearnTalk(env, new Date("2026-10-24T00:00:00.000Z")), true);
  const others = ["all_learn_data", "all_learn_checks", "all_story_runs"].map((t) => db.raw.prepare(`SELECT COUNT(*) AS n FROM ${t}`).get().n);
  assert.deepEqual(others, [0, 0, 0], "no other allowance is touched");
});

test("0008 reverts cleanly with its down file and forgets itself", () => {
  const db = sqliteD1();
  db.raw.exec("CREATE TABLE d1_migrations (name TEXT)");
  db.raw.exec("INSERT INTO d1_migrations VALUES ('0007_session_title.sql'), ('0008_talk_allowance.sql')");
  db.raw.exec(readFileSync(new URL("../migrations/down/0008_talk_allowance.sql", import.meta.url), "utf8"));
  assert.equal(db.raw.prepare("SELECT 1 FROM sqlite_master WHERE name = 'all_learn_talks'").get(), undefined);
  assert.deepEqual(db.raw.prepare("SELECT name FROM d1_migrations").all().map((r) => r.name), ["0007_session_title.sql"]);
  assert.ok(db.raw.prepare("SELECT 1 FROM sqlite_master WHERE name = 'all_learn_checks'").get(), "the learn allowances stay");
});

// ---- the route ----

const today = () => new Date().toISOString().slice(0, 10);
const dayUsed = () => d1(`SELECT used FROM all_learn_talks WHERE utc_day = '${today()}'`)[0]?.used ?? 0;
const setUsed = (n) => d1(`INSERT INTO all_learn_talks (utc_day, used) VALUES ('${today()}', ${n}) ON CONFLICT (utc_day) DO UPDATE SET used = ${n}`);
const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/learn/talk`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });

test("AC-23: without the app secret nothing is spent", async () => {
  const before = { calls: (await stubCalls()).count, used: dayUsed() };
  assert.equal((await post(start(), { "content-type": "application/json" })).status, 401);
  assert.deepEqual({ calls: (await stubCalls()).count, used: dayUsed() }, before);
});

test("talk-mission: a start takes one unit, asks the cheap model once and returns the opening, the mission and its first word as target", async () => {
  const keep = dayUsed();
  const before = (await stubCalls()).count;
  const res = await post(start());
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.reply, "Morning. You look worried. What brings you here so early?");
  assert.equal(body.target, "shore");
  assert.deepEqual(body.mission.words, ["shore", "tide", "fog"]);
  assert.equal(body.mission.title, "The Lost Boat");
  assert.match(body.mission.brief, /harbour keeper/);
  assert.equal(typeof body.mission.picture, "string");
  assert.equal(dayUsed(), keep + 1);
  const calls = await stubCalls();
  assert.equal(calls.count, before + 1);
  assert.equal(calls.last.model, "claude-haiku-4-5-20251001");
  assert.match(calls.last.system, /English conversation partner/);
  const data = JSON.parse(calls.last.messages[0].content);
  assert.equal(data.topic, SCENE);
  assert.deepEqual(data.words, WORDS);
  assert.ok(MISSION_KINDS.includes(data.kind));
});

test("talk-mission: a start whose plan is not a mission gives 502 talk_failed", async () => {
  const res = await post(start({ scene: "STUB:malformed" }));
  assert.equal(res.status, 502);
  assert.equal((await res.json()).code, "talk_failed");
});

const xaiUrl = process.env.VOCAB_API_XAI_STUB_URL;
const pictureUsed = () => d1(`SELECT used FROM all_learn_talk_pictures WHERE utc_day = '${today()}'`)[0]?.used ?? 0;
const postPicture = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/learn/talk/picture`, { method: "POST", headers, body: JSON.stringify(body) });

test("talk-mission: the picture route draws one picture with the cheap model and takes one unit", async () => {
  const keep = pictureUsed();
  const before = (await (await fetch(new URL("__calls", xaiUrl))).json()).count;
  const res = await postPicture({ prompt: "A grumpy harbour keeper on a misty pier." });
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type"), /^image\//);
  assert.ok((await res.arrayBuffer()).byteLength > 0);
  assert.equal(pictureUsed(), keep + 1);
  const xai = await (await fetch(new URL("__calls", xaiUrl))).json();
  assert.equal(xai.count, before + 1);
  assert.equal(xai.last.model, "grok-imagine-image");
  assert.match(xai.last.prompt, /no text/);
  assert.equal((await postPicture({ prompt: "" })).status, 400);
  assert.equal((await postPicture({ prompt: "A pier." }, { "content-type": "application/json" })).status, 401);
});

test("AC-24: replies never take a unit and the next target follows the learner's last message", async () => {
  const keep = dayUsed();
  const res = await post(reply(turns(4, "The tide is high near the shore.")));
  assert.equal(res.status, 200);
  assert.equal((await res.json()).target, "tide");
  assert.equal((await post(reply())).status, 200);
  assert.equal(dayUsed(), keep, "no unit for a reply");
});

test("AC-24: the 21st start in a UTC day is refused 429 day_limit; replies still go through", async () => {
  const keep = dayUsed();
  setUsed(19);
  try {
    assert.equal((await post(start())).status, 200, "the 20th");
    const before = (await stubCalls()).count;
    const res = await post(start());
    assert.equal(res.status, 429);
    assert.deepEqual(await res.json(), { error: "Today's talk limit is reached. Try again tomorrow.", code: "day_limit" });
    assert.equal((await stubCalls()).count, before, "a refused start reaches no AI");
    const answer = await post(reply());
    assert.equal(answer.status, 200, "a reply inside a started talk is never refused for the limit");
    assert.equal(dayUsed(), 20);
  } finally {
    setUsed(keep);
  }
});

test("AC-24: a bad request is refused 400 bad_request and spends nothing", async () => {
  const before = { calls: (await stubCalls()).count, used: dayUsed() };
  for (const body of ["not json", reply(turns(25)), start({ history: turns(2) }), start({ target: "harbour" })]) {
    const res = await post(body);
    assert.equal(res.status, 400);
    assert.equal((await res.json()).code, "bad_request");
  }
  assert.deepEqual({ calls: (await stubCalls()).count, used: dayUsed() }, before);
});

test("ADR-0007: an AI that fails, answers nothing or too late gives 502 talk_failed", async () => {
  for (const marker of ["STUB:error", "STUB:empty", "STUB:slow"]) {
    const res = await post(reply(turns(2, `${marker} hello`)));
    assert.equal(res.status, 502, marker);
    assert.equal((await res.json()).code, "talk_failed", marker);
  }
});

test("the talk route is POST only", async () => {
  assert.equal((await fetch(`${baseUrl}/learn/talk`, { headers: appHeaders() })).status, 405);
});
