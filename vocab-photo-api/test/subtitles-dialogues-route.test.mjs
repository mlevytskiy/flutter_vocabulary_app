// get-words-from-subtitles-improvment T4: POST /subtitles/words with the `dialogues` flag
// (AC-01, AC-02, AC-07, AC-08, AC-09). The AI is the local stub (test/anthropic-stub.mjs).
import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const calls = async () => (await fetch(`${stubUrl}__calls`)).json();

const asked = ["reluctant", "tide", "harbour", "fog", "grab", "rope", "lift", "drift", "wary", "shore", "stern", "gale", "moor"]
  .map((word) => ({ word, context: `A line with ${word} in it.` }));
const marker = (word) => [{ word, context: "" }];

const request = (overrides = {}) => ({
  words: asked,
  lines: ["I was reluctant to leave, but the tide was coming in.", "Grab the rope."],
  maximum: 20,
  model: "claude-sonnet-5",
  sessionWords: [],
  ...overrides,
});

async function pick(body) {
  const res = await fetch(`${baseUrl}/subtitles/words`, {
    method: "POST",
    headers: appHeaders({ "content-type": "application/json" }),
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

beforeEach(() => d1("DELETE FROM all_subtitle_imports"));

test("flag on: the reply carries the checked dialogues beside the words, and the AI is asked for them", async () => {
  const { status, body } = await pick(request({ dialogues: true }));
  assert.equal(status, 200);
  assert.deepEqual(body.dialogues, [
    { lines: ["A: You look reluctant.", "B: The tide is coming in."], words: ["reluctant", "tide"] },
    { lines: ["A: Grab the rope!", "B: Lifting it now."], words: ["grab", "rope", "lift"] },
    { lines: ["A: What fog.", "B: Yes."], words: ["fog"] },
  ]);
  assert.ok(body.words.length > 0);
  const { last } = await calls();
  assert.equal(last.max_tokens, 20000);
  assert.match(last.system, /dialogues/);
});

test("flag on: the dialogues follow the kept words (session words and the maximum cut them)", async () => {
  const { body } = await pick(request({ dialogues: true, sessionWords: ["TIDE", "fog"], maximum: 2 }));
  assert.deepEqual(body.words.map((w) => w.word), ["reluctant", "harbour"]);
  assert.deepEqual(body.dialogues, [{ lines: ["A: You look reluctant.", "B: The tide is coming in."], words: ["reluctant"] }]);
});

test("flag off, false or absent: today's response, no dialogues key, and today's request to the AI", async () => {
  for (const extra of [{}, { dialogues: false }]) {
    const { status, body } = await pick(request(extra));
    assert.equal(status, 200);
    assert.equal("dialogues" in body, false);
    assert.deepEqual(Object.keys(body).sort(), ["model", "timings", "usage", "words"]);
    const { last } = await calls();
    assert.equal(last.max_tokens, 16000);
    assert.doesNotMatch(last.system, /"dialogues"/);
  }
});

test("flag on, no qualifying dialogue: dialogues is an empty list and the words still come (AC-07)", async () => {
  const { status, body } = await pick(request({ dialogues: true, words: [...marker("STUB:no-dialogues"), ...asked] }));
  assert.equal(status, 200);
  assert.deepEqual(body.dialogues, []);
  assert.ok(body.words.length > 0);
});

test("a malformed dialogues flag is bad_request and nothing is asked", async () => {
  const before = (await calls()).count;
  for (const dialogues of ["true", 1, null, [], {}]) {
    const { status, body } = await pick(request({ dialogues }));
    assert.equal(status, 400);
    assert.equal(body.code, "bad_request");
  }
  assert.equal((await calls()).count, before);
});

test("flag on, cut-off reply: words_not_picked, neither words nor dialogues (AC-08)", async () => {
  const { status, body } = await pick(request({ dialogues: true, words: marker("STUB:cutoff") }));
  assert.equal(status, 502);
  assert.equal(body.code, "words_not_picked");
  assert.equal("dialogues" in body, false);
  assert.equal("words" in body, false);
});

test("flag on, reply without the dialogues list: words_not_picked (complete or nothing, AC-08)", async () => {
  const { status, body } = await pick(request({ dialogues: true, words: marker("STUB:bad-dialogues") }));
  assert.equal(status, 502);
  assert.equal(body.code, "words_not_picked");
});

test("flag on takes one allowance unit per import, like flag off", async () => {
  await pick(request({ dialogues: true }));
  assert.equal(d1("SELECT sum(used) AS n FROM all_subtitle_imports")[0].n, 1);
  await pick(request());
  assert.equal(d1("SELECT sum(used) AS n FROM all_subtitle_imports")[0].n, 2);
});
