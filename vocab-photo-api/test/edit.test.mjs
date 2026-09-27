import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { d1, get, pagePost, publish, sql, storedRows } from "./helpers.mjs";

const save = (id, cell) => pagePost(`/s/${id}/cells`, cell);

async function publishOne(entry = { word: "apple", translation: "яблуко" }) {
  const { id } = await publish({ entries: [entry] });
  const [row] = storedRows(id);
  return { id, row };
}

// AC-09, AC-11: the first save from a base revision lands; the second gets the first's value.
test("two saves from the same base revision: the first lands, the second is a conflict with the first value", async () => {
  const { id, row } = await publishOne();

  const first = await save(id, { rowId: row.id, field: "translation", value: "яблучко", baseRev: row.translation_rev });
  assert.equal(first.status, 200);
  assert.deepEqual(first.body, { rowId: row.id, field: "translation", rev: 1 });

  const second = await save(id, { rowId: row.id, field: "translation", value: "яблуня", baseRev: row.translation_rev });
  assert.equal(second.status, 409);
  assert.equal(second.body.code, "conflict");
  assert.equal(second.body.field, "translation");
  assert.equal(second.body.value, "яблучко");
  assert.equal(second.body.rev, 1);
  assert.equal(typeof second.body.error, "string");

  // Choosing "keep mine" is a save from the revision the conflict named.
  const resolved = await save(id, { rowId: row.id, field: "translation", value: "яблуня", baseRev: 1 });
  assert.equal(resolved.status, 200);
  assert.equal(resolved.body.rev, 2);

  const [stored] = storedRows(id);
  assert.equal(stored.translation, "яблуня");
  assert.equal(stored.translation_rev, 2);
  assert.equal(d1(`SELECT rev FROM sessions WHERE id = ${sql(id)}`)[0].rev, 2);
  assert.match(await (await get(`/s/${id}`)).text(), /яблуня/);
});

// AC-12 precondition: different cells never conflict, even in one row.
test("saves to different cells of the same row from the same revision both land", async () => {
  const { id, row } = await publishOne();

  const word = await save(id, { rowId: row.id, field: "word", value: "apples", baseRev: row.word_rev });
  const definition = await save(id, { rowId: row.id, field: "definition", value: "a fruit", baseRev: row.definition_rev });
  assert.equal(word.status, 200);
  assert.equal(definition.status, 200);
  assert.equal(word.body.rev, 1);
  assert.equal(definition.body.rev, 2);

  const [stored] = storedRows(id);
  assert.equal(stored.word, "apples");
  assert.equal(stored.word_rev, 1);
  assert.equal(stored.definition, "a fruit");
  assert.equal(stored.definition_rev, 2);
  assert.equal(stored.translation_rev, 0);
});

// AC-10: nothing is written, and the answer names the field and the overflow.
test("a value of 501 characters is refused as field_too_long with the overflow", async () => {
  const { id, row } = await publishOne();

  const res = await save(id, { rowId: row.id, field: "definition", value: "x".repeat(501), baseRev: 0 });
  assert.equal(res.status, 422);
  assert.equal(res.body.code, "field_too_long");
  assert.equal(res.body.field, "definition");
  assert.equal(res.body.overflow, 1);
  assert.equal(res.body.limit, 500);
  assert.match(res.body.error, /definition is 1 character too long/);

  const exactly = await save(id, { rowId: row.id, field: "definition", value: "x".repeat(500), baseRev: 0 });
  assert.equal(exactly.status, 200);
  assert.equal(storedRows(id)[0].definition.length, 500);
});

// AC-38: 256 KB of UTF-8 cell text per session; a shrinking edit always lands.
test("a save that would take the list past 256 KB is refused as list_full", async () => {
  const { id, row } = await publishOne({ word: "apple", translation: "яблуко" });
  // "apple" is 5 bytes, "яблуко" 12: pad the list to exactly 256 KB - 1 byte.
  const padding = 256 * 1024 - 1 - 5 - 12;
  d1(
    `WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < 999)
     INSERT INTO rows (session_id, id, position, word)
     SELECT ${sql(id)}, 'pad-' || i, 1 + i, substr(replace(hex(zeroblob(250)), '00', 'aa'), 1,
       CASE WHEN i < ${Math.floor(padding / 500)} THEN 500 WHEN i = ${Math.floor(padding / 500)} THEN ${padding % 500} ELSE 0 END)
     FROM n WHERE i <= ${Math.floor(padding / 500)}`
  );

  // One more byte fits exactly.
  const fits = await save(id, { rowId: row.id, field: "word", value: "apples", baseRev: 0 });
  assert.equal(fits.status, 200);

  const over = await save(id, { rowId: row.id, field: "word", value: "applesa", baseRev: fits.body.rev });
  assert.equal(over.status, 422);
  assert.equal(over.body.code, "list_full");
  assert.equal(over.body.limit, 256 * 1024);
  assert.equal(storedRows(id)[0].word, "apples");

  const shorter = await save(id, { rowId: row.id, field: "translation", value: "я", baseRev: 0 });
  assert.equal(shorter.status, 200);
});

// AC-33, AC-34: text is stored exactly as typed; the photo link never moves.
test("a save stores markup as given and keeps the row's photo link", async () => {
  const photo = randomUUID();
  const { id } = await publish({
    sources: [{ id: photo, order: 0 }],
    entries: [{ word: "apple", translation: "яблуко", sourceId: photo }],
  });
  const [row] = storedRows(id);

  const script = `<script>alert("x")</script> & <b>bold</b>`;
  assert.equal((await save(id, { rowId: row.id, field: "word", value: script, baseRev: 0 })).status, 200);

  const [stored] = storedRows(id);
  assert.equal(stored.word, script);
  assert.equal(stored.source_id, photo);
  const page = await (await get(`/s/${id}`)).text();
  assert.doesNotMatch(page, /<script>alert/);
});

test("a save to a deleted row is a conflict; a save to an unknown row is refused", async () => {
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
    ],
  });
  const [apple] = storedRows(id);
  d1(
    `UPDATE sessions SET rev = rev + 1 WHERE id = ${sql(id)};
     UPDATE rows SET deleted_at_rev = 1 WHERE session_id = ${sql(id)} AND id = ${sql(apple.id)}`
  );

  const deleted = await save(id, { rowId: apple.id, field: "translation", value: "яблучко", baseRev: 0 });
  assert.equal(deleted.status, 409);
  assert.equal(deleted.body.code, "conflict");
  assert.equal(deleted.body.deleted, true);

  const unknown = await save(id, { rowId: randomUUID(), field: "translation", value: "x", baseRev: 0 });
  assert.equal(unknown.status, 404);
  assert.equal(unknown.body.code, "unknown_row");

  assert.equal(d1(`SELECT rev FROM sessions WHERE id = ${sql(id)}`)[0].rev, 1);
});

test("a save to an unknown or expired session answers gone; a malformed save is a bad request", async () => {
  const { id, row } = await publishOne();

  const unknown = await save(randomUUID(), { rowId: row.id, field: "word", value: "x", baseRev: 0 });
  assert.equal(unknown.status, 404);
  assert.equal(unknown.body.code, "gone");

  for (const cell of [
    { rowId: row.id, field: "source_id", value: "x", baseRev: 0 },
    { rowId: row.id, field: "word", value: 5, baseRev: 0 },
    { rowId: row.id, field: "word", value: "x", baseRev: -1 },
    { rowId: "not an id", field: "word", value: "x", baseRev: 0 },
  ]) {
    const res = await save(id, cell);
    assert.equal(res.status, 400, JSON.stringify(cell));
    assert.equal(res.body.code, "bad_request");
  }

  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(id)}`);
  const expired = await save(id, { rowId: row.id, field: "word", value: "x", baseRev: 0 });
  assert.equal(expired.status, 404);
  assert.deepEqual(expired.body, unknown.body);
  assert.equal(storedRows(id)[0].word, "apple");
});
