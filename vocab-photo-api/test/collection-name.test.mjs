// collection-naming (owner, 2026-10-18): POST /collections/name asks the AI for a short
// collection name. Run through `npm test`: the AI is test/anthropic-stub.mjs.
import assert from "node:assert/strict";
import { test } from "node:test";
import { appHeaders, baseUrl } from "./helpers.mjs";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();
const five = (first = "fork") => [first, "spoon", "knife", "pan", "kettle"].map((word) => ({ word, translation: `t ${word}` }));
const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/collections/name`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });

test("answers 401 without the app secret", async () => {
  const res = await post({ words: five() }, { "content-type": "application/json" });
  assert.equal(res.status, 401);
});

test("names five words with Sonnet 5.5 by default", async () => {
  const res = await post({ words: five() });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { name: "Kitchen Tools", model: "claude-sonnet-5-5" });
  const { last } = await stubCalls();
  assert.equal(last.model, "claude-sonnet-5-5");
  assert.deepEqual(JSON.parse(last.messages[0].content).words[1], { word: "spoon", translation: "t spoon" });
});

test("takes another offered Anthropic model, refuses one not offered", async () => {
  const opus = await post({ words: five(), model: "claude-opus-5-5" });
  assert.equal(opus.status, 200);
  assert.equal((await stubCalls()).last.model, "claude-opus-5-5");
  const bad = await post({ words: five(), model: "gpt-9" });
  assert.equal(bad.status, 422);
  assert.equal((await bad.json()).code, "not_offered");
});

test("refuses a bad body", async () => {
  assert.equal((await post("not json")).status, 400);
  assert.equal((await post({ words: [] })).status, 400);
  assert.equal((await post({ words: [{ word: "  " }] })).status, 400);
  assert.equal((await post({ words: Array.from({ length: 51 }, () => ({ word: "a" })) })).status, 400);
});

test("cleans a long quoted name to 60 code points at a word", async () => {
  const res = await post({ words: five("STUB:long") });
  assert.equal(res.status, 200);
  const { name } = await res.json();
  assert.ok([...name].length <= 60, name);
  assert.ok(!name.includes('"') && !name.endsWith(".") && !name.endsWith(" "), name);
  assert.ok(name.startsWith("Very long name"), name);
});

for (const marker of ["STUB:error", "STUB:malformed", "STUB:empty"]) {
  test(`answers 502 naming_failed on ${marker}`, async () => {
    const res = await post({ words: five(marker) });
    assert.equal(res.status, 502);
    assert.equal((await res.json()).code, "naming_failed");
  });
}

const describe = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/collections/description`, { method: "POST", headers, body: JSON.stringify(body) });
const twenty = (first = "fork") => [first, ...Array.from({ length: 19 }, (_, i) => `w${i}`)].map((word) => ({ word }));

test("description: 401 without the secret, 200 with Sonnet 5.5", async () => {
  assert.equal((await describe({ words: twenty() }, { "content-type": "application/json" })).status, 401);
  const res = await describe({ words: twenty() });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { description: "Words for cooking at home: tools and actions.", model: "claude-sonnet-5-5" });
  assert.equal((await stubCalls()).last.model, "claude-sonnet-5-5");
});

test("description: a long answer is cut to 300 code points at a word, no quotes", async () => {
  const { description } = await (await describe({ words: twenty("STUB:long") })).json();
  assert.ok([...description].length <= 300, description);
  assert.ok(!description.startsWith('"') && !description.endsWith(" "), description);
});

for (const marker of ["STUB:error", "STUB:malformed"]) {
  test(`description: 502 description_failed on ${marker}`, async () => {
    const res = await describe({ words: twenty(marker) });
    assert.equal(res.status, 502);
    assert.equal((await res.json()).code, "description_failed");
  });
}

const autofill = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/collections/autofill`, { method: "POST", headers, body: JSON.stringify(body) });

test("autofill: many collections in one AI call, only what each wants", async () => {
  assert.equal((await autofill({ collections: [] }, { "content-type": "application/json" })).status, 401);
  const before = (await stubCalls()).count;
  const res = await autofill({
    collections: [
      { id: "a", words: five(), want: ["name"] },
      { id: "b", words: twenty(), want: ["name", "description"] },
      { id: "c", words: twenty(), want: ["description"] },
      { id: "STUB:skip", words: five(), want: ["name"] },
    ],
  });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.model, "claude-sonnet-5-5");
  assert.deepEqual(body.collections, [
    { id: "a", name: "Name a" },
    { id: "b", name: "Name b", description: "About b." },
    { id: "c", description: "About c." },
  ]);
  const calls = await stubCalls();
  assert.equal(calls.count, before + 1);
  const sent = JSON.parse(calls.last.messages[0].content).collections;
  assert.deepEqual(sent.map((c) => c.want), [["name"], ["name", "description"], ["description"], ["name"]]);
});

test("autofill: sends at most 30 words a collection, refuses bad bodies", async () => {
  const many = Array.from({ length: 45 }, (_, i) => ({ word: `w${i}` }));
  assert.equal((await autofill({ collections: [{ id: "a", words: many, want: ["description"] }] })).status, 200);
  assert.equal(JSON.parse((await stubCalls()).last.messages[0].content).collections[0].words.length, 30);
  assert.equal((await autofill({ collections: [{ id: "a", words: five(), want: [] }] })).status, 400);
  assert.equal((await autofill({ collections: [{ id: "a", words: five(), want: ["name"] }, { id: "a", words: five(), want: ["name"] }] })).status, 400);
  assert.equal((await autofill({ collections: Array.from({ length: 101 }, (_, i) => ({ id: `c${i}`, words: five(), want: ["name"] })) })).status, 400);
});

for (const marker of ["STUB:error", "STUB:malformed"]) {
  test(`autofill: 502 autofill_failed on ${marker}`, async () => {
    const res = await autofill({ collections: [{ id: marker, words: five(), want: ["name"] }] });
    assert.equal(res.status, 502);
    assert.equal((await res.json()).code, "autofill_failed");
  });
}
