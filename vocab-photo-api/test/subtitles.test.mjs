// words-from-subtitles T4: POST /subtitles/words, one test per response in
// docs/features/words-from-subtitles/contracts/openapi.yaml. The AI is the local
// stub (test/anthropic-stub.mjs); the allowance is the real D1 tables.
import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const aiCalls = async () => (await (await fetch(`${stubUrl}__calls`)).json()).count;

const asked = ["reluctant", "tide", "harbour", "fog", "grab", "rope", "lift", "drift", "wary", "shore", "stern", "gale", "moor"]
  .map((word) => ({ word, context: `A line with ${word} in it.` }));
const marker = (word) => [{ word, context: "" }];

const request = (overrides = {}) => ({
  words: asked,
  maximum: 20,
  model: "claude-sonnet-5",
  sessionWords: [],
  ...overrides,
});

async function pick(body, headers = appHeaders({ "content-type": "application/json" })) {
  const res = await fetch(`${baseUrl}/subtitles/words`, {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

// The day total is shared by every address, so each test starts from an empty day.
beforeEach(() => d1("DELETE FROM all_subtitle_imports"));

// Ten imports from one address must land in one 10-minute window. They take
// about a second against the stub, so 10 s left in the window is plenty; waiting
// for a full minute's margin cost up to a minute of every run.
async function awayFromWindowEdge() {
  const intoWindow = Date.now() % (10 * 60 * 1000);
  const left = 10 * 60 * 1000 - intoWindow;
  if (left < 10_000) await new Promise((ok) => setTimeout(ok, left + 1000));
}

test("200: ranked words, at most the maximum, no session word in any case, no duplicates, plus model, time and usage", async () => {
  const { status, body } = await pick(request({ maximum: 5, sessionWords: ["TIDE", "fog"] }));
  assert.equal(status, 200);
  assert.deepEqual(
    body.words.map((w) => w.word),
    ["reluctant", "harbour", "grab", "rope", "lift"],
  );
  for (const w of body.words) assert.deepEqual(Object.keys(w).sort(), ["context", "translation", "word"]);
  assert.deepEqual(body.words[0], { word: "reluctant", translation: "переклад reluctant", context: "A line with reluctant in it." });
  assert.equal(body.model, "claude-sonnet-5");
  assert.equal(typeof body.timings.aiMs, "number");
  assert.deepEqual(body.usage, { inputTokens: 1200, outputTokens: 340 });
});

test("200: a larger maximum keeps the same words on top (the cut is in rank order)", async () => {
  const twenty = (await pick(request({ maximum: 20 }))).body.words.map((w) => w.word);
  const three = (await pick(request({ maximum: 3 }))).body.words.map((w) => w.word);
  assert.deepEqual(twenty.slice(0, 3), three);
  assert.ok(twenty.length < 20, "the maximum is a limit, not a target: fewer came back, fewer are returned");
});

test("200: no word qualifies gives an empty list with the model, time and usage", async () => {
  const { status, body } = await pick(request({ words: marker("STUB:empty"), model: "claude-haiku-4-5-20251001" }));
  assert.equal(status, 200);
  assert.deepEqual(body.words, []);
  assert.equal(body.model, "claude-haiku-4-5-20251001");
});

test("the chosen model and the phone's words with their context reach the AI as JSON; the session words and lines do not", async () => {
  const words = [{ word: "reluctant", context: "I was reluctant to leave." }, { word: "harbour", context: "The harbour." }];
  await pick(request({ model: "claude-opus-5-5", words, lines: ["An excerpt line."], maximum: 7, sessionWords: ["secretword"] }));
  const { last } = await (await fetch(`${stubUrl}__calls`)).json();
  assert.equal(last.model, "claude-opus-5-5");
  assert.equal(last.messages[0].content, `<words>\n${JSON.stringify(words)}\n</words>\n\nTranslate these words.`);
  assert.ok(!JSON.stringify(last).includes("secretword"));
  assert.ok(!JSON.stringify(last).includes("An excerpt line."), "lines go only with dialogues");
});

test("a word the AI returns that was not asked is dropped", async () => {
  const { body } = await pick(request({ words: asked.filter((w) => w.word !== "harbour") }));
  assert.ok(body.words.length > 0);
  assert.ok(!body.words.some((w) => w.word === "harbour"));
});

test("a purpose or level from an older app is ignored", async () => {
  const { status } = await pick(request({ purpose: "understand_film", level: "B2" }));
  assert.equal(status, 200);
  const { last } = await (await fetch(`${stubUrl}__calls`)).json();
  assert.doesNotMatch(last.system, /B2/);
});

test("401: no app secret, nothing picked and the allowance untouched", async () => {
  const before = await aiCalls();
  const { status, body } = await pick(request(), { "content-type": "application/json", "cf-connecting-ip": "203.0.113.50" });
  assert.equal(status, 401);
  assert.deepEqual(body, { error: "Unauthorized" });
  assert.equal(await aiCalls(), before);
});

test("400 bad_request for every out-of-bounds field, before the allowance or the AI", async () => {
  const before = await aiCalls();
  const cases = [
    "not json",
    { ...request(), lines: ["x".repeat(201)] },
    { ...request(), lines: [""] },
    { ...request(), dialogues: true },
    { ...request(), dialogues: true, lines: [] },
    { ...request(), maximum: 0 },
    { ...request(), maximum: 101 },
    { ...request(), maximum: 2.5 },
    { ...request(), words: [] },
    { ...request(), words: ["reluctant"] },
    { ...request(), words: [{ word: " ", context: "" }] },
    { ...request(), words: [{ word: "x".repeat(101), context: "" }] },
    { ...request(), words: [{ word: "fog" }] },
    { ...request(), words: [{ word: "fog", context: "x".repeat(603) }] },
    { ...request(), words: Array.from({ length: 111 }, (_, i) => ({ word: `w${i}`, context: "" })) },
    (({ words, ...rest }) => rest)(request()),
    { ...request(), sessionWords: Array.from({ length: 501 }, (_, i) => `w${i}`) },
    { ...request(), sessionWords: ["x".repeat(501)] },
    (({ sessionWords, ...rest }) => rest)(request()),
  ];
  for (const body of cases) {
    const res = await pick(body);
    assert.equal(res.status, 400, JSON.stringify(body).slice(0, 80));
    assert.equal(res.body.code, "bad_request");
    assert.equal(typeof res.body.error, "string");
  }
  assert.equal(await aiCalls(), before);
  assert.equal(d1("SELECT count(*) AS n FROM all_subtitle_imports")[0].n, 0);
});

test("400 unknown_model for a model off the allow-list", async () => {
  const { status, body } = await pick(request({ model: "claude-fable-5-1" }));
  assert.equal(status, 400);
  assert.equal(body.code, "unknown_model");
});

test("413 too_large past 1 MB of lines; exactly 1 MB is accepted", async () => {
  const line = "a".repeat(200);
  const full = Array.from({ length: 1048576 / 200 }, () => line); // 5242 lines, 1,048,400 bytes
  full.push("b".repeat(1048576 - full.length * 200)); // top up to exactly 1,048,576
  const ok = await pick(request({ lines: full, maximum: 1 }));
  assert.equal(ok.status, 200);
  const over = await pick(request({ lines: [...full, "c"] }));
  assert.equal(over.status, 413);
  assert.equal(over.body.code, "too_large");
});

test("502 words_not_picked for a cut-off, malformed, refused, failed or too-late reply; never a partial list", async () => {
  for (const line of ["STUB:cutoff", "STUB:malformed", "STUB:refusal", "STUB:error", "STUB:slow:6000"]) {
    const { status, body } = await pick(request({ words: marker(line) }));
    assert.equal(status, 502, line);
    assert.equal(body.code, "words_not_picked", line);
    assert.equal(body.words, undefined, line);
  }
});

test("429 too_many_imports: the 11th import from one address in a window is refused and the AI called 10 times", async () => {
  await awayFromWindowEdge();
  const ip = "203.0.113.11";
  const before = await aiCalls();
  for (let i = 0; i < 10; i++) {
    assert.equal((await pick(request(), appHeaders({ "content-type": "application/json", "cf-connecting-ip": ip }))).status, 200);
  }
  const { status, body } = await pick(request(), appHeaders({ "content-type": "application/json", "cf-connecting-ip": ip }));
  assert.equal(status, 429);
  assert.equal(body.code, "too_many_imports");
  assert.equal((await aiCalls()) - before, 10);
});

test("429 too_many_imports: the 21st import of a UTC day is refused, from any address", async () => {
  await awayFromWindowEdge();
  for (let i = 0; i < 20; i++) {
    const ip = `203.0.113.${20 + (i % 3)}`;
    assert.equal((await pick(request(), appHeaders({ "content-type": "application/json", "cf-connecting-ip": ip }))).status, 200, `import ${i + 1}`);
  }
  const { status, body } = await pick(request(), appHeaders({ "content-type": "application/json", "cf-connecting-ip": "203.0.113.99" }));
  assert.equal(status, 429);
  assert.equal(body.code, "too_many_imports");
});

const zenStubUrl = process.env.VOCAB_API_ZEN_STUB_URL;
const zenCalls = async () => (await fetch(`${zenStubUrl}__calls`)).json();

test("an OpenCode Zen model: the same words go to Zen's chat completions with the Zen key, and its translations come back", async () => {
  const anthropicBefore = await aiCalls();
  const { status, body } = await pick(request({ model: "deepseek-v4.1-flash", maximum: 3, sessionWords: ["tide"] }));
  assert.equal(status, 200);
  assert.deepEqual(body.words, [
    { word: "reluctant", translation: "зен reluctant", context: "A line with reluctant in it." },
    { word: "harbour", translation: "зен harbour", context: "A line with harbour in it." },
    { word: "fog", translation: "зен fog", context: "A line with fog in it." },
  ]);
  assert.equal(body.model, "deepseek-v4.1-flash");
  assert.deepEqual(body.usage, { inputTokens: 910, outputTokens: 275 });
  const { last, lastAuth, lastPath } = await zenCalls();
  assert.equal(lastPath, "/chat/completions");
  assert.equal(lastAuth, "Bearer test-key");
  assert.equal(last.model, "deepseek-v4.1-flash");
  assert.equal(last.messages[0].role, "system");
  assert.equal(await aiCalls(), anthropicBefore, "Anthropic is not asked");
});

test("an OpenCode Zen model: a cut-off or failed reply is words_not_picked", async () => {
  for (const marker of ["STUB:cutoff", "STUB:error", "STUB:empty"]) {
    const { status, body } = await pick(request({ model: "kimi-k3", words: [{ word: marker, context: "" }] }));
    assert.equal(status, 502, marker);
    assert.equal(body.code, "words_not_picked", marker);
  }
});

test("a context of three full lines (602 characters) is accepted", async () => {
  const { status } = await pick(request({ words: [{ word: "reluctant", context: "x".repeat(602) }] }));
  assert.equal(status, 200);
});
