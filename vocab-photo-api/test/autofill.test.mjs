import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { appHeaders, baseUrl, d1, pagePost, publish, sql, storedRows } from "./helpers.mjs";

// The dictionary is the local stub from test/mw-stub.mjs: no real quota is used.
const defineRow = (id, rowId) => pagePost(`/s/${id}/define`, { rowId });
const today = () => new Date().toISOString().slice(0, 10);
const nextMidnight = () => {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1)).toISOString();
};
const pageUsed = (id) =>
  d1(`SELECT used FROM page_autofill WHERE session_id = ${sql(id)} AND utc_day = ${sql(today())}`)[0]?.used ?? 0;
const allPagesUsed = () => d1(`SELECT used FROM all_pages_autofill WHERE utc_day = ${sql(today())}`)[0]?.used ?? 0;
const dictionaryCalls = async () => (await fetch(`${process.env.VOCAB_API_MW_STUB_URL}__calls`)).json();

/** The app's own secret-gated lookup (definition-mode), never counted. */
async function appDefine(word) {
  const res = await fetch(`${baseUrl}/define`, {
    method: "POST",
    headers: appHeaders({ "content-type": "application/json" }),
    body: JSON.stringify({ word }),
  });
  return { status: res.status, body: await res.json() };
}

// AC-16, AC-19: only the empty cell is filled; a filled one stays and costs nothing.
test("a definition lightning fills only an empty cell and spends one unit", async () => {
  const { id } = await publish({
    detail: "both",
    entries: [
      { word: "kettle", translation: "чайник" },
      { word: "cup", translation: "чашка", definition: "a small bowl" },
      { word: "longing", translation: "туга" },
    ],
  });
  const [kettle, cup, longing] = storedRows(id);
  const allBefore = allPagesUsed();

  const filled = await defineRow(id, kettle.id);
  assert.equal(filled.status, 200);
  assert.deepEqual(filled.body, {
    rowId: kettle.id,
    field: "definition",
    value: "definition: the meaning of kettle\nexample: a kettle here",
    rev: 1,
  });
  const [storedKettle, storedCup] = storedRows(id);
  assert.equal(storedKettle.definition, filled.body.value);
  assert.equal(storedKettle.definition_rev, 1);
  assert.equal(storedKettle.translation, "чайник");
  assert.deepEqual([pageUsed(id), allPagesUsed()], [1, allBefore + 1]);

  const kept = await defineRow(id, cup.id);
  assert.equal(kept.status, 409);
  assert.equal(kept.body.code, "conflict");
  assert.equal(kept.body.value, "a small bowl");
  assert.equal(storedCup.definition, "a small bowl");
  assert.equal(pageUsed(id), 1);

  // A first sense too long for a cell is skipped for one that fits.
  const short = await defineRow(id, longing.id);
  assert.equal(short.body.value, "definition: the short meaning of longing");
});

test("a word looked up before comes from the cache but still spends the page's unit", async () => {
  const entries = [{ word: "saucer", translation: "блюдце" }];
  const [first, second] = [await publish({ entries }), await publish({ entries })];
  assert.equal((await defineRow(first.id, storedRows(first.id)[0].id)).status, 200);
  const calls = (await dictionaryCalls()).saucer;
  assert.equal(calls, 1);

  assert.equal((await defineRow(second.id, storedRows(second.id)[0].id)).status, 200);
  assert.equal((await dictionaryCalls()).saucer, calls);
  assert.equal(pageUsed(second.id), 1);
});

// AC-18: the page's allowance is 50 a UTC day, and racing lookups cannot pass it.
test("the 51st lookup on one page is paused until 00:00 UTC; translations still save", async () => {
  const { id } = await publish({
    detail: "definition",
    entries: Array.from({ length: 56 }, (_, i) => ({ word: `word${i}`, translation: `слово ${i}` })),
  });
  const rows = storedRows(id);
  const allBefore = allPagesUsed();

  const answers = await Promise.all(rows.slice(0, 55).map((row) => defineRow(id, row.id)));
  const statuses = answers.map((res) => res.status);
  assert.equal(statuses.filter((status) => status === 200).length, 50);
  assert.equal(statuses.filter((status) => status === 429).length, 5);
  assert.deepEqual([pageUsed(id), allPagesUsed()], [50, allBefore + 50]);

  const paused = await defineRow(id, rows[55].id);
  assert.equal(paused.status, 429);
  assert.equal(paused.body.code, "autofill_paused");
  assert.equal(paused.body.reason, "page");
  assert.equal(paused.body.resumesAt, nextMidnight());
  assert.match(paused.body.error, /type/);
  assert.equal(storedRows(id)[55].definition, "");

  const typed = await pagePost(`/s/${id}/cells`, { rowId: rows[55].id, field: "translation", value: "інше", baseRev: 0 });
  assert.equal(typed.status, 200);
});

// AC-18b, AC-29: the all-pages share runs out before the page's own allowance;
// the app's /define keeps working because pages stop at 500 of the 1,000.
test("with the all-pages share spent, a page with allowance left is paused and the app's /define still answers", async () => {
  const { id } = await publish({ entries: [{ word: "spoon", translation: "ложка" }] });
  const [spoon] = storedRows(id);
  const before = allPagesUsed();
  d1(`INSERT OR REPLACE INTO all_pages_autofill (utc_day, used) VALUES (${sql(today())}, 500)`);
  try {
    const paused = await defineRow(id, spoon.id);
    assert.equal(paused.status, 429);
    assert.equal(paused.body.code, "autofill_paused");
    assert.equal(paused.body.reason, "all_pages");
    assert.equal(paused.body.resumesAt, nextMidnight());
    assert.equal(pageUsed(id), 0);
    assert.equal(allPagesUsed(), 500);

    const app = await appDefine("spoon");
    assert.equal(app.status, 200);
    assert.equal(app.body.outcome, "senses");
    assert.equal(allPagesUsed(), 500);
  } finally {
    d1(`UPDATE all_pages_autofill SET used = ${before} WHERE utc_day = ${sql(today())}`);
  }
});

// AC-17, AC-20: every lookup counts, found or not.
test("a word the dictionary does not know spends one unit and leaves the cell empty", async () => {
  const { id } = await publish({
    entries: [
      { word: "zzmisspelt", translation: "помилка" },
      { word: "outage", translation: "збій" },
    ],
  });
  const [misspelt, outage] = storedRows(id);

  const nothing = await defineRow(id, misspelt.id);
  assert.equal(nothing.status, 422);
  assert.equal(nothing.body.code, "nothing_found");
  assert.equal(pageUsed(id), 1);
  assert.equal(storedRows(id)[0].definition, "");

  const down = await defineRow(id, outage.id);
  assert.equal(down.status, 503);
  assert.equal(down.body.code, "dictionary_unavailable");
  assert.equal(storedRows(id)[1].definition, "");
});

test("define refuses rows it cannot fill without spending a unit", async () => {
  const { id } = await publish({
    entries: [
      { word: "", translation: "лише переклад" },
      { word: "pear", translation: "груша" },
    ],
  });
  const [noWord, pear] = storedRows(id);
  assert.equal((await defineRow(id, noWord.id)).status, 400);
  assert.equal((await defineRow(id, randomUUID())).status, 404);
  assert.equal((await pagePost(`/s/${id}/define`, {})).status, 400);

  await pagePost(`/s/${id}/rows/delete`, { rowId: pear.id, revs: { word: 0, translation: 0, definition: 0 } });
  const deleted = await defineRow(id, pear.id);
  assert.equal(deleted.status, 409);
  assert.equal(deleted.body.deleted, true);
  assert.equal(pageUsed(id), 0);

  const gone = await pagePost(`/s/${randomUUID()}/define`, { rowId: pear.id });
  assert.equal(gone.status, 404);
  assert.equal(gone.body.code, "gone");
});
