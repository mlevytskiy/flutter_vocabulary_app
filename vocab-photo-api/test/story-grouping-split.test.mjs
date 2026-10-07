// mnemonic-story T7 fix: the Worker checks the AI's split with the app's own rules
// (lib/core/story/word_grouping.dart applySplit, ADR-0005) and repairs it, so the app never
// gets a split it rejects (AC-03, AC-04). Pure unit tests over grouping.ts, plus the route
// through the local Worker for the retry path.
import assert from "node:assert/strict";
import { test } from "node:test";
import { groupingPrompt, repairSplit, validateSplit } from "../src/story/grouping.ts";
// The route tests need the local Worker (`npm test`); the unit tests above them run on their own.
const { appHeaders, baseUrl } = process.env.VOCAB_API_BASE_URL ? await import("./helpers.mjs") : {};

const ids = (prefix, from, to) => Array.from({ length: to - from }, (_, i) => `${prefix}${from + i}`);
const wordsOf = (rowIds) => rowIds.map((rowId) => ({ rowId, word: `word-${rowId}` }));
const plainRequest = (n) => ({ words: wordsOf(ids("w", 0, n)), keep: [] });
const sizes = (groups) => groups.map((g) => g.rowIds.length);
const allIds = (groups) => groups.flatMap((g) => g.rowIds).sort();

/** What applySplit accepts, restated independently of the code under test. */
function assertAppAccepts(request, groups) {
  const keepIds = new Set(request.keep.flatMap((k) => k.rowIds));
  const newIds = request.words.map((w) => w.rowId).filter((id) => !keepIds.has(id));
  const placeable = [...keepIds, ...newIds].sort();
  assert.deepEqual(allIds(groups), placeable, "every word exactly once");
  const used = new Set();
  for (const k of request.keep) {
    const g = groups.find((x) => x.id === k.id);
    assert.ok(g, `keep ${k.id} present`);
    assert.ok(!used.has(k.id));
    used.add(k.id);
    assert.ok(k.rowIds.every((r) => g.rowIds.includes(r)), `keep ${k.id} intact`);
    assert.ok(g.rowIds.length <= 19, `keep ${k.id} <= 19`);
  }
  const fresh = groups.filter((g) => g.id === undefined);
  assert.equal(groups.length, fresh.length + request.keep.length, "no group has an unknown id");
  for (const g of fresh) {
    assert.ok(g.rowIds.length >= 1 && g.rowIds.length <= 19, `fresh size ${g.rowIds.length}`);
    if (g.rowIds.length < 7) assert.ok(newIds.length < 7, "a small new group only when fewer than 7 new words");
    assert.equal(typeof g.name, "string");
    assert.ok(g.name.trim() !== "");
  }
}

// The exact reply Haiku gave live for 45 words: 10 groups of 2,4,4,4,5,5,5,6,5,5, ids invented.
function liveBadReply() {
  const topics = ["fruits", "actions", "transport", "emotions", "professions", "colors", "weather", "phrasal verbs", "foods", "tools"];
  const counts = [2, 4, 4, 4, 5, 5, 5, 6, 5, 5];
  let at = 0;
  return topics.map((t, i) => {
    const rowIds = ids("w", at, at + counts[i]);
    at += counts[i];
    return { id: t.split(" ")[0], name: t[0].toUpperCase() + t.slice(1), rowIds };
  });
}

test("the live bad reply (10 small groups with invented ids) is invalid, with reasons", () => {
  const problems = validateSplit(plainRequest(45), liveBadReply());
  assert.ok(problems.length > 0);
  assert.ok(problems.some((p) => /id/.test(p)), problems.join("; "));
  assert.ok(problems.some((p) => /fewer than 7|7 to 19/.test(p)), problems.join("; "));
});

test("the live bad reply is repaired into groups of 7 to 19 that the app accepts", () => {
  const request = plainRequest(45);
  const fixed = repairSplit(request, liveBadReply());
  assert.ok(fixed);
  assertAppAccepts(request, fixed);
  assert.deepEqual(validateSplit(request, fixed), []);
  assert.ok(fixed.length >= 3 && fixed.length <= 6, `groups: ${sizes(fixed)}`);
});

test("a valid split is left exactly as the AI gave it", () => {
  const request = plainRequest(20);
  const groups = [{ name: "A", rowIds: ids("w", 0, 10) }, { name: "B", rowIds: ids("w", 10, 20) }];
  assert.deepEqual(validateSplit(request, groups), []);
  assert.deepEqual(repairSplit(request, groups), groups);
});

test("one oversized group is split evenly", () => {
  const request = plainRequest(45);
  const fixed = repairSplit(request, [{ name: "Everything", rowIds: ids("w", 0, 45) }]);
  assertAppAccepts(request, fixed);
  assert.deepEqual(sizes(fixed), [15, 15, 15]);
});

test("a group of 20 is cut into two groups of 10", () => {
  const request = plainRequest(20);
  const fixed = repairSplit(request, [{ name: "Big", rowIds: ids("w", 0, 20) }]);
  assertAppAccepts(request, fixed);
  assert.deepEqual(sizes(fixed), [10, 10]);
});

test("missing, duplicate and unknown rowIds are fixed", () => {
  const request = plainRequest(20);
  const groups = [
    { name: "A", rowIds: [...ids("w", 0, 9), "ghost", "w1"] },
    { name: "B", rowIds: [...ids("w", 9, 17), "w0"] }, // w17..w19 missing
  ];
  assert.ok(validateSplit(request, groups).length >= 3);
  const fixed = repairSplit(request, groups);
  assertAppAccepts(request, fixed);
  assert.ok(!allIds(fixed).includes("ghost"));
});

test("reply entries that are not groups, a missing name and a missing rowIds list are tolerated", () => {
  const request = plainRequest(14);
  const fixed = repairSplit(request, [null, 5, { rowIds: ids("w", 0, 14) }, { name: "Empty" }, { name: "X", rowIds: "no" }]);
  assertAppAccepts(request, fixed);
  assert.equal(fixed[0].name, "Words");
});

test("undersized groups are merged: smallest into the smallest other, name kept short", () => {
  const request = plainRequest(24);
  const groups = [
    { name: "Fruit", rowIds: ids("w", 0, 3) },
    { name: "Boats", rowIds: ids("w", 3, 8) },
    { name: "Weather", rowIds: ids("w", 8, 24) },
  ];
  const fixed = repairSplit(request, groups);
  assertAppAccepts(request, fixed);
  assert.deepEqual(sizes(fixed).sort((a, b) => a - b), [8, 16]);
  const merged = fixed.find((g) => g.rowIds.length === 8);
  assert.equal(merged.name, "Fruit & Boats");
  for (const g of fixed) assert.ok(g.name.length <= 40);
});

test("a long merged name falls back to the larger group's name", () => {
  const request = plainRequest(17);
  const long = "An extremely long group name that goes on";
  const fixed = repairSplit(request, [
    { name: long, rowIds: ids("w", 0, 11) },
    { name: "Another quite long group name here", rowIds: ids("w", 11, 17) },
  ]);
  assertAppAccepts(request, fixed);
  assert.equal(fixed.length, 1);
  assert.equal(fixed[0].name, long);
});

test("keep groups: invented ids are stripped, real keep ids stay, the keep group stays intact", () => {
  const keep = [{ id: "K1", name: "Sea", rowIds: ids("k", 0, 8) }];
  const request = { words: wordsOf([...ids("k", 0, 8), ...ids("n", 0, 16)]), keep };
  const groups = [
    { id: "K1", name: "Sea renamed", rowIds: ids("k", 0, 8) },
    { id: "fruits", name: "Fruits", rowIds: ids("n", 0, 8) },
    { id: "K1", name: "dup keep id", rowIds: ids("n", 8, 16) },
  ];
  const fixed = repairSplit(request, groups);
  assertAppAccepts(request, fixed);
  assert.equal(fixed[0].id, "K1");
  assert.equal(fixed[0].name, "Sea", "a keep group keeps its name");
});

test("keep groups: a dropped keep word, an omitted keep group and a keep group over 19 are repaired", () => {
  const keep = [
    { id: "K1", name: "Sea", rowIds: ids("k", 0, 17) },
    { id: "K2", name: "Sky", rowIds: ids("j", 0, 8) },
  ];
  const request = { words: wordsOf([...ids("k", 0, 17), ...ids("j", 0, 8), ...ids("n", 0, 10)]), keep };
  const groups = [
    { id: "K1", name: "Sea", rowIds: [...ids("k", 1, 17), ...ids("n", 0, 5)] }, // k0 dropped, 21 words
    { name: "Rest", rowIds: ids("n", 5, 10) },
  ];
  assert.ok(validateSplit(request, groups).length > 0);
  const fixed = repairSplit(request, groups);
  assertAppAccepts(request, fixed);
  assert.ok(fixed.find((g) => g.id === "K2"));
});

test("new words left over after the keep groups took some are not left as a group under 7 when 7+ are new", () => {
  const keep = [{ id: "K1", name: "Sea", rowIds: ids("k", 0, 15) }];
  const request = { words: wordsOf([...ids("k", 0, 15), ...ids("n", 0, 8)]), keep };
  const groups = [
    { id: "K1", name: "Sea", rowIds: [...ids("k", 0, 15), ...ids("n", 0, 4)] },
    { name: "Rest", rowIds: ids("n", 4, 8) },
  ];
  assert.ok(validateSplit(request, groups).length > 0);
  assertAppAccepts(request, repairSplit(request, groups));
});

test("fewer than 7 new words may wait in a group under 7 (the app's exception)", () => {
  const keep = [{ id: "K1", name: "Sea", rowIds: ids("k", 0, 19) }];
  const request = { words: wordsOf([...ids("k", 0, 19), ...ids("n", 0, 4)]), keep };
  const groups = [{ id: "K1", name: "Sea", rowIds: ids("k", 0, 19) }, { name: "Few", rowIds: ids("n", 0, 4) }];
  assert.deepEqual(validateSplit(request, groups), []);
  assertAppAccepts(request, repairSplit(request, groups));
  // several small groups (and a missing word) collapse into one
  const split = [{ id: "K1", name: "Sea", rowIds: ids("k", 0, 19) }, { name: "a", rowIds: ["n0", "n1"] }, { name: "b", rowIds: ["n2"] }];
  const fixed = repairSplit(request, split);
  assertAppAccepts(request, fixed);
  assert.equal(fixed.length, 2);
});

test("a reply that is not a split at all still yields a valid split", () => {
  const request = plainRequest(30);
  assertAppAccepts(request, repairSplit(request, []));
});

test("the prompt states the number of words, the target number of new groups and the id rule", () => {
  const { system, user } = groupingPrompt(plainRequest(45));
  assert.match(system, /never fewer than 7, never more than 19/i);
  assert.match(system, /do not give new groups an id/i);
  const sent = JSON.parse(user);
  assert.equal(sent.wordCount, 45);
  assert.equal(sent.newWordCount, 45);
  assert.equal(sent.newGroups, 3); // round(45 / 15)
  assert.deepEqual(sent.newGroupsBetween, [3, 6]); // ceil(45/19) .. floor(45/7)
  assert.ok(Array.isArray(sent.words) && Array.isArray(sent.keep));
});

test("the prompt target is clamped into the allowed range", () => {
  const sent = (n) => JSON.parse(groupingPrompt(plainRequest(n)).user);
  assert.equal(sent(20).newGroups, 2); // round(1.33)=1 clamped up to ceil(20/19)=2
  assert.equal(sent(8).newGroups, 1);
  assert.equal(sent(5).newGroups, 0); // fewer than 7 new words: no new group needed
});

// ---- the route: retry once, then repair ----
const post = (body) =>
  fetch(`${baseUrl}/story/grouping`, { method: "POST", headers: appHeaders({ "content-type": "application/json" }), body: JSON.stringify(body) });
const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();
const marked = (marker, n = 44) => ({ words: [{ rowId: "m", word: marker }, ...wordsOf(ids("r", 0, n))], keep: [] });

test("route: a bad first reply is retried once with what was wrong, and the good retry is returned", { skip: !stubUrl || !baseUrl }, async () => {
  const before = (await stubCalls()).count;
  const request = marked("STUB:small-groups");
  const res = await post(request);
  assert.equal(res.status, 200);
  const body = await res.json();
  assertAppAccepts(request, body.groups);
  const seen = await stubCalls();
  assert.equal(seen.count, before + 2, "asked twice");
  const second = JSON.parse(seen.last.messages[0].content);
  assert.ok(Array.isArray(second.problems) && second.problems.length > 0, "the retry lists what was wrong");
});

test("route: still wrong after the retry is repaired, never sent as is (45 words, two asks)", { skip: !stubUrl || !baseUrl }, async () => {
  const before = (await stubCalls()).count;
  const request = marked("STUB:small-always");
  const res = await post(request);
  assert.equal(res.status, 200);
  assertAppAccepts(request, (await res.json()).groups);
  assert.equal((await stubCalls()).count, before + 2);
});

test("route: a valid first reply is asked only once", { skip: !stubUrl || !baseUrl }, async () => {
  const before = (await stubCalls()).count;
  const request = plainRequest(30);
  const res = await post(request);
  assert.equal(res.status, 200);
  assertAppAccepts(request, (await res.json()).groups);
  assert.equal((await stubCalls()).count, before + 1);
});
