import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { appHeaders, baseUrl, get, pagePost, publish, storedRows } from "./helpers.mjs";

// AC-20: the shared page renders one dialogue page per dialogue after the word table, in the
// phone's order, with the bold places, the word list and the scene picture once it has arrived.
// AC-22: no control on the page edits a dialogue or draws a picture. The markup is the shape the
// change feed carries (T8), so the page script (T10) can re-render a dialogue from feed data.

const png = Buffer.from("89504e470d0a1a0a-scene", "utf8");

async function html(id) {
  const res = await get(`/s/${id}`);
  assert.equal(res.status, 200);
  return res.text();
}

/** The dialogue sections of the page, each as { id, position, lines, words, picture }. */
function dialogues(page) {
  return [...page.matchAll(/<section class="dialogue-page" data-dialogue="([^"]+)" data-position="(\d+)">(.*?)<\/section>/gs)].map(
    (m) => ({
      id: m[1],
      position: Number(m[2]),
      lines: [...m[3].matchAll(/<p class="dialogue-line">(.*?)<\/p>/gs)].map((l) => l[1]),
      words: [...m[3].matchAll(/<li data-row="([^"]+)"><span class="dw-word">(.*?)<\/span>(?: <span class="dw-translation">(.*?)<\/span>)?(?: <span class="dw-definition">(.*?)<\/span>)?<\/li>/gs)].map(
        (w) => ({ rowId: w[1], word: w[2], translation: w[3], definition: w[4] })
      ),
      picture: m[3].match(/<img class="dialogue-picture" src="([^"]+)"/)?.[1] ?? null,
      body: m[3],
    })
  );
}

const A = ["A: Grab the rope!", "B: I can't lift it, the tide is coming. Grab it!"];
const B = ["A: <b>Look</b> at the tide & the fog."];

async function session(extra = {}) {
  const idA = randomUUID();
  const idB = randomUUID();
  const published = await publish({
    entries: [
      { word: "grab", translation: "хапати", definition: "to seize" },
      { word: "rope", translation: "мотузка" },
      { word: "tide", translation: "приплив" },
      { word: "fog", translation: "туман" },
      { word: "apple", translation: "яблуко" },
    ],
    dialogues: [
      { id: idA, lines: A, entries: [0, 1, 2] },
      { id: idB, lines: B, entries: [2, 3] },
    ],
    ...extra,
  });
  const byWord = Object.fromEntries(storedRows(published.id).map((r) => [r.word, r.id]));
  return { ...published, idA, idB, byWord };
}

test("two dialogues render after the table in order, with their words listed", async () => {
  const s = await session();
  const page = await html(s.id);
  const found = dialogues(page);
  assert.deepEqual(found.map((d) => d.id), [s.idA, s.idB]);
  assert.deepEqual(found.map((d) => d.position), [0, 1]);
  assert.ok(page.indexOf("</table>") < page.indexOf('class="dialogue-page"'));
  assert.deepEqual(found[0].words.map((w) => [w.rowId, w.word, w.translation, w.definition]), [
    [s.byWord.grab, "grab", "хапати", "to seize"],
    [s.byWord.rope, "rope", "мотузка", undefined],
    [s.byWord.tide, "tide", "приплив", undefined],
  ]);
  assert.deepEqual(found[1].words.map((w) => w.word), ["tide", "fog"]);
});

test("every place of every word is bold, line by line, and text is escaped", async () => {
  const s = await session();
  const [a, b] = dialogues(await html(s.id));
  assert.deepEqual(a.lines, [
    "A: <strong>Grab</strong> the <strong>rope</strong>!",
    "B: I can&#39;t lift it, the <strong>tide</strong> is coming. <strong>Grab</strong> it!",
  ]);
  assert.deepEqual(b.lines, ["A: &lt;b&gt;Look&lt;/b&gt; at the <strong>tide</strong> &amp; the <strong>fog</strong>."]);
});

test("a picture is shown only once it has arrived, with the feed's cache-busting revision", async () => {
  const s = await session();
  assert.equal(dialogues(await html(s.id))[0].picture, null);
  assert.doesNotMatch(await html(s.id), /<img class="dialogue-picture"/);

  const up = await fetch(`${baseUrl}/sessions/${s.id}/dialogues/${s.idA}/picture`, {
    method: "POST",
    headers: appHeaders({ "content-type": "image/png", "x-edit-token": s.editToken }),
    body: png,
  });
  assert.equal(up.status, 200);
  const [a, b] = dialogues(await html(s.id));
  assert.match(a.picture, new RegExp(`^/s/${s.id}/dialogues/${s.idA}/picture\\?v=\\d+$`));
  assert.equal(b.picture, null);
});

test("a deleted word leaves the dialogue's list and bold; one with no word left is not rendered", async () => {
  const s = await session();
  const del = (rowId) => pagePost(`/s/${s.id}/rows/delete`, { rowId, revs: { word: 0, translation: 0, definition: 0 } });
  assert.equal((await del(s.byWord.rope)).status, 200);
  let [a] = dialogues(await html(s.id));
  assert.deepEqual(a.words.map((w) => w.word), ["grab", "tide"]);
  assert.match(a.lines[0], /^A: <strong>Grab<\/strong> the rope!$/);

  await del(s.byWord.tide);
  await del(s.byWord.fog);
  const left = dialogues(await html(s.id));
  assert.deepEqual(left.map((d) => d.id), [s.idA]);
});

test("a dialogue page has no control that edits the dialogue or draws a picture (AC-22)", async () => {
  const s = await session();
  for (const d of dialogues(await html(s.id))) {
    assert.doesNotMatch(d.body, /<(button|input|textarea|form|select|a )|contenteditable|data-field/i);
  }
});

/** The page with what differs per run (ids, dates, the style block, the script path) replaced. */
function normalised(page, session) {
  return page
    .replaceAll(session.id, "SESSION")
    .replace(/data-row="[^"]+"/g, 'data-row="ROW"')
    .replace(/<style>.*?<\/style>/s, "<style>STYLE</style>")
    .replace(/src="\/assets\/page-[0-9a-f]{12}\.js"/, 'src="/assets/page.js"')
    .replace(/published [^<·]*· available until [^<]*|until \d\d\.\d\d\.\d{4}/g, "DATES");
}

test("a session without dialogues renders exactly as before (snapshot taken before this task)", async () => {
  const s = await publish({
    detail: "both",
    entries: [{ word: "apple", translation: "яблуко", definition: "a fruit" }],
  });
  const page = normalised(await html(s.id), s);
  assert.doesNotMatch(page.replace(/<style>STYLE<\/style>/, ""), /dialogue|has-dialogues/);
  const expected = readFileSync(new URL("./fixtures/page-no-dialogues.html", import.meta.url), "utf8");
  assert.equal(page, expected);

  // Published with an empty list: the same page.
  const t = await publish({ detail: "both", entries: [{ word: "apple", translation: "яблуко", definition: "a fruit" }], dialogues: [] });
  assert.equal(normalised(await html(t.id), t), expected);
});
