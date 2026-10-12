import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { baseUrl, d1, get, pagePost, publish, sql, storedRows } from "./helpers.mjs";

const addRow = (id, body, ip) => pagePost(`/s/${id}/rows`, body, ip);
const deleteRow = (id, body, ip) => pagePost(`/s/${id}/rows/delete`, body, ip);
const save = (id, body, ip) => pagePost(`/s/${id}/cells`, body, ip);
const sleep = (ms) => new Promise((ok) => setTimeout(ok, Math.max(0, ms)));
const revsOf = (row) => ({ word: row.word_rev, translation: row.translation_rev, definition: row.definition_rev });

// AC-13: the plus button's row exists once a cell holds text; before that it is only on the page.
test("an added row persists once it has text; a row never given text does not exist", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const rowId = randomUUID();

  const empty = await addRow(id, { rowId, field: "word", value: "" });
  assert.equal(empty.status, 400);
  assert.equal(storedRows(id).length, 1);

  const added = await addRow(id, { rowId, field: "word", value: "kettle" });
  assert.equal(added.status, 200);
  assert.deepEqual(added.body, { rowId, rev: 1 });

  // A retried add that already landed answers the same and adds nothing.
  assert.deepEqual((await addRow(id, { rowId, field: "word", value: "kettle" })).body, added.body);

  const saved = await save(id, { rowId, field: "translation", value: "чайник", baseRev: added.body.rev });
  assert.equal(saved.status, 200);

  const rows = storedRows(id);
  assert.equal(rows.length, 2);
  assert.deepEqual(
    { id: rows[1].id, position: rows[1].position, word: rows[1].word, translation: rows[1].translation },
    { id: rowId, position: 1, word: "kettle", translation: "чайник" }
  );
  assert.equal(rows[1].source_id, null);
  assert.deepEqual(revsOf(rows[1]), { word: 1, translation: 2, definition: 1 });
  assert.match(await (await get(`/s/${id}`)).text(), /apple[\s\S]*kettle[\s\S]*чайник/);

  // Another row cannot take a used id.
  const taken = await addRow(id, { rowId, field: "word", value: "other" });
  assert.equal(taken.status, 409);
  assert.equal(taken.body.code, "conflict");
  assert.equal(taken.body.word, "kettle");
});

// AC-14: the 501st live row is refused and the answer names the limit; tombstones do not count.
test("the 501st row is refused with the limit named", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  d1(
    `WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 498)
     INSERT INTO rows (session_id, id, position, word) SELECT ${sql(id)}, 'seed-' || i, i, 'w' || i FROM n`
  );

  const last = await addRow(id, { rowId: randomUUID(), field: "word", value: "five hundredth" });
  assert.equal(last.status, 200);

  const over = await addRow(id, { rowId: randomUUID(), field: "translation", value: "зайвий" });
  assert.equal(over.status, 422);
  assert.equal(over.body.code, "rows_full");
  assert.equal(over.body.limit, 500);
  assert.match(over.body.error, /500 rows/);
  assert.equal(d1(`SELECT count(*) AS n FROM rows WHERE session_id = ${sql(id)}`)[0].n, 500);

  const seed = storedRows(id).find((row) => row.id === "seed-1");
  assert.equal((await deleteRow(id, { rowId: seed.id, revs: revsOf(seed) })).status, 200);
  assert.equal((await addRow(id, { rowId: randomUUID(), field: "word", value: "fits again" })).status, 200);
});

// AC-15, AC-15b: the delete sent after Undo applies only to a row nobody changed meanwhile.
test("a delete after a concurrent save is refused; an untouched delete applies", async () => {
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
    ],
  });
  const [apple, pear] = storedRows(id);

  // Partner B saves apple while partner A's Undo is running.
  const changed = await save(id, { rowId: apple.id, field: "translation", value: "яблучко", baseRev: 0 });
  assert.equal(changed.status, 200);
  const refused = await deleteRow(id, { rowId: apple.id, revs: revsOf(apple) });
  assert.equal(refused.status, 409);
  assert.equal(refused.body.code, "conflict");
  assert.equal(refused.body.translation, "яблучко");
  assert.deepEqual(refused.body.revs, { word: 0, translation: changed.body.rev, definition: 0 });
  assert.equal(storedRows(id)[0].deleted_at_rev, null);

  const applied = await deleteRow(id, { rowId: pear.id, revs: revsOf(pear) });
  assert.equal(applied.status, 200);
  assert.equal(applied.body.rev, changed.body.rev + 1);
  const [storedApple, storedPear] = storedRows(id);
  assert.equal(storedPear.deleted_at_rev, applied.body.rev);
  assert.equal(storedApple.deleted_at_rev, null);

  const page = await (await get(`/s/${id}`)).text();
  assert.match(page, /яблучко/);
  assert.doesNotMatch(page, /груша/);

  // A repeated delete answers the same; an unknown row is refused.
  assert.deepEqual((await deleteRow(id, { rowId: pear.id, revs: revsOf(pear) })).body, applied.body);
  assert.equal((await deleteRow(id, { rowId: randomUUID(), revs: revsOf(pear) })).status, 404);
  assert.equal((await deleteRow(id, { rowId: apple.id, revs: { word: 0 } })).status, 400);
});

test("the page write limit refuses the 301st write in a minute from one address, never a read", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const [row] = storedRows(id);
  const ip = `192.168.1.${Math.floor(Math.random() * 250)}`;
  // Local windows are aligned to the wall-clock minute: start with 20 s of it left.
  if (Date.now() % 60_000 > 40_000) await sleep(60_000 - (Date.now() % 60_000) + 100);

  const statuses = [];
  for (let i = 0; i < 300; i += 20) {
    const batch = Array.from({ length: 20 }, (_, k) =>
      save(id, { rowId: row.id, field: "word", value: `apple ${i + k}`, baseRev: 0 }, ip)
    );
    statuses.push(...(await Promise.all(batch)).map((res) => res.status));
  }
  assert.equal(statuses.filter((status) => status === 429).length, 0);

  const limited = await save(id, { rowId: row.id, field: "word", value: "one too many", baseRev: 0 }, ip);
  assert.equal(limited.status, 429);
  assert.equal(limited.body.code, "rate_limited");
  const read = await fetch(`${baseUrl}/s/${id}`, { headers: { "cf-connecting-ip": ip } });
  assert.equal(read.status, 200);
  // Another address has its own budget.
  assert.notEqual((await save(id, { rowId: row.id, field: "word", value: "x", baseRev: 0 })).status, 429);
});

/**
 * AC-35: two partners on one network (one IP). Partner A runs a column
 * autofill -- one translation save per cell, paced at 3 a second -- then keeps
 * editing at a normal pace; partner B saves a word every 3 seconds throughout.
 * Returns every status the Worker answered.
 */
async function twoPartnerSession({ durationMs, autofillCells }) {
  const { id } = await publish({
    entries: Array.from({ length: 500 }, (_, i) => ({ word: `word${i}`, translation: "" })),
  });
  const rows = storedRows(id);
  const ip = `192.168.2.${Math.floor(Math.random() * 250)}`;
  const statuses = [];
  const started = Date.now();
  const end = started + durationMs;

  const partnerA = async () => {
    for (let i = 0; i < autofillCells && Date.now() < end; i++) {
      await sleep(started + i * 334 - Date.now());
      const res = await save(id, { rowId: rows[i].id, field: "translation", value: `переклад ${i}`, baseRev: 0 }, ip);
      statuses.push(res.status);
    }
    for (let k = 0; Date.now() < end; k++) {
      await sleep(3000);
      const row = rows[(k * 7) % rows.length];
      const res = await save(id, { rowId: row.id, field: "definition", value: `note ${k}`, baseRev: row.definition_rev }, ip);
      if (res.status === 200) row.definition_rev = res.body.rev;
      statuses.push(res.status);
    }
  };
  const partnerB = async () => {
    for (let k = 0; Date.now() < end; k++) {
      await sleep(3000);
      const row = rows[(k * 13 + 250) % rows.length];
      const res = await save(id, { rowId: row.id, field: "word", value: `${row.word}!`, baseRev: row.word_rev }, ip);
      if (res.status === 200) row.word_rev = res.body.rev;
      statuses.push(res.status);
    }
  };
  await Promise.all([partnerA(), partnerB()]);
  return statuses;
}

// The two paced sessions below are soak tests: they spend real minutes at a
// real pace. The page write limit counts writes per address in a wall-clock
// minute, and the test above already shows 300 writes in one minute all land,
// which covers the ~220 these send in their busiest minute. So the full
// regression skips them; `npm run test:long` runs both (docs/testing.md).
const soak = { skip: !process.env.VOCAB_API_LONG_TESTS && "set VOCAB_API_LONG_TESTS=1 (npm run test:long)" };

test("two partners on one network, with a column autofill at 3 saves a second, are never refused (short)", soak, async () => {
  // The busiest stretch of the 15-minute session: a full minute of autofill beside the other partner.
  const statuses = await twoPartnerSession({ durationMs: 65_000, autofillCells: 500 });
  assert.ok(statuses.length > 200, `only ${statuses.length} writes were sent`);
  assert.deepEqual([...new Set(statuses)], [200]);
});

test(
  "a 15-minute two-partner session with a 500-cell column autofill sees no 429 (AC-35)",
  { ...soak, timeout: 17 * 60_000 },
  async () => {
    const statuses = await twoPartnerSession({ durationMs: 15 * 60_000, autofillCells: 500 });
    assert.ok(statuses.length > 900, `only ${statuses.length} writes were sent`);
    assert.equal(statuses.filter((status) => status === 429).length, 0);
    assert.deepEqual([...new Set(statuses)], [200]);
  }
);
