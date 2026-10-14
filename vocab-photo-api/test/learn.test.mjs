// The web learn page, the no-words page and the coming-soon page
// (learn-part-step-1 T3: AC-04, AC-06, AC-08, AC-08b, AC-09).
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { baseUrl, get, pagePost, publish, storedRows } from "./helpers.mjs";

const revsOf = (row) => ({ word: row.word_rev, translation: row.translation_rev, definition: row.definition_rev });

// The plan after learn-kit (S-02, AC-01): six in Step 1, three in Step 2, four in Step 3.
const IDS = [
  "mnemonic-story",
  "dialogs-from-movie",
  "match-synonyms",
  "match-definitions",
  "guess-my-word",
  "pick-the-answer",
  "fill-the-gaps",
  "remember-or-not",
  "sentence-patterns",
  "own-sentences",
  "translate-sentences",
  "explain-to-friend",
  "quiz",
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

test("AC-04, AC-08: the learn page shows the word count, three steps and the thirteen exercises in order", async () => {
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
  assert.ok(html.indexOf("Step 1") < positions[0] && positions[5] < html.indexOf("Step 2"));
  assert.ok(html.indexOf("Step 2") < positions[6] && positions[8] < html.indexOf("Step 3"));
  assert.ok(html.indexOf("Step 3") < positions[9]);

  assert.doesNotMatch(inputOf(html, "mnemonic-story"), /disabled/);
  assert.doesNotMatch(inputOf(html, "dialogs-from-movie"), /disabled/);
  assert.doesNotMatch(inputOf(html, "pick-the-answer"), /disabled/);
  assert.doesNotMatch(inputOf(html, "remember-or-not"), /disabled/);
  assert.doesNotMatch(inputOf(html, "match-synonyms"), /disabled/);
  for (const x of IDS.slice(2).filter((x) => x !== "pick-the-answer" && x !== "remember-or-not" && x !== "match-synonyms")) assert.match(inputOf(html, x), /disabled/);
  assert.equal((html.match(/Coming soon/g) ?? []).length, 8);
  assert.equal((html.match(/class="exercise soon"/g) ?? []).length, 8);
  assert.match(html, /<input type="checkbox"/);
  assert.match(html, /<label/);
});

test("AC-16, AC-22: Dialogs from movie can be ticked, and Start leads to the coming-soon page", async () => {
  const { id } = await publish();

  const ticked = (await learn(id, "?pick=dialogs-from-movie")).html;
  assert.match(inputOf(ticked, "dialogs-from-movie"), /\bchecked\b/);
  assert.equal((ticked.match(/\bchecked\b/g) ?? []).length, 1);
  const href = `/s/${id}/learn/dialogs-from-movie\\?pick=dialogs-from-movie`;
  assert.match(ticked, new RegExp(`class="btn start"[^>]*href="${href}"|href="${href}"[^>]*class="btn start"`));

  const res = await get(`/s/${id}/learn/dialogs-from-movie?pick=dialogs-from-movie`);
  const html = withoutStyle(await res.text());
  assert.equal(res.status, 200);
  assert.match(html, /<h1>Dialogs from movie<\/h1>/);
  assert.match(html, /Coming soon — this exercise is not ready yet\./);
  assert.match(html, new RegExp(`href="/s/${id}/learn\\?pick=dialogs-from-movie"`));
  assert.doesNotMatch(html, /<button|<input|<form/);
});

test("learn-pick-the-answer AC-19: Pick the right answer is listed in Step 1, can be ticked, and the page has no way to play it", async () => {
  const { id } = await publish();
  const ticked = (await learn(id, "?pick=pick-the-answer")).html;
  assert.match(inputOf(ticked, "pick-the-answer"), /\bchecked\b/);
  assert.match(ticked, /Pick the right answer/);

  const res = await get(`/s/${id}/learn/pick-the-answer?pick=pick-the-answer`);
  const html = withoutStyle(await res.text());
  assert.equal(res.status, 200);
  assert.match(html, /<h1>Pick the right answer<\/h1>/);
  assert.match(html, /Coming soon — this exercise is not ready yet\./);
  assert.doesNotMatch(html, /<button|<input|<form/);
});

test("learn-remember-or-not AC-20: Remember or not is listed in Step 2, can be ticked, and the page has no way to play it", async () => {
  const { id } = await publish();
  const ticked = (await learn(id, "?pick=remember-or-not")).html;
  assert.match(inputOf(ticked, "remember-or-not"), /\bchecked\b/);
  assert.match(ticked, /Remember or not/);
  const res = await get(`/s/${id}/learn/remember-or-not?pick=remember-or-not`);
  const html = withoutStyle(await res.text());
  assert.equal(res.status, 200);
  assert.match(html, /<h1>Remember or not<\/h1>/);
  assert.match(html, /Coming soon — this exercise is not ready yet\./);
  assert.doesNotMatch(html, /<button|<input|<form/);
});

test("learn-match-synonyms AC-23: Match synonyms is listed in Step 1, can be ticked, and the page has no way to play it", async () => {
  const { id } = await publish();
  const ticked = (await learn(id, "?pick=match-synonyms")).html;
  assert.match(inputOf(ticked, "match-synonyms"), /\bchecked\b/);
  assert.match(ticked, /Match synonyms/);
  const res = await get(`/s/${id}/learn/match-synonyms?pick=match-synonyms`);
  const html = withoutStyle(await res.text());
  assert.equal(res.status, 200);
  assert.match(html, /<h1>Match synonyms<\/h1>/);
  assert.match(html, /Coming soon — this exercise is not ready yet\./);
  assert.doesNotMatch(html, /<button|<input|<form/);
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

  for (const q of ["?pick=quiz", "?pick=nope", "?pick=", "?pick=%3Cb%3E"]) {
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

test("learn-kit AC-02: an old link naming a removed exercise answers the gone page; a pick naming it is ignored", async () => {
  const live = await publish();
  const refBody = await (await get(`/s/${randomUUID()}`)).text();
  for (const removed of ["match-antonyms", "own-sentences-spoken", "translate-sentences-spoken", "chain-story"]) {
    const res = await get(`/s/${live.id}/learn/${removed}`);
    assert.equal(res.status, 404, removed);
    assert.equal(await res.text(), refBody, removed);
    const page = await learn(live.id, `?pick=${removed}&pick=mnemonic-story`);
    assert.equal(page.res.status, 200, removed);
    assert.equal((page.html.match(/\bchecked\b/g) ?? []).length, 1, removed);
    assert.match(inputOf(page.html, "mnemonic-story"), /\bchecked\b/);
    assert.doesNotMatch(page.html, new RegExp(`value="${removed}"`), removed);
    assert.match(page.html, /<h2>Step 3<\/h2>/);
  }
});

test("AC-09: a dead session or an unusable exercise answers byte-for-byte the shared page's gone answer", async () => {
  const live = await publish();
  const reference = await get(`/s/${randomUUID()}`);
  const refBody = await reference.text();
  assert.equal(reference.status, 404);

  const paths = [
    `/s/${randomUUID()}/learn`,
    `/s/${randomUUID()}/learn/mnemonic-story`,
    `/s/${live.id}/learn/quiz`,
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

const LEARN_SCRIPT = /<script type="module" src="(\/assets\/learn-[0-9a-f]{12}\.js)"><\/script>/;

test("AC-05, AC-07: both learn pages load the versioned learn script, served immutable; an old hash is 404", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const { res: learnRes, html: learnHtml } = await learn(id);
  const { res: soonRes, html: soonHtml } = await (async () => {
    const res = await get(`/s/${id}/learn/mnemonic-story`);
    return { res, html: withoutStyle(await res.text()) };
  })();

  const src = learnHtml.match(LEARN_SCRIPT)?.[1];
  assert.ok(src, "learn page has the script tag");
  assert.equal(soonHtml.match(LEARN_SCRIPT)?.[1], src);
  assert.equal((learnHtml.match(/<script/g) ?? []).length, 1, "no inline script");
  for (const res of [learnRes, soonRes]) {
    assert.match(res.headers.get("content-security-policy") ?? "", /script-src 'self'(;|$)/);
  }

  const js = await get(src);
  assert.equal(js.status, 200);
  assert.match(js.headers.get("content-type") ?? "", /^text\/javascript/);
  assert.equal(js.headers.get("cache-control"), "public, max-age=31536000, immutable");
  assert.equal(js.headers.get("x-content-type-options"), "nosniff");
  assert.match(await js.text(), /replaceState/);

  assert.equal((await get("/assets/learn-000000000000.js")).status, 404);
});

test("the no-words page needs no script", async () => {
  const { id } = await publish({ entries: [{ word: "blank", translation: "" }] });
  const { html } = await learn(id);
  assert.doesNotMatch(html, /<script/);
});
