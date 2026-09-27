import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { baseUrl, d1, kvPut, pagePost, publish, sql, storedRows, uploadSource } from "./helpers.mjs";

/** A poll from the page: public, no secret. Returns `{ status, body }`. */
async function changes(id, since, ip) {
  const headers = ip ? { "cf-connecting-ip": ip } : {};
  const res = await fetch(`${baseUrl}/s/${id}/changes?since=${since}`, { headers });
  return { status: res.status, body: await res.json() };
}

const nothing = (rev) => ({ rev, cells: [], rows: [], deleted: [], sources: [] });

// ADR-0005: a poll from the last seen revision returns exactly what changed after it.
test("a poll from the old revision returns the saved cell; from the new one, nothing", async () => {
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
    ],
  });
  const [, pear] = storedRows(id);
  assert.deepEqual((await changes(id, 0)).body, nothing(0));

  const saved = await pagePost(`/s/${id}/cells`, { rowId: pear.id, field: "translation", value: "грушка", baseRev: 0 });
  assert.equal(saved.status, 200);

  assert.deepEqual((await changes(id, 0)).body, {
    ...nothing(1),
    cells: [{ rowId: pear.id, field: "translation", value: "грушка", rev: 1 }],
  });
  assert.deepEqual((await changes(id, 1)).body, nothing(1));
});

test("rows added after the cursor arrive whole, also after later edits; the edits alone arrive as cells", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const rowId = randomUUID();
  assert.equal((await pagePost(`/s/${id}/rows`, { rowId, field: "word", value: "kettle" })).status, 200);

  const row = (translation, revs) => ({ rowId, position: 1, sourceId: null, word: "kettle", translation, definition: "", revs });
  assert.deepEqual((await changes(id, 0)).body, {
    ...nothing(1),
    rows: [row("", { word: 1, translation: 1, definition: 1 })],
  });

  await pagePost(`/s/${id}/cells`, { rowId, field: "translation", value: "чайник", baseRev: 1 });
  // A page that already has the row gets only the new cell.
  assert.deepEqual((await changes(id, 1)).body, {
    ...nothing(2),
    cells: [{ rowId, field: "translation", value: "чайник", rev: 2 }],
  });
  // A page that never saw the row still gets it whole, as saved now.
  assert.deepEqual((await changes(id, 0)).body, {
    ...nothing(2),
    rows: [row("чайник", { word: 1, translation: 2, definition: 1 })],
  });
});

// AC-37: a delete reaches other pages as a tombstone; a photo's bytes as an arrived slot.
test("a delete appears as a tombstone and a photo arrival as an arrived slot", async () => {
  const [photo, later] = [randomUUID(), randomUUID()];
  const { id } = await publish({
    sources: [
      { id: photo, order: 0 },
      { id: later, order: 1 },
    ],
    entries: [
      { word: "apple", translation: "яблуко", sourceId: photo },
      { word: "pear", translation: "груша" },
    ],
  });
  const [, pear] = storedRows(id);

  assert.equal((await uploadSource(id, photo, Buffer.from("photo bytes"), "image/jpeg")).status, 200);
  const deleted = await pagePost(`/s/${id}/rows/delete`, {
    rowId: pear.id,
    revs: { word: 0, translation: 0, definition: 0 },
  });
  assert.equal(deleted.status, 200);

  assert.deepEqual((await changes(id, 0)).body, {
    ...nothing(2),
    deleted: [{ rowId: pear.id, rev: 2 }],
    sources: [{ id: photo, ord: 0, mediaType: "image/jpeg", rev: 1 }],
  });
  assert.deepEqual((await changes(id, 1)).body, { ...nothing(2), deleted: [{ rowId: pear.id, rev: 2 }] });
});

// ADR-0008: a republish replaces the list, so a page from before it reloads.
test("after a republish the feed answers reload for a cursor from before it", async () => {
  const first = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const [apple] = storedRows(first.id);
  await pagePost(`/s/${first.id}/cells`, { rowId: apple.id, field: "word", value: "apples", baseRev: 0 });

  await publish({
    publishedId: first.id,
    editToken: first.editToken,
    entries: [{ word: "kettle", translation: "чайник" }],
  });
  assert.deepEqual((await changes(first.id, 1)).body, { rev: 2, reload: true });
  assert.deepEqual((await changes(first.id, 0)).body, { rev: 2, reload: true });
  assert.deepEqual((await changes(first.id, 2)).body, nothing(2));
  // A cursor ahead of the session is not from this list: reload too.
  assert.deepEqual((await changes(first.id, 7)).body, { rev: 2, reload: true });
});

test("a link still only in KV is imported by its first poll", async () => {
  const id = randomUUID();
  kvPut(
    `session:${id}`,
    JSON.stringify({
      id,
      createdAt: "2026-09-20T10:00:00.000Z",
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      detail: "translation",
      entries: [{ word: "kettle", translation: "чайник" }],
      sources: [],
    })
  );
  assert.deepEqual((await changes(id, 0)).body, nothing(0));
  assert.equal(storedRows(id).length, 1);
});

test("the feed answers gone for unknown and expired ids, refuses a bad cursor, and is never rate-limited", async () => {
  const unknown = await changes(randomUUID(), 0);
  assert.equal(unknown.status, 404);
  assert.equal(unknown.body.code, "gone");

  const expired = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(expired.id)}`);
  assert.deepEqual(await changes(expired.id, 0), unknown);

  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  for (const since of ["", "-1", "1.5", "abc"]) {
    const bad = await changes(id, since);
    assert.equal(bad.status, 400, `since=${since}`);
    assert.equal(bad.body.code, "bad_request");
  }
  assert.equal((await fetch(`${baseUrl}/s/${id}/changes`)).status, 400);

  // Polling is not a page write: 320 polls from one address in a minute all answer.
  const ip = `192.168.3.${Math.floor(Math.random() * 250)}`;
  for (let i = 0; i < 320; i += 40) {
    const batch = await Promise.all(Array.from({ length: 40 }, () => changes(id, 0, ip)));
    assert.deepEqual([...new Set(batch.map((res) => res.status))], [200]);
  }
});
