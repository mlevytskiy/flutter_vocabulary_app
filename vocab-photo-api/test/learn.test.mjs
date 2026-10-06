// The web learn page, the no-words page and the coming-soon page
// (learn-part-step-1 T3: AC-04, AC-06, AC-08, AC-08b, AC-09).
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { baseUrl, get, pagePost, publish, storedRows } from "./helpers.mjs";

const revsOf = (row) => ({ word: row.word_rev, translation: row.translation_rev, definition: row.definition_rev });

const IDS = [
  "mnemonic-story",
  "match-synonyms",
  "match-antonyms",
  "match-definitions",
  "pick-the-answer",
  "fill-the-gaps",
  "remember-or-not",
  "own-sentences",
  "translate-sentences",
  "own-sentences-spoken",
  "translate-sentences-spoken",
];

/** The page without its inline stylesheet, whose comments hold words of their own. */
const withoutStyle = (html) => html.replace(/<style>[\s\S]*?<\/style>/, "");

async function learn(id, query = "") {
  const res = await get(`/s/${id}/learn${query}`);
  return { res, html: withoutStyle(await res.text()) };
}

/** The `<input …>` tag of one exercise's checkbox. */
function inputOf(html, exerciseId) {
  const m = html.match(new RegExp(`<input[^>]*value="${exerciseId}"[^>]*>`));
  assert.ok(m, `no checkbox for ${exerciseId}`);
  return m[0];
}

test("AC-04, AC-08: the learn page shows the word count, three steps and the eleven exercises in order", async () => {
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "", definition: "a fruit" },
      { word: "blank", translation: "  ", definition: "" },
    ],
  });
  const { res, html } = await learn(id);

  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type") ?? "", /text\/html/);
  assert.equal(res.headers.get("cache-control"), "no-store");
  assert.match(res.headers.get("content-security-policy") ?? "", /script-src 'self'/);
  assert.match(res.headers.get("content-security-policy") ?? "", /form-action 'none'/);
  assert.match(html, /<h1>Learn<\/h1>/);
  assert.match(html, /2 words/);
  for (const step of ["Step 1", "Step 2", "Step 3"]) assert.match(html, new RegExp(`<h2>${step}</h2>`));

  const positions = IDS.map((x) => html.indexOf(`value="${x}"`));
  assert.ok(positions.every((p) => p > 0), "every exercise is listed");
  assert.deepEqual([...positions].sort((a, b) => a - b), positions, "plan order");
  assert.ok(html.indexOf("Step 1") < positions[0] && positions[3] < html.indexOf("Step 2"));
  assert.ok(positions[4] < html.indexOf("Step 3") && html.indexOf("Step 3") < positions[7]);

  assert.doesNotMatch(inputOf(html, "mnemonic-story"), /disabled/);
  for (const x of IDS.slice(1)) assert.match(inputOf(html, x), /disabled/);
  assert.equal((html.match(/Coming soon/g) ?? []).length, 10);
  assert.equal((html.match(/class="exercise soon"/g) ?? []).length, 10);
  assert.match(html, /<input type="checkbox"/);
  assert.match(html, /<label/);
});

test("AC-04: one word reads '1 word'", async () => {
  const { id } = await publish();
  assert.match((await learn(id)).html, /1 word(?!s)/);
});

test("AC-08: Start is an unavailable a.btn with the hint, nothing ticked, no pick", async () => {
  const { id } = await publish();
  const { html } = await learn(id);

  assert.match(html, /<a [^>]*class="btn start"[^>]*aria-disabled="true"/);
  assert.match(html, /Pick at least one exercise/);
  assert.match(html, /aria-live/);
  assert.doesNotMatch(html, /\bchecked\b/);
});

test("AC-06: pick=mnemonic-story ticks it; coming-soon, unknown, empty and repeated picks are ignored", async () => {
  const { id } = await publish();

  const ticked = (await learn(id, "?pick=mnemonic-story")).html;
  assert.match(inputOf(ticked, "mnemonic-story"), /\bchecked\b/);
  assert.equal((ticked.match(/\bchecked\b/g) ?? []).length, 1);
  assert.match(ticked, /href="\/s\/[^"]*\/learn\/mnemonic-story\?pick=mnemonic-story"[^>]*class="btn start"|class="btn start"[^>]*href="\/s\/[^"]*\/learn\/mnemonic-story\?pick=mnemonic-story"/);

  for (const q of ["?pick=match-synonyms", "?pick=nope", "?pick=", "?pick=%3Cb%3E"]) {
    const { res, html } = await learn(id, q);
    assert.equal(res.status, 200, q);
    assert.doesNotMatch(html, /\bchecked\b/, q);
  }

  const repeated = (await learn(id, "?pick=mnemonic-story&pick=mnemonic-story&pick=nope")).html;
  assert.equal((repeated.match(/\bchecked\b/g) ?? []).length, 1);
});

test("AC-08b: a live session with no word to learn answers the no-words page, 200, linking to the list", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "" }, { word: "", translation: "x" }] });
  const { res, html } = await learn(id);

  assert.equal(res.status, 200);
  assert.equal(res.headers.get("cache-control"), "no-store");
  assert.match(html, /<h1>No words to learn<\/h1>/);
  assert.match(html, new RegExp(`href="/s/${id}"`));
  assert.doesNotMatch(html, /Step 1/);
  assert.doesNotMatch(html, /type="checkbox"/);
});

test("AC-08b: a deleted row does not count as a word to learn", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const [seed] = storedRows(id);
  const del = await pagePost(`/s/${id}/rows/delete`, { rowId: seed.id, revs: revsOf(seed) });
  assert.equal(del.status, 200);

  const { res, html } = await learn(id);
  assert.equal(res.status, 200);
  assert.match(html, /<h1>No words to learn<\/h1>/);
});

test("a stored word containing markup renders as text on the learn pages", async () => {
  const { id } = await publish({ entries: [{ word: "<script>alert(1)</script>", translation: "<b>x</b>" }] });
  for (const path of [`/s/${id}/learn`, `/s/${id}/learn/mnemonic-story`]) {
    const html = withoutStyle(await (await get(path)).text());
    assert.doesNotMatch(html, /<script>alert/);
    assert.doesNotMatch(html, /<b>x<\/b>/);
  }
});

test("the coming-soon page for mnemonic-story names the exercise and links back with the same pick", async () => {
  const { id } = await publish();
  const res = await get(`/s/${id}/learn/mnemonic-story?pick=mnemonic-story&pick=nope`);
  const html = withoutStyle(await res.text());

  assert.equal(res.status, 200);
  assert.equal(res.headers.get("cache-control"), "no-store");
  assert.match(res.headers.get("content-security-policy") ?? "", /script-src 'self'/);
  assert.match(html, /<h1>Mnemonic story<\/h1>/);
  assert.match(html, /Coming soon — this exercise is not ready yet\./);
  assert.match(html, new RegExp(`href="/s/${id}/learn\\?pick=mnemonic-story"`));
  assert.match(html, /Back to exercises/);
  assert.doesNotMatch(html, /\d+ words?\b/);

  const bare = withoutStyle(await (await get(`/s/${id}/learn/mnemonic-story`)).text());
  assert.match(bare, new RegExp(`href="/s/${id}/learn"`));
});

// OQ-1 (provisional): a live session with no word to learn still answers the coming-soon page.
test("OQ-1: the coming-soon page for a live session with no word to learn is the 200 page", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "" }] });
  const res = await get(`/s/${id}/learn/mnemonic-story`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /<h1>Mnemonic story<\/h1>/);
});

test("AC-09: a dead session or an unusable exercise answers byte-for-byte the shared page's gone answer", async () => {
  const live = await publish();
  const reference = await get(`/s/${randomUUID()}`);
  const refBody = await reference.text();
  assert.equal(reference.status, 404);

  const paths = [
    `/s/${randomUUID()}/learn`,
    `/s/${randomUUID()}/learn/mnemonic-story`,
    `/s/${live.id}/learn/match-synonyms`,
    `/s/${live.id}/learn/nope`,
    `/s/${randomUUID()}/learn/nope`,
  ];
  for (const path of paths) {
    const res = await get(path);
    assert.equal(res.status, 404, path);
    assert.equal(await res.text(), refBody, path);
    assert.deepEqual(
      [...res.headers].filter(([k]) => ["content-type", "cache-control", "content-security-policy", "referrer-policy", "x-content-type-options"].includes(k)),
      [...reference.headers].filter(([k]) => ["content-type", "cache-control", "content-security-policy", "referrer-policy", "x-content-type-options"].includes(k)),
      path,
    );
  }
});

test("a path the pattern does not accept gets the router's JSON 404, and a POST is a 405", async () => {
  const { id } = await publish();
  const res = await fetch(`${baseUrl}/s/${id}/learn/a/b`);
  assert.equal(res.status, 404);
  assert.match(res.headers.get("content-type") ?? "", /json/);
  assert.equal((await fetch(`${baseUrl}/s/${id}/learn`, { method: "POST" })).status, 405);
});

test("the learn pages use the shared stylesheet (one CSP hash) and fit a 320 px column", async () => {
  const { id } = await publish();
  const learnRes = await get(`/s/${id}/learn`);
  const sharedRes = await get(`/s/${id}`);
  const styleSrc = (res) => (res.headers.get("content-security-policy") ?? "").match(/style-src [^;]+/)?.[0];
  assert.ok(styleSrc(learnRes));
  assert.equal(styleSrc(learnRes), styleSrc(sharedRes));
  const html = await learnRes.text();
  assert.equal((html.match(/<style>/g) ?? []).length, 1);
  assert.match(html, /<meta name="viewport"/);
});
