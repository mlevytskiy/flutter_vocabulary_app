// learn-redesign openai-voice: POST /learn/speech, the AI's voice in Talk (spec AC-31, ADR-0009
// amendment, sad §5.2). The pure rules, the counter and the missing-key answer run directly (the counter
// against the real schema in node:sqlite); the route runs against the local Worker, whose OpenAI is
// test/openai-stub.mjs and whose speech day row is seeded through d1() and put back afterwards.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { sqliteD1 } from "./sqlite-d1.mjs";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";
import { LEARN_SPEECH_DAY_LIMIT, takeLearnSpeech } from "../src/learn/allowance.ts";
import { learnSpeechRoute, parseSpeechRequest, SPEECH_INSTRUCTIONS, SPEECH_VOICES } from "../src/learn/speech.ts";

const stubUrl = process.env.VOCAB_API_OPENAI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();
const SPEECH_BYTES = [0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x21, 0xff, 0xfb];

// ---- the pure rules ----

test("openai-voice: a text with a known voice is accepted; the voice defaults to coral", () => {
  assert.deepEqual(parseSpeechRequest({ text: "Hello!", voice: "nova" }), { text: "Hello!", voice: "nova" });
  assert.deepEqual(parseSpeechRequest({ text: "Hello!" }), { text: "Hello!", voice: "coral" });
  assert.equal(parseSpeechRequest({ text: "x".repeat(1200) }).error, undefined, "1200 characters is the most");
  assert.deepEqual(
    [...SPEECH_VOICES].sort(),
    ["alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer", "verse"],
  );
});

test("openai-voice: a missing, blank or too long text and an unknown voice are refused", () => {
  for (const body of [null, [], {}, { text: "" }, { text: "   " }, { text: 3 }, { text: "x".repeat(1201) }, { text: "Hi", voice: "robot" }, { text: "Hi", voice: 1 }]) {
    assert.equal(typeof parseSpeechRequest(body).error, "string", JSON.stringify(body));
  }
});

// ---- the counter ----

test("openai-voice: 400 speech units a UTC day, then refused; a new day starts again", async () => {
  const db = sqliteD1();
  const env = { DB: db };
  const at = new Date("2026-10-23T12:00:00.000Z");
  db.raw.exec("INSERT INTO all_learn_speech (utc_day, used) VALUES ('2026-10-23', 399)");
  assert.equal(LEARN_SPEECH_DAY_LIMIT, 400);
  assert.equal(await takeLearnSpeech(env, at), true, "the 400th");
  assert.equal(await takeLearnSpeech(env, at), false, "the 401st");
  assert.equal(await takeLearnSpeech(env, new Date("2026-10-24T00:00:00.000Z")), true);
  const others = ["all_learn_data", "all_learn_checks", "all_learn_talks"].map((t) => db.raw.prepare(`SELECT COUNT(*) AS n FROM ${t}`).get().n);
  assert.deepEqual(others, [0, 0, 0], "no other allowance is touched");
});

test("0009 reverts cleanly with its down file and forgets itself", () => {
  const db = sqliteD1();
  db.raw.exec("CREATE TABLE d1_migrations (name TEXT)");
  db.raw.exec("INSERT INTO d1_migrations VALUES ('0008_talk_allowance.sql'), ('0009_speech_allowance.sql')");
  db.raw.exec(readFileSync(new URL("../migrations/down/0009_speech_allowance.sql", import.meta.url), "utf8"));
  assert.equal(db.raw.prepare("SELECT 1 FROM sqlite_master WHERE name = 'all_learn_speech'").get(), undefined);
  assert.deepEqual(db.raw.prepare("SELECT name FROM d1_migrations").all().map((r) => r.name), ["0008_talk_allowance.sql"]);
  assert.ok(db.raw.prepare("SELECT 1 FROM sqlite_master WHERE name = 'all_learn_talks'").get(), "the talk allowance stays");
});

test("openai-voice: without OPENAI_API_KEY the route answers 503 speech_unavailable and takes no unit", async () => {
  const db = sqliteD1();
  const request = new Request("http://worker/learn/speech", { method: "POST", body: JSON.stringify({ text: "Hello!" }) });
  const res = await learnSpeechRoute.handler({ request, env: { DB: db }, url: new URL(request.url), params: {} });
  assert.equal(res.status, 503);
  assert.equal((await res.json()).code, "speech_unavailable");
  assert.equal(db.raw.prepare("SELECT COUNT(*) AS n FROM all_learn_speech").get().n, 0);
});

// ---- the route ----

const today = () => new Date().toISOString().slice(0, 10);
const dayUsed = () => d1(`SELECT used FROM all_learn_speech WHERE utc_day = '${today()}'`)[0]?.used ?? 0;
const setUsed = (n) => d1(`INSERT INTO all_learn_speech (utc_day, used) VALUES ('${today()}', ${n}) ON CONFLICT (utc_day) DO UPDATE SET used = ${n}`);
const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/learn/speech`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });

test("openai-voice: without the app secret nothing is spent", async () => {
  const before = { calls: (await stubCalls()).count, used: dayUsed() };
  assert.equal((await post({ text: "Hello!" }, { "content-type": "application/json" })).status, 401);
  assert.deepEqual({ calls: (await stubCalls()).count, used: dayUsed() }, before);
});

test("openai-voice: a line takes one unit, asks gpt-4o-mini-tts once and passes the mp3 bytes through", async () => {
  const keep = dayUsed();
  const before = (await stubCalls()).count;
  const res = await post({ text: "Do you like the sea?", voice: "sage" });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("content-type"), "audio/mpeg");
  assert.deepEqual([...new Uint8Array(await res.arrayBuffer())], SPEECH_BYTES);
  assert.equal(dayUsed(), keep + 1);
  const calls = await stubCalls();
  assert.equal(calls.count, before + 1);
  assert.equal(calls.lastPath, "/v1/audio/speech");
  assert.equal(calls.lastAuth, "Bearer test-key");
  assert.deepEqual(calls.last, {
    model: "gpt-4o-mini-tts",
    voice: "sage",
    input: "Do you like the sea?",
    instructions: SPEECH_INSTRUCTIONS,
    response_format: "mp3",
  });
  assert.equal(SPEECH_INSTRUCTIONS, "Speak slowly and clearly, like a friendly English teacher talking to a learner.");
});

test("openai-voice: without a voice the stub hears coral", async () => {
  assert.equal((await post({ text: "Hello!" })).status, 200);
  assert.equal((await stubCalls()).last.voice, "coral");
});

test("openai-voice: a bad request is refused 400 bad_request and spends nothing", async () => {
  const before = { calls: (await stubCalls()).count, used: dayUsed() };
  for (const body of ["not json", { text: "" }, { text: "x".repeat(1201) }, { text: "Hi", voice: "robot" }]) {
    const res = await post(body);
    assert.equal(res.status, 400);
    assert.equal((await res.json()).code, "bad_request");
  }
  assert.deepEqual({ calls: (await stubCalls()).count, used: dayUsed() }, before);
});

test("openai-voice: an OpenAI error or a reply too late gives 502 speech_failed", async () => {
  for (const marker of ["STUB:error", "STUB:slow"]) {
    const res = await post({ text: `${marker} hello` });
    assert.equal(res.status, 502, marker);
    assert.equal((await res.json()).code, "speech_failed", marker);
  }
});

test("openai-voice: the 401st line in a UTC day is refused 429 day_limit and reaches no OpenAI", async () => {
  const keep = dayUsed();
  setUsed(399);
  try {
    assert.equal((await post({ text: "Hello!" })).status, 200, "the 400th");
    const before = (await stubCalls()).count;
    const res = await post({ text: "Hello again!" });
    assert.equal(res.status, 429);
    assert.equal((await res.json()).code, "day_limit");
    assert.equal((await stubCalls()).count, before);
    assert.equal(dayUsed(), 400);
  } finally {
    setUsed(keep);
  }
});

test("the speech route is POST only", async () => {
  assert.equal((await fetch(`${baseUrl}/learn/speech`, { headers: appHeaders() })).status, 405);
});
