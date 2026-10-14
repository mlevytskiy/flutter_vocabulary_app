// learn-kit: POST /learn/data, the exercise data service (spec AC-20 – AC-27; decisions S-14 – S-17,
// S-19). The pure rules are tested directly; the route runs against the local Worker, whose AI is
// test/anthropic-stub.mjs and whose LEARN_DATA namespace is simulated by `wrangler dev`.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { appHeaders, baseUrl } from "./helpers.mjs";
import { cacheKey, checkValue, parseDataReply, parseDataRequest } from "../src/learn/data.ts";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();

/** Words unique to this call, so the shared local cache never answers for another test. */
const fresh = (n, translation = "переклад") => {
  const tag = randomUUID().slice(0, 8);
  return Array.from({ length: n }, (_, i) => ({ rowId: `r${i}`, word: `word${tag}x${i}`, translation: `${translation} ${tag}` }));
};

const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/learn/data`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });

// ---- the pure rules ----

test("S-14: a valid request is accepted as it is, trimmed words kept as sent", () => {
  const words = [{ rowId: "a", word: "bank", translation: "берег" }, { rowId: "b", word: "run", translation: "" }];
  assert.deepEqual(parseDataRequest({ kind: "synonym", words }), { kind: "synonym", words });
});

test("AC-23: a bad request is refused with a plain reason", () => {
  const ok = { rowId: "a", word: "bank", translation: "берег" };
  const bad = [
    null,
    [],
    { kind: "synonym" },
    { kind: "synonym", words: [] },
    { kind: "synonym", words: Array.from({ length: 20 }, (_, i) => ({ ...ok, rowId: `r${i}` })) },
    { kind: "antonym", words: [ok] },
    { kind: "synonym", words: [ok, { ...ok }] },
    { kind: "synonym", words: [{ ...ok, word: "  " }] },
    { kind: "synonym", words: [{ ...ok, word: "x".repeat(101) }] },
    { kind: "synonym", words: [{ ...ok, translation: "x".repeat(201) }] },
    { kind: "synonym", words: [{ ...ok, rowId: "" }] },
    { kind: "synonym", words: [{ ...ok, rowId: "x".repeat(101) }] },
    { kind: "synonym", words: [{ ...ok, translation: 3 }] },
    { kind: "synonym", words: ["bank"] },
  ];
  for (const body of bad) {
    const parsed = parseDataRequest(body);
    assert.equal(typeof parsed.error, "string", JSON.stringify(body)?.slice(0, 80));
  }
  assert.equal(parseDataRequest({ kind: "synonym", words: Array.from({ length: 19 }, (_, i) => ({ ...ok, rowId: `r${i}` })) }).error, undefined);
  assert.equal(parseDataRequest({ kind: "synonym", words: [{ ...ok, word: "x".repeat(100), translation: "y".repeat(200) }] }).error, undefined);
});

test("S-16: the cache key covers kind, word and translation, lower-cased and trimmed", async () => {
  const a = await cacheKey("synonym", " Bank ", "Берег ");
  assert.match(a, /^learn:v1:synonym:[0-9a-f]{64}$/);
  assert.equal(a, await cacheKey("synonym", "bank", "берег"));
  assert.notEqual(a, await cacheKey("synonym", "bank", "банк"), "AC-22: another translation is another key");
  assert.notEqual(a, await cacheKey("definition", "bank", "берег"));
});

test("S-15, AC-25: each kind's value rule", () => {
  const w = { rowId: "a", word: "bank", translation: "берег" };
  const good = {
    synonym: { synonym: "shore" },
    definition: { definition: "The land along the side of a river." },
    clues: { clues: ["It is near water.", "You can sit on it by a river.", "The side of a river."] },
    sentence: { sentence: "We sat on the bank of the river." },
    pattern: { sentence: "We sat on the bank all day.", pattern: "sit on the [noun] of [noun]", usage: "places by water" },
    translate: { source: "Ми сиділи на березі річки.", cue: "березі", model: "We sat on the bank of the river." },
  };
  for (const [kind, value] of Object.entries(good)) assert.deepEqual(checkValue(kind, value, w), value, kind);
  // Extra keys are dropped.
  assert.deepEqual(checkValue("synonym", { synonym: "shore", note: "x" }, w), { synonym: "shore" });

  const broken = {
    synonym: [{ synonym: "Bank" }, { synonym: "x".repeat(41) }, { synonym: "" }, {}],
    definition: [{ definition: "x".repeat(161) }, { definition: 3 }],
    clues: [{ clues: ["a", "b"] }, { clues: ["a", "b", "x".repeat(121)] }, { clues: ["a", "", "c"] }, { clues: "abc" }],
    sentence: [
      { sentence: "There is no such word here." },
      { sentence: "The bank by the bank." },
      { sentence: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen bank" },
      { sentence: `The bank ${"x".repeat(120)}` },
    ],
    pattern: [
      { sentence: "We sat on the bank.", pattern: "sit on the bank of [noun]", usage: "u" },
      { sentence: "We sat on the bank.", pattern: "sit on the [thing]", usage: "u" },
      { sentence: "We sat on the bank.", pattern: "sit on it", usage: "u" },
      { sentence: "We sat on the bank.", pattern: "x [noun]".padEnd(61, "x"), usage: "u" },
      { sentence: "We sat on the bank.", pattern: "[noun]", usage: "x".repeat(61) },
      { sentence: "No word.", pattern: "[noun]", usage: "u" },
    ],
    translate: [
      { source: "Ми сиділи на bank річки.", cue: "на", model: "We sat on the bank." },
      { source: "Ми сиділи на березі.", cue: "бережок", model: "We sat on the bank." },
      { source: "Ми сиділи на березі.", cue: "березі", model: "We sat there." },
      { source: "Ми сиділи на березі.", cue: "", model: "We sat on the bank." },
    ],
  };
  for (const [kind, values] of Object.entries(broken)) {
    for (const value of values) assert.equal(checkValue(kind, value, w), undefined, `${kind} ${JSON.stringify(value)}`);
  }
  // "Once" uses the story word check: -s/-ed/-ing forms count, a word inside another does not.
  assert.ok(checkValue("sentence", { sentence: "Two banks closed." }, w));
  assert.equal(checkValue("sentence", { sentence: "Bankruptcy is near." }, w), undefined);
  // The pattern slots allowed.
  for (const slot of ["[noun]", "[verb]", "[adjective]", "[sentence]", "[verb in Past Simple]"]) {
    assert.ok(checkValue("pattern", { sentence: "We sat on the bank.", pattern: `I ${slot}`, usage: "u" }, w), slot);
  }
});

test("S-17: the reply is a JSON object with items, a fenced block allowed", () => {
  assert.deepEqual(parseDataReply('{"items": [{"rowId": "a", "none": true}]}'), [{ rowId: "a", none: true }]);
  assert.deepEqual(parseDataReply('```json\n{"items": []}\n```'), []);
  assert.equal(parseDataReply("Here you are."), undefined);
  assert.equal(parseDataReply('{"words": []}'), undefined);
  assert.equal(parseDataReply("[1]"), undefined);
});

// ---- the route ----

test("AC-26: without the app secret nothing is generated", async () => {
  const before = (await stubCalls()).count;
  const res = await post({ kind: "synonym", words: fresh(3) }, { "content-type": "application/json" });
  assert.equal(res.status, 401);
  assert.equal((await post({ kind: "synonym", words: fresh(3) }, { "content-type": "application/json", "x-app-secret": "wrong" })).status, 401);
  assert.equal((await stubCalls()).count, before);
});

test("AC-20: one AI request answers every word of the group, in the sense of its translation", async () => {
  const words = fresh(10);
  const before = (await stubCalls()).count;
  const res = await post({ kind: "synonym", words });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.kind, "synonym");
  assert.deepEqual(body.results.map((r) => r.rowId), words.map((w) => w.rowId), "request order");
  assert.deepEqual(body.results[0].value, { synonym: `similar to ${words[0].word}` });
  const calls = await stubCalls();
  assert.equal(calls.count, before + 1, "one AI request");
  assert.equal(calls.last.model, "claude-haiku-4-5-20251001");
  assert.equal(calls.last.max_tokens, 3000);
  const sent = JSON.parse(calls.last.messages[0].content);
  assert.equal(sent.kind, "synonym");
  assert.deepEqual(sent.words, words, "word and translation go to the AI as JSON data");
});

test("AC-20: a word the AI has no answer for comes back null", async () => {
  const words = [...fresh(3), { rowId: "n", word: "STUB:none", translation: randomUUID() }];
  const body = await (await post({ kind: "definition", words })).json();
  assert.equal(body.results[3].value, null);
  assert.ok(body.results[0].value.definition);
});

test("AC-21: an answered word is served from the cache for 30 days: no AI request, no allowance", async () => {
  const words = fresh(5);
  await post({ kind: "clues", words });
  const before = (await stubCalls()).count;
  // Other row ids, same words and translations, as from another session.
  const again = words.map((w, i) => ({ ...w, rowId: `other${i}` }));
  const res = await post({ kind: "clues", words: again });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(body.results.map((r) => r.rowId), again.map((w) => w.rowId));
  assert.equal(body.results[0].value.clues.length, 3);
  assert.equal((await stubCalls()).count, before, "no AI request");
});

test("AC-21: a real 'none' is cached too", async () => {
  const words = [{ rowId: "n", word: "STUB:none", translation: randomUUID() }];
  await post({ kind: "synonym", words });
  const before = (await stubCalls()).count;
  const body = await (await post({ kind: "synonym", words })).json();
  assert.equal(body.results[0].value, null);
  assert.equal((await stubCalls()).count, before);
});

test("AC-21: only the misses are sent to the AI", async () => {
  const words = fresh(4);
  await post({ kind: "sentence", words: words.slice(0, 2) });
  await post({ kind: "sentence", words });
  const sent = JSON.parse((await stubCalls()).last.messages[0].content);
  assert.deepEqual(sent.words.map((w) => w.rowId), ["r2", "r3"]);
});

test("AC-22: a changed translation is not answered from the old entry", async () => {
  const [word] = fresh(1);
  await post({ kind: "definition", words: [word] });
  const before = (await stubCalls()).count;
  const body = await (await post({ kind: "definition", words: [{ ...word, translation: "інший сенс" }] })).json();
  assert.equal((await stubCalls()).count, before + 1);
  assert.equal(body.results[0].value.definition, "The sense of інший сенс.");
});

test("AC-25: a word whose answer breaks its rule comes back null and is asked again next time", async () => {
  for (const kind of ["synonym", "definition", "clues", "sentence", "pattern", "translate"]) {
    const words = [...fresh(2), { rowId: "b", word: "STUB:broken", translation: randomUUID() }, { rowId: "m", word: "STUB:missing", translation: randomUUID() }];
    const body = await (await post({ kind, words })).json();
    assert.equal(body.results[2].value, null, kind);
    assert.equal(body.results[3].value, null, `${kind}: a word the reply leaves out`);
    assert.ok(body.results[0].value, kind);
    const before = (await stubCalls()).count;
    await post({ kind, words: words.slice(2) });
    assert.equal((await stubCalls()).count, before + 1, `${kind}: the broken answer was not cached`);
    const sent = JSON.parse((await stubCalls()).last.messages[0].content);
    assert.deepEqual(sent.words.map((w) => w.rowId), ["b", "m"]);
  }
});

test("AC-23: a bad request reaches nothing and takes nothing", async () => {
  const before = (await stubCalls()).count;
  for (const body of ["not json", { kind: "antonym", words: fresh(2) }, { kind: "synonym", words: fresh(20) }, { kind: "synonym", words: [] }]) {
    const res = await post(body);
    assert.equal(res.status, 400);
    const reply = await res.json();
    assert.equal(reply.code, "bad_request");
    assert.equal(typeof reply.error, "string");
  }
  assert.equal((await stubCalls()).count, before);
});

test("AC-24: an AI that fails, refuses, answers unreadably or too late gives 502 learn_failed; nothing is cached", async () => {
  for (const marker of ["STUB:error", "STUB:refusal", "STUB:malformed", "STUB:slow"]) {
    const words = [...fresh(2), { rowId: "x", word: marker, translation: randomUUID() }];
    const res = await post({ kind: "synonym", words });
    assert.equal(res.status, 502, marker);
    assert.equal((await res.json()).code, "learn_failed", marker);
    const before = (await stubCalls()).count;
    await post({ kind: "synonym", words: words.slice(0, 2) });
    assert.equal((await stubCalls()).count, before + 1, `${marker}: nothing was cached`);
  }
});

test("the data route is POST only", async () => {
  assert.equal((await fetch(`${baseUrl}/learn/data`, { headers: appHeaders() })).status, 405);
});
