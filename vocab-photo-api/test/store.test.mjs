import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { d1, get, kvDelete, kvPut, publish } from "./helpers.mjs";

const sql = (value) => `'${String(value).replace(/'/g, "''")}'`;

async function openPage(id) {
  const res = await get(`/s/${id}`);
  return { status: res.status, html: await res.text() };
}

test("a publish is stored in D1 and the page shows its rows", async () => {
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
    ],
  });

  const rows = d1(`SELECT word, translation, position FROM rows WHERE session_id = ${sql(id)} ORDER BY position`);
  assert.deepEqual(rows, [
    { word: "apple", translation: "яблуко", position: 0 },
    { word: "pear", translation: "груша", position: 1 },
  ]);

  const page = await openPage(id);
  assert.equal(page.status, 200);
  assert.match(page.html, /apple[\s\S]*яблуко[\s\S]*pear[\s\S]*груша/);
});

// AC-27: every translation and definition sent is stored, whatever the mode.
test("a publish in translation mode still stores the definitions it receives", async () => {
  const { id } = await publish({
    detail: "translation",
    entries: [{ word: "apple", translation: "яблуко", definition: "a round fruit" }],
  });

  const [row] = d1(`SELECT translation, definition FROM rows WHERE session_id = ${sql(id)}`);
  assert.deepEqual(row, { translation: "яблуко", definition: "a round fruit" });
});

// AC-26 for old links: a pre-feature KV document is imported on its first open.
test("a link published to KV before the feature is imported into D1 on first open", async () => {
  const id = randomUUID();
  const doc = {
    id,
    createdAt: "2026-09-20T10:00:00.000Z",
    expiresAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
    detail: "both",
    entries: [
      { word: "kettle", translation: "чайник", definition: "a pot for boiling water" },
      { word: "spoon", translation: "ложка" },
    ],
    sources: [],
  };
  kvPut(`session:${id}`, JSON.stringify(doc));
  assert.deepEqual(d1(`SELECT id FROM sessions WHERE id = ${sql(id)}`), []);

  const first = await openPage(id);
  assert.equal(first.status, 200);
  assert.match(first.html, /kettle[\s\S]*чайник[\s\S]*a pot for boiling water[\s\S]*spoon/);

  const [session] = d1(`SELECT created_at, expires_at, detail FROM sessions WHERE id = ${sql(id)}`);
  assert.deepEqual(session, { created_at: doc.createdAt, expires_at: doc.expiresAt, detail: "both" });
  assert.equal(d1(`SELECT count(*) AS n FROM rows WHERE session_id = ${sql(id)}`)[0].n, 2);

  // With the KV copy gone, the second open can only have come from D1.
  kvDelete(`session:${id}`);
  const second = await openPage(id);
  assert.equal(second.status, 200);
  assert.equal(second.html, first.html);
});

// AC-32: an expired link and a mistyped one are indistinguishable.
test("expired and unknown ids get byte-identical gone pages", async () => {
  const { id } = await publish();
  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(id)}`);

  const expired = await get(`/s/${id}`);
  const unknown = await get(`/s/${randomUUID()}`);
  const expiredBody = Buffer.from(await expired.arrayBuffer());
  const unknownBody = Buffer.from(await unknown.arrayBuffer());

  assert.equal(expired.status, 404);
  assert.equal(unknown.status, 404);
  assert.equal(expired.headers.get("content-type"), unknown.headers.get("content-type"));
  assert.ok(expiredBody.equals(unknownBody), "the two gone pages differ");
  assert.match(expiredBody.toString(), /This word list is gone/);
});

test("an expired session's AnkiDroid file is gone too", async () => {
  const { id } = await publish();
  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(id)}`);

  const res = await get(`/s/${id}/words.txt`);
  assert.equal(res.status, 404);
  assert.match(await res.text(), /This word list is gone/);
});
