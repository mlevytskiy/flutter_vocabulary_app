// mnemonic-story T7: the offered AI list route and the grouping route (AC-03, AC-04, AC-12;
// ADR-0004, ADR-0005). Run through `npm test`: they need the local Worker, whose Anthropic
// calls go to test/anthropic-stub.mjs.
import assert from "node:assert/strict";
import { test } from "node:test";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;

const words = (n, prefix = "w") => Array.from({ length: n }, (_, i) => ({ rowId: `${prefix}${i}`, word: `${prefix}word${i}` }));
const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/story/grouping`, {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();

test("both routes answer 401 without the app secret", async () => {
  assert.equal((await fetch(`${baseUrl}/story/models`)).status, 401);
  assert.equal((await fetch(`${baseUrl}/story/models`, { headers: { "x-app-secret": "wrong" } })).status, 401);
  assert.equal(
    (await fetch(`${baseUrl}/story/grouping`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ words: words(20), keep: [] }),
    })).status,
    401,
  );
});

test("AC-12: the models route returns the offered list with the defaults and no internal fields", async () => {
  const res = await fetch(`${baseUrl}/story/models`, { headers: appHeaders() });
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type") ?? "", /application\/json/);
  const body = await res.json();
  assert.equal(body.pricesAsOf, "2026-10-07");
  assert.deepEqual(body.defaults, { story: "claude-sonnet-5-5", prompt: "claude-sonnet-5-5", picture: "grok-imagine-image" });
  assert.deepEqual(Object.keys(body).sort(), ["defaults", "models", "pricesAsOf"]);
  const ids = body.models.map((m) => m.id);
  assert.ok(ids.includes("claude-sonnet-5-5") && ids.includes("claude-opus-5-5") && ids.includes("grok-imagine-image"));
  assert.ok(!ids.includes("claude-haiku-4-5-20251001"), "the grouping AI is not offered");
  const sonnet = body.models.find((m) => m.id === "claude-sonnet-5-5");
  assert.deepEqual(sonnet, {
    id: "claude-sonnet-5-5", name: "Sonnet 5.5", provider: "anthropic", role: "text",
    inputUsdPerMTok: 2, outputUsdPerMTok: 10, estimate15Usd: 0.008,
  });
  for (const model of body.models) assert.equal("provisional" in model, false, `${model.id} leaks provisional`);
});

test("AC-03: the grouping route returns a valid AI split unchanged, asking the fixed Haiku model", async () => {
  const before = (await stubCalls()).count;
  const keep = [{ id: "g1", name: "Sea", rowIds: ["k1", "k2"] }];
  const res = await post({ words: [...words(18), { rowId: "k1", word: "tide" }, { rowId: "k2", word: "harbour" }], keep });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(body.groups[0], { id: "g1", name: "Sea", rowIds: ["k1", "k2"] });
  assert.equal(body.groups.length, 2);
  assert.equal(body.groups[1].rowIds.length, 18);
  const seen = await stubCalls();
  assert.equal(seen.count, before + 1);
  assert.equal(seen.last.model, "claude-haiku-4-5-20251001");
  const sent = JSON.parse(seen.last.messages[0].content);
  assert.equal(sent.words.length, 20);
  assert.deepEqual(sent.keep, keep);
});

test("AC-03: a request without a keep list is a plain split", async () => {
  const res = await post({ words: words(8) });
  assert.equal(res.status, 200);
  assert.equal((await res.json()).groups.length, 1);
});

test("AC-04: an AI that fails, refuses or returns broken JSON gives a clean 502, never the raw reply", async () => {
  for (const marker of ["STUB:error", "STUB:refusal", "STUB:malformed", "STUB:no-groups"]) {
    const res = await post({ words: [{ rowId: "x", word: marker }, ...words(7)], keep: [] });
    assert.equal(res.status, 502, marker);
    assert.deepEqual(await res.json(), { error: "Could not group the words", code: "grouping_failed" }, marker);
  }
});

test("the grouping route does not count against the story allowance", async () => {
  const day = new Date().toISOString().slice(0, 10);
  const read = () => JSON.stringify(d1("SELECT used FROM all_story_runs WHERE utc_day = '" + day + "'"));
  const before = read();
  assert.equal((await post({ words: words(20) })).status, 200);
  assert.equal(read(), before);
});

test("grouping request validation: empty list, too many words, malformed body", async () => {
  const bad = async (body, headers) => {
    const res = await post(body, headers);
    assert.equal(res.status, 400, JSON.stringify(body).slice(0, 80));
    assert.equal(typeof (await res.json()).error, "string");
  };
  const before = (await stubCalls()).count;
  await bad({ words: [], keep: [] });
  await bad({ words: words(501), keep: [] });
  await bad("not json");
  await bad("[1,2]");
  await bad({ keep: [] });
  await bad({ words: "apple" });
  await bad({ words: [{ rowId: "a" }] });
  await bad({ words: [{ rowId: "", word: "x" }] });
  await bad({ words: [{ rowId: "a", word: "  " }] });
  await bad({ words: [{ rowId: "a", word: 3 }] });
  await bad({ words: [{ rowId: "a", word: "x" }, { rowId: "a", word: "y" }] });
  await bad({ words: words(8), keep: "none" });
  await bad({ words: words(8), keep: [{ id: "g", name: "n", rowIds: "a" }] });
  await bad({ words: words(8), keep: [{ id: "", name: "n", rowIds: ["a"] }] });
  await bad({ words: words(8), keep: [{ id: "g", name: "n", rowIds: [1] }] });
  assert.equal((await stubCalls()).count, before, "a bad request never reaches the AI");
});

test("the grouping route is POST only", async () => {
  const res = await fetch(`${baseUrl}/story/grouping`, { headers: appHeaders() });
  assert.equal(res.status, 405);
});
