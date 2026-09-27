import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { d1, get, pagePost, publish, sql, storedRows, uploadSource } from "./helpers.mjs";

const HEADER = "#separator:tab\n#html:true\n#tags column:4\n";

async function download(id) {
  const res = await get(`/s/${id}/words.txt`);
  assert.equal(res.status, 200);
  return res.text();
}

function saveCell(id, rowId, field, value, baseRev) {
  return pagePost(`/s/${id}/cells`, { rowId, field, value, baseRev });
}

// AC-30: the file holds what the page saved, in the fixed places.
test("the file holds the edited values in their fixed places", async () => {
  const { id } = await publish({
    detail: "both",
    entries: [
      { word: "apple", translation: "яблуко", definition: "a round fruit" },
      { word: "pear", translation: "груша" },
    ],
  });
  const [apple, pear] = storedRows(id);
  assert.equal((await saveCell(id, apple.id, "translation", "яблучко", apple.translation_rev)).status, 200);
  assert.equal((await saveCell(id, pear.id, "word", "<b>pear</b> & co", pear.word_rev)).status, 200);
  const added = randomUUID();
  assert.equal((await pagePost(`/s/${id}/rows`, { rowId: added, field: "word", value: "plum" })).status, 200);

  assert.equal(
    await download(id),
    HEADER +
      "apple\tяблучко\ta round fruit\t\n" +
      // AC-33: the file keeps anki.ts's sanitising.
      "&lt;b&gt;pear&lt;/b&gt; &amp; co\tгруша\t\t\n" +
      "plum\t\t\t\n"
  );
});

// AC-31: a card needs a word.
test("a row with an empty word and a row with every cell cleared are left out", async () => {
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
      { word: "plum", translation: "слива", definition: "a small fruit" },
    ],
  });
  const [, pear, plum] = storedRows(id);
  assert.equal((await saveCell(id, pear.id, "word", "", pear.word_rev)).status, 200);
  for (const field of ["word", "translation", "definition"]) {
    const current = storedRows(id).find((row) => row.id === plum.id);
    assert.equal((await saveCell(id, plum.id, field, "", current[`${field}_rev`])).status, 200);
  }
  // Both rows are still on the page's list; only the file leaves them out.
  assert.equal(d1(`SELECT count(*) AS n FROM rows WHERE session_id = ${sql(id)} AND deleted_at_rev IS NULL`)[0].n, 3);

  assert.equal(await download(id), HEADER + "apple\tяблуко\t\t\n");
});

// AC-30 + AC-27: the columns follow the data, not the published mode.
test("a translation-mode session's stored definitions are in the file; an all-empty column is written empty", async () => {
  const withDefinitions = await publish({
    detail: "translation",
    entries: [{ word: "apple", translation: "яблуко", definition: "a round fruit" }],
  });
  assert.equal(await download(withDefinitions.id), HEADER + "apple\tяблуко\ta round fruit\t\n");

  const definitionOnly = await publish({
    detail: "definition",
    entries: [{ word: "apple", translation: "", definition: "a round fruit" }],
  });
  assert.equal(await download(definitionOnly.id), HEADER + "apple\t\ta round fruit\t\n");
});

// sad §7: the daily cron deletes an expired session with everything it owns.
test("the scheduled clean-up removes an expired session, its rows, slots and counters; its page stays gone", async () => {
  const photo = randomUUID();
  const expired = await publish({
    sources: [{ id: photo, order: 0 }],
    entries: [{ word: "apple", translation: "яблуко", sourceId: photo }],
  });
  await uploadSource(expired.id, photo, Buffer.from("photo bytes"));
  const [row] = storedRows(expired.id);
  const define = await pagePost(`/s/${expired.id}/define`, { rowId: row.id });
  assert.ok([200, 422].includes(define.status), `define answered ${define.status}`);
  const live = await publish({ entries: [{ word: "pear", translation: "груша" }] });
  const counts = (id) =>
    d1(
      `SELECT (SELECT count(*) FROM sessions WHERE id = ${sql(id)}) AS sessions,
              (SELECT count(*) FROM rows WHERE session_id = ${sql(id)}) AS rows,
              (SELECT count(*) FROM sources WHERE session_id = ${sql(id)}) AS sources,
              (SELECT count(*) FROM page_autofill WHERE session_id = ${sql(id)}) AS counters`
    )[0];
  assert.deepEqual(counts(expired.id), { sessions: 1, rows: 1, sources: 1, counters: 1 });
  const allPagesBefore = d1(`SELECT sum(used) AS used FROM all_pages_autofill`)[0].used;

  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(expired.id)}`);
  const run = await get(`/__scheduled?cron=${encodeURIComponent("0 3 * * *")}`);
  assert.equal(run.status, 200);

  assert.deepEqual(counts(expired.id), { sessions: 0, rows: 0, sources: 0, counters: 0 });
  assert.deepEqual(counts(live.id), { sessions: 1, rows: 1, sources: 0, counters: 0 });
  // The all-pages share is not a session's and survives the clean-up.
  assert.equal(d1(`SELECT sum(used) AS used FROM all_pages_autofill`)[0].used, allPagesBefore);

  const page = await get(`/s/${expired.id}`);
  assert.equal(page.status, 404);
  assert.match(await page.text(), /This word list is gone/);
  assert.equal((await get(`/s/${expired.id}/words.txt`)).status, 404);
  assert.equal((await get(`/s/${expired.id}/sources/${photo}`)).status, 404);
  assert.equal((await get(`/s/${live.id}`)).status, 200);
});
