import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { d1, publish, publishRaw, sql, storedRows } from "./helpers.mjs";

// AC-20 (publish and republish carry dialogues), AC-22 (app secret on the write; the page only reads).

const entries = [
  { word: "apple", translation: "яблуко" },
  { word: "pear", translation: "груша" },
  { word: "plum", translation: "слива" },
];

function dialogueRows(id) {
  return d1(
    `SELECT id, position, lines_json, picture_media_type, picture_arrived_rev, added_rev
     FROM dialogues WHERE session_id = ${sql(id)} ORDER BY position`
  );
}

function wordsOf(id, dialogueId) {
  return d1(
    `SELECT r.word FROM dialogue_words dw JOIN rows r ON r.session_id = dw.session_id AND r.id = dw.row_id
     WHERE dw.session_id = ${sql(id)} AND dw.dialogue_id = ${sql(dialogueId)} ORDER BY r.position`
  ).map((r) => r.word);
}

test("a publish with two dialogues stores them linked to the right rows", async () => {
  const [d1id, d2id] = [randomUUID(), randomUUID()];
  const { id } = await publish({
    entries,
    dialogues: [
      { id: d1id, lines: ["Eat an apple.", "A pear too?"], entries: [0, 1] },
      { id: d2id, lines: ["One plum."], entries: [2], picture: { mediaType: "image/png" } },
    ],
  });

  const rows = dialogueRows(id);
  assert.equal(rows.length, 2);
  assert.deepEqual(rows[0], {
    id: d1id,
    position: 0,
    lines_json: JSON.stringify(["Eat an apple.", "A pear too?"]),
    picture_media_type: null,
    picture_arrived_rev: null,
    added_rev: 0,
  });
  assert.equal(rows[1].id, d2id);
  assert.equal(rows[1].position, 1);
  // Declared, not arrived: the bytes come later.
  assert.equal(rows[1].picture_media_type, "image/png");
  assert.equal(rows[1].picture_arrived_rev, null);
  assert.deepEqual(wordsOf(id, d1id), ["apple", "pear"]);
  assert.deepEqual(wordsOf(id, d2id), ["plum"]);
});

test("entries are positions in the sent list, even when a blank row is dropped before them", async () => {
  const dId = randomUUID();
  const { id } = await publish({
    entries: [{ word: "", translation: "" }, ...entries],
    dialogues: [{ id: dId, lines: ["Pear."], entries: [2] }],
  });
  assert.deepEqual(wordsOf(id, dId), ["pear"]);
  // A dialogue about the dropped blank row is refused.
  const res = await publishRaw({
    entries: [{ word: "", translation: "" }, ...entries],
    dialogues: [{ id: randomUUID(), lines: ["x"], entries: [0] }],
  });
  assert.equal(res.status, 400);
});

test("a republish replaces the dialogues together with the rows under the same link", async () => {
  const first = await publish({
    entries,
    dialogues: [{ id: randomUUID(), lines: ["Old."], entries: [0] }],
  });
  const newId = randomUUID();
  const again = await publish({
    entries: entries.slice(1),
    publishedId: first.id,
    editToken: first.editToken,
    dialogues: [{ id: newId, lines: ["New one.", "Second."], entries: [0, 1] }],
  });
  assert.equal(again.id, first.id);
  const rows = dialogueRows(first.id);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].id, newId);
  assert.equal(rows[0].added_rev, 1);
  assert.deepEqual(wordsOf(first.id, newId), ["pear", "plum"]);
  assert.equal(
    d1(`SELECT COUNT(*) AS n FROM dialogue_words WHERE session_id = ${sql(first.id)}`)[0].n,
    2
  );

  // A republish without dialogues clears them, like it clears the rows.
  await publish({ entries, publishedId: first.id, editToken: first.editToken });
  assert.equal(dialogueRows(first.id).length, 0);
  assert.equal(
    d1(`SELECT COUNT(*) AS n FROM dialogue_words WHERE session_id = ${sql(first.id)}`)[0].n,
    0
  );
});

test("a publish without dialogues is unchanged", async () => {
  const published = await publish({ entries });
  assert.equal(dialogueRows(published.id).length, 0);
  assert.equal(storedRows(published.id).length, 3);
  assert.deepEqual(Object.keys(published).sort(), ["editToken", "expiresAt", "id", "url"]);
  const empty = await publish({ entries, dialogues: [] });
  assert.equal(dialogueRows(empty.id).length, 0);
});

test("bad dialogues are refused with 400 and nothing is stored", async () => {
  const good = { id: randomUUID(), lines: ["Hi."], entries: [0] };
  const bad = [
    ["entry out of range", { ...good, entries: [3] }],
    ["negative entry", { ...good, entries: [-1] }],
    ["fractional entry", { ...good, entries: [0.5] }],
    ["no entries", { ...good, entries: [] }],
    ["no lines", { ...good, lines: [] }],
    ["nine lines", { ...good, lines: Array(9).fill("x") }],
    ["blank line", { ...good, lines: ["ok", "  "] }],
    ["long line", { ...good, lines: ["x".repeat(201)] }],
    ["non-string line", { ...good, lines: [5] }],
    ["bad id", { ...good, id: "not a valid id!" }],
    ["picture type", { ...good, picture: { mediaType: "image/gif" } }],
  ];
  for (const [name, dialogue] of bad) {
    const res = await publishRaw({ entries, dialogues: [dialogue] });
    assert.equal(res.status, 400, name);
    assert.ok(typeof (await res.json()).error === "string", name);
  }
  assert.equal((await publishRaw({ entries, dialogues: "nope" })).status, 400);
  assert.equal((await publishRaw({ entries, dialogues: [good, { ...good }] })).status, 400, "duplicate id");

  const eleven = Array.from({ length: 11 }, () => ({ id: randomUUID(), lines: ["x"], entries: [0] }));
  assert.equal((await publishRaw({ entries, dialogues: eleven })).status, 400, "11 in one import");
  const ten = eleven.slice(0, 10);
  assert.equal((await publishRaw({ entries, dialogues: ten })).status, 200);
  // Ten per import: a republish may carry two imports' worth.
  const twoImports = [
    ...ten.map((d) => ({ ...d, id: randomUUID(), importId: "imp-1" })),
    ...ten.map((d) => ({ ...d, id: randomUUID(), importId: "imp-2" })),
  ];
  assert.equal((await publishRaw({ entries, dialogues: twoImports })).status, 200);
});

test("a rejected republish leaves the old dialogues in place", async () => {
  const first = await publish({ entries, dialogues: [{ id: randomUUID(), lines: ["Keep."], entries: [0] }] });
  const res = await publishRaw({
    entries,
    publishedId: first.id,
    editToken: first.editToken,
    dialogues: [{ id: randomUUID(), lines: ["x"], entries: [9] }],
  });
  assert.equal(res.status, 400);
  assert.equal(dialogueRows(first.id).length, 1);
});
