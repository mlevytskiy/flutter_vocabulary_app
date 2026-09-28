import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { d1, pagePost, publish, publishRaw, sql, storedRows } from "./helpers.mjs";

// sad §10 QG-2 / spec §6: each session content limit, at the limit and at
// limit + 1, on the publish route and on the page's add-row route. The page's
// cell save is covered in edit.test.mjs (501 characters, 256 KB + 1 byte), the
// 501st page row and the 301st write a minute in rows.test.mjs, the 51st and
// 501st definition lookups in autofill.test.mjs.

const addRow = (id, body) => pagePost(`/s/${id}/rows`, body);
const entries = (n) => Array.from({ length: n }, (_, i) => ({ word: `w${i}`, translation: `t${i}` }));
const errorOf = async (res) => (await res.json()).error;

test("a publish holds 500 rows; the 501st is refused", async () => {
  const { id } = await publish({ entries: entries(500) });
  assert.equal(storedRows(id).length, 500);

  const over = await publishRaw({ entries: entries(501) });
  assert.equal(over.status, 400);
  assert.match(await errorOf(over), /At most 500 entries/);
});

test("a published field holds 500 characters; 501 is refused, for a definition naming the word", async () => {
  const exactly = "x".repeat(500);
  const { id } = await publish({ detail: "both", entries: [{ word: exactly, translation: exactly, definition: exactly }] });
  const [row] = storedRows(id);
  assert.deepEqual([row.word.length, row.translation.length, row.definition.length], [500, 500, 500]);

  for (const field of ["word", "translation"]) {
    const over = await publishRaw({ entries: [{ word: "apple", translation: "яблуко", [field]: "x".repeat(501) }] });
    assert.equal(over.status, 400, field);
    assert.match(await errorOf(over), /at most 500 characters/);
  }
  const definition = await publishRaw({ entries: [{ word: "apple", translation: "яблуко", definition: "x".repeat(501) }] });
  assert.equal(definition.status, 400);
  assert.match(await errorOf(definition), /definition of "apple" is too long/);
});

test("a publish body over 256 KB is refused as too large", async () => {
  // 500 rows of 3 × 180 characters: well inside the row and field limits, ~290 KB of JSON.
  const big = Array.from({ length: 500 }, (_, i) => ({
    word: `${i}`.padEnd(180, "w"),
    translation: `${i}`.padEnd(180, "t"),
    definition: `${i}`.padEnd(180, "d"),
  }));
  assert.ok(JSON.stringify({ entries: big }).length > 256 * 1024);
  const over = await publishRaw({ detail: "both", entries: big });
  assert.equal(over.status, 413);
  assert.match(await errorOf(over), /too large/);
});

test("a publish declares 10 photos; the 11th is refused", async () => {
  const ten = Array.from({ length: 10 }, (_, order) => ({ id: randomUUID(), order }));
  const { id } = await publish({ sources: ten, entries: [{ word: "apple", translation: "яблуко", sourceId: ten[9].id }] });
  assert.equal(d1(`SELECT count(*) AS n FROM sources WHERE session_id = ${sql(id)}`)[0].n, 10);

  const eleven = await publishRaw({
    sources: [...ten, { id: randomUUID(), order: 10 }],
    entries: [{ word: "apple", translation: "яблуко" }],
  });
  assert.equal(eleven.status, 400);
  assert.match(await errorOf(eleven), /at most 10 sources/);
});

test("a page-added row holds 500 characters in its first cell; 501 is refused as field_too_long", async () => {
  const { id } = await publish();
  const fits = await addRow(id, { rowId: randomUUID(), field: "definition", value: "x".repeat(500) });
  assert.equal(fits.status, 200);

  const over = await addRow(id, { rowId: randomUUID(), field: "word", value: "x".repeat(501) });
  assert.equal(over.status, 422);
  assert.equal(over.body.code, "field_too_long");
  assert.equal(over.body.limit, 500);
  assert.equal(over.body.overflow, 1);
  assert.equal(storedRows(id).length, 2);
});

test("a page-added row that would take the list past 256 KB is refused as list_full", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  // "apple" + "яблуко" = 17 bytes; pad to exactly 256 KB - 10 bytes, three
  // 500-character cells a row so the pad stays under the 500-row limit.
  const padding = 256 * 1024 - 10 - 17;
  const full = Math.floor(padding / 1500);
  const rest = padding % 1500;
  const len = (cell) => `CASE WHEN i < ${full} THEN 500 ELSE ${Math.min(500, Math.max(0, rest - cell * 500))} END`;
  const text = (cell) => `substr(replace(hex(zeroblob(250)), '00', 'aa'), 1, ${len(cell)})`;
  d1(
    `WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < 999)
     INSERT INTO rows (session_id, id, position, word, translation, definition)
     SELECT ${sql(id)}, 'pad-' || i, 1 + i, ${text(0)}, ${text(1)}, ${text(2)} FROM n WHERE i <= ${full}`
  );

  const fits = await addRow(id, { rowId: randomUUID(), field: "word", value: "x".repeat(10) });
  assert.equal(fits.status, 200);

  const over = await addRow(id, { rowId: randomUUID(), field: "word", value: "y" });
  assert.equal(over.status, 422);
  assert.equal(over.body.code, "list_full");
  assert.equal(over.body.limit, 256 * 1024);
});

test("a page request over 16 KB is refused before it reaches the database", async () => {
  const { id } = await publish();
  const [row] = storedRows(id);
  const res = await pagePost(`/s/${id}/cells`, { rowId: row.id, field: "word", value: "x".repeat(17 * 1024), baseRev: 0 });
  assert.equal(res.status, 413);
  assert.equal(storedRows(id)[0].word, "apple");
});
