// The smoke test (docs/testing.md): one walk through every route the app and
// the shared page use, a few requests each, so `npm test` answers "does the
// Worker still work?" in seconds. It checks that each route answers and hands
// its result to the next step -- the edge cases live in the other files, which
// run with `npm run test:full`. Keep it fast: no sleeps, no bulk data, no
// wrangler subprocesses.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { appHeaders, baseUrl, get, pagePost, publish, storedRows, uploadSource } from "./helpers.mjs";

const SET_URL = "https://quizlet.com/987534268/job-interview-flash-cards/";

async function appPost(path, body) {
  const res = await fetch(`${baseUrl}${path}`, {
    method: "POST",
    headers: appHeaders({ "content-type": "application/json" }),
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

test("smoke: the secret-gated routes refuse a request without the app secret", async () => {
  for (const path of ["/analyze", "/define", "/sessions", "/subtitles/words"]) {
    const res = await fetch(`${baseUrl}${path}`, { method: "POST", body: "{}" });
    assert.equal(res.status, 401, path);
  }
});

test("smoke: publish, photo, page, edit, add, delete, poll, autofill, download, republish", async () => {
  // The app publishes a session with a photo and a Quizlet set (POST /sessions).
  const photo = randomUUID();
  const set = randomUUID();
  const first = await publish({
    detail: "both",
    sources: [
      { id: photo, order: 0 },
      { id: set, order: 1, kind: "set", name: "Job interview", url: SET_URL },
    ],
    entries: [
      { word: "apple", translation: "яблуко", sourceId: photo },
      { word: "kettle", translation: "чайник", sourceId: set },
      { word: "pear", translation: "груша" },
    ],
  });
  const { id, editToken } = first;
  assert.match(first.url, new RegExp(`/s/${id}$`));

  // ...then uploads the photo's bytes in the background.
  assert.equal((await uploadSource(id, photo, Buffer.from("photo bytes"))).status, 200);
  const bytes = await get(`/s/${id}/sources/${photo}`);
  assert.equal(bytes.status, 200);
  assert.equal(await bytes.text(), "photo bytes");

  // The partner opens the page: rows, the set, the CSP and the page script.
  const page = await get(`/s/${id}`);
  assert.equal(page.status, 200);
  assert.match(page.headers.get("content-security-policy") ?? "", /default-src 'none'/);
  const html = await page.text();
  assert.match(html, /apple[\s\S]*kettle[\s\S]*pear/);
  assert.match(html, /Job interview/);
  const script = html.match(/src="(\/assets\/page-[0-9a-f]{12}\.js)"/)[1];
  assert.equal((await get(script)).status, 200);

  // The partner edits a cell, adds a row and deletes one.
  const [apple, kettle, pear] = storedRows(id);
  const saved = await pagePost(`/s/${id}/cells`, { rowId: apple.id, field: "translation", value: "яблучко", baseRev: 0 });
  assert.equal(saved.status, 200);
  const added = await pagePost(`/s/${id}/rows`, { rowId: randomUUID(), field: "word", value: "plum" });
  assert.equal(added.status, 200);
  const deleted = await pagePost(`/s/${id}/rows/delete`, {
    rowId: pear.id,
    revs: { word: pear.word_rev, translation: pear.translation_rev, definition: pear.definition_rev },
  });
  assert.equal(deleted.status, 200);

  // A definition lightning fills an empty cell from the (stub) dictionary.
  const filled = await pagePost(`/s/${id}/define`, { rowId: kettle.id });
  assert.equal(filled.status, 200);
  assert.match(filled.body.value, /the meaning of kettle/);

  // Another open page sees all of it through the change feed.
  const feed = await (await get(`/s/${id}/changes?since=0`)).json();
  assert.ok(feed.rev >= 4, `feed revision ${feed.rev}`);
  assert.equal(feed.deleted.length, 1);

  // The AnkiDroid file holds the edits.
  const file = await get(`/s/${id}/words.txt`);
  assert.equal(file.status, 200);
  const text = await file.text();
  assert.match(text, /apple\tяблучко/);
  assert.match(text, /plum/);
  assert.doesNotMatch(text, /груша/);

  // The app republishes with its token: same link, and open pages are told to reload.
  const again = await publish({ publishedId: id, editToken, entries: [{ word: "cup", translation: "чашка" }] });
  assert.equal(again.id, id);
  assert.equal((await (await get(`/s/${id}/changes?since=${feed.rev}`)).json()).reload, true);
  assert.match(await (await get(`/s/${id}`)).text(), /cup/);
});

test("smoke: the app's dictionary lookup and subtitle import answer", async () => {
  const define = await appPost("/define", { word: "spoon" });
  assert.equal(define.status, 200);
  assert.equal(define.body.outcome, "senses");

  const subtitles = await appPost("/subtitles/words", {
    lines: ["I was reluctant to leave, but the tide was coming in."],
    purpose: "understand_film",
    level: "B2",
    maximum: 5,
    model: "claude-sonnet-5",
    sessionWords: [],
  });
  assert.equal(subtitles.status, 200);
  assert.equal(subtitles.body.words.length, 5);
});

test("smoke: an unknown link answers the gone page", async () => {
  const res = await get(`/s/${randomUUID()}`);
  assert.equal(res.status, 404);
  assert.match(await res.text(), /This word list is gone/);
});
