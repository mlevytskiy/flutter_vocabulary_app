import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { test } from "node:test";
import { d1, get, publish, publishRaw, uploadSource } from "./helpers.mjs";

const sql = (value) => `'${String(value).replace(/'/g, "''")}'`;

function sessionRecord(id) {
  return d1(`SELECT expires_at, rev, replaced_rev, edit_token_hash FROM sessions WHERE id = ${sql(id)}`)[0];
}

function slots(id) {
  return d1(`SELECT id, ord, status, arrived_rev FROM sources WHERE session_id = ${sql(id)} ORDER BY ord`);
}

// AC-25: recognised rows link to the photo they came from; typed rows link to none.
test("a publish with two declared photos links each recognised row to its slot", async () => {
  const [photoA, photoB] = [randomUUID(), randomUUID()];
  const { id } = await publish({
    // Listed out of order: the pager order is `order`, not the array's.
    sources: [
      { id: photoB, order: 1 },
      { id: photoA, order: 0 },
    ],
    entries: [
      { word: "apple", translation: "яблуко", sourceId: photoA },
      { word: "pear", translation: "груша", sourceId: photoB },
      { word: "typed", translation: "набране" },
      { word: "plum", translation: "слива", sourceId: photoA },
    ],
  });

  const rows = d1(`SELECT word, source_id FROM rows WHERE session_id = ${sql(id)} ORDER BY position`);
  assert.deepEqual(rows, [
    { word: "apple", source_id: photoA },
    { word: "pear", source_id: photoB },
    { word: "typed", source_id: null },
    { word: "plum", source_id: photoA },
  ]);
  assert.deepEqual(slots(id), [
    { id: photoA, ord: 0, status: "pending", arrived_rev: null },
    { id: photoB, ord: 1, status: "pending", arrived_rev: null },
  ]);

  // A pending photo has no bytes to serve yet.
  assert.equal((await get(`/s/${id}/sources/${photoA}`)).status, 404);

  assert.equal((await uploadSource(id, photoA, Buffer.from("bytes of photo A"))).status, 200);
  assert.equal((await uploadSource(id, photoB, Buffer.from("bytes of photo B"), "image/jpeg")).status, 200);
  assert.deepEqual(
    slots(id).map((s) => [s.id, s.status]),
    [
      [photoA, "arrived"],
      [photoB, "arrived"],
    ]
  );

  const a = await get(`/s/${id}/sources/${photoA}`);
  assert.equal(a.status, 200);
  assert.equal(a.headers.get("content-type"), "image/png");
  assert.equal(await a.text(), "bytes of photo A");
  const b = await get(`/s/${id}/sources/${photoB}`);
  assert.equal(b.headers.get("content-type"), "image/jpeg");
  assert.equal(await b.text(), "bytes of photo B");

  const page = await (await get(`/s/${id}`)).text();
  assert.match(page, new RegExp(`/s/${id}/sources/${photoA}[\\s\\S]*/s/${id}/sources/${photoB}`));
});

test("an upload to an undeclared photo id is refused and a repeated upload changes nothing", async () => {
  const photo = randomUUID();
  const { id } = await publish({
    sources: [{ id: photo, order: 0 }],
    entries: [{ word: "apple", translation: "яблуко", sourceId: photo }],
  });

  const guessed = randomUUID();
  const refused = await uploadSource(id, guessed, Buffer.from("not declared"));
  assert.equal(refused.status, 404);
  assert.equal((await get(`/s/${id}/sources/${guessed}`)).status, 404);
  assert.equal(sessionRecord(id).rev, 0);
  // A photo declared by another session is not this session's either.
  assert.equal((await uploadSource(randomUUID(), photo, Buffer.from("x"))).status, 404);

  const first = await uploadSource(id, photo, Buffer.from("the first bytes"));
  assert.equal(first.status, 200);
  const afterFirst = { session: sessionRecord(id), slots: slots(id) };
  assert.equal(afterFirst.session.rev, 1);
  assert.deepEqual(afterFirst.slots, [{ id: photo, ord: 0, status: "arrived", arrived_rev: 1 }]);

  const repeat = await uploadSource(id, photo, Buffer.from("different bytes"));
  assert.equal(repeat.status, 200);
  assert.deepEqual(await repeat.json(), await first.json());
  assert.deepEqual({ session: sessionRecord(id), slots: slots(id) }, afterFirst);
  assert.equal(await (await get(`/s/${id}/sources/${photo}`)).text(), "the first bytes");
});

// AC-24: "include photos" off means the app sends no sources; nothing is reachable.
test("a session published without sources answers gone for any guessed photo path", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  assert.deepEqual(slots(id), []);

  for (const guess of [randomUUID(), "0", "photo", "kv-0"]) {
    const res = await get(`/s/${id}/sources/${guess}`);
    assert.equal(res.status, 404);
    assert.match(await res.text(), /This word list is gone/);
    assert.equal((await uploadSource(id, guess, Buffer.from("x"))).status, 404);
  }
  assert.doesNotMatch(await (await get(`/s/${id}`)).text(), /<img/i);
});

test("a publish rejects a row linked to an undeclared photo and more than 10 photos", async () => {
  const photo = randomUUID();
  const unlinked = await publishRaw({
    sources: [{ id: photo, order: 0 }],
    entries: [{ word: "apple", translation: "яблуко", sourceId: randomUUID() }],
  });
  assert.equal(unlinked.status, 400);
  assert.match((await unlinked.json()).error, /declared source/);

  const eleven = await publishRaw({
    sources: Array.from({ length: 11 }, (_, order) => ({ id: randomUUID(), order })),
    entries: [{ word: "apple", translation: "яблуко" }],
  });
  assert.equal(eleven.status, 400);
  assert.match((await eleven.json()).error, /at most 10/);
});

// ADR-0008: the token overwrites the same link; the Worker keeps only its hash.
test("a republish with the token keeps the link and expiry and replaces rows and photos", async () => {
  const [oldPhoto, newPhoto] = [randomUUID(), randomUUID()];
  const first = await publish({
    sources: [{ id: oldPhoto, order: 0 }],
    entries: [
      { word: "apple", translation: "яблуко", sourceId: oldPhoto },
      { word: "pear", translation: "груша" },
    ],
  });
  assert.equal(typeof first.editToken, "string");
  assert.ok(first.editToken.length >= 32);
  const stored = sessionRecord(first.id);
  assert.equal(stored.edit_token_hash, createHash("sha256").update(first.editToken).digest("hex"));
  await uploadSource(first.id, oldPhoto, Buffer.from("old photo"));
  assert.equal(sessionRecord(first.id).rev, 1);

  const again = await publish({
    publishedId: first.id,
    editToken: first.editToken,
    detail: "both",
    sources: [{ id: newPhoto, order: 0 }],
    entries: [{ word: "kettle", translation: "чайник", definition: "a pot", sourceId: newPhoto }],
  });
  assert.equal(again.id, first.id);
  assert.equal(again.url, first.url);
  assert.equal(again.expiresAt, first.expiresAt);
  assert.equal(again.editToken, first.editToken);

  const replaced = sessionRecord(first.id);
  assert.equal(replaced.expires_at, stored.expires_at);
  assert.deepEqual([replaced.rev, replaced.replaced_rev], [2, 2]);
  assert.deepEqual(
    d1(`SELECT word, source_id, word_rev, definition_rev FROM rows WHERE session_id = ${sql(first.id)}`),
    [{ word: "kettle", source_id: newPhoto, word_rev: 2, definition_rev: 2 }]
  );
  assert.deepEqual(slots(first.id), [{ id: newPhoto, ord: 0, status: "pending", arrived_rev: null }]);
  // The dropped photo's bytes may linger in R2, but it is no longer this session's.
  assert.equal((await get(`/s/${first.id}/sources/${oldPhoto}`)).status, 404);

  const page = await (await get(`/s/${first.id}`)).text();
  assert.match(page, /<div class="v">kettle<\/div>/);
  assert.doesNotMatch(page, /<div class="v">(apple|pear)<\/div>/);

  // A second republish raises the revision again; it never goes back.
  await publish({ publishedId: first.id, editToken: first.editToken, entries: [{ word: "cup", translation: "чашка" }] });
  const twice = sessionRecord(first.id);
  assert.deepEqual([twice.rev, twice.replaced_rev], [3, 3]);
});

test("a wrong token or an expired link yields a new link and leaves the old one untouched", async () => {
  const first = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });

  const wrong = await publish({
    publishedId: first.id,
    editToken: "not-the-token",
    entries: [{ word: "vandal", translation: "вандал" }],
  });
  assert.notEqual(wrong.id, first.id);
  assert.notEqual(wrong.editToken, first.editToken);
  assert.deepEqual(d1(`SELECT word FROM rows WHERE session_id = ${sql(first.id)}`), [{ word: "apple" }]);
  assert.deepEqual([sessionRecord(first.id).rev, sessionRecord(first.id).replaced_rev], [0, 0]);

  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(first.id)}`);
  const expired = await publish({
    publishedId: first.id,
    editToken: first.editToken,
    entries: [{ word: "pear", translation: "груша" }],
  });
  assert.notEqual(expired.id, first.id);
  assert.equal((await get(`/s/${first.id}`)).status, 404);
  assert.match(await (await get(`/s/${expired.id}`)).text(), /pear/);
});

// AC-26: older app builds send neither photos nor a token and publish as before.
test("an old-shape publish (no sources, no token) still succeeds", async () => {
  const res = await publishRaw({ entries: [{ word: "apple", translation: "яблуко" }] });
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(Object.keys(body).sort(), ["editToken", "expiresAt", "id", "url"]);
  assert.equal((await get(`/s/${body.id}`)).status, 200);
  assert.deepEqual(slots(body.id), []);
});
