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

test("a publish rejects a row linked to an undeclared photo", async () => {
  const photo = randomUUID();
  const unlinked = await publishRaw({
    sources: [{ id: photo, order: 0 }],
    entries: [{ word: "apple", translation: "яблуко", sourceId: randomUUID() }],
  });
  assert.equal(unlinked.status, 400);
  assert.match((await unlinked.json()).error, /declared source/);
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

const SET_URL = "https://quizlet.com/987534268/job-interview-flash-cards/";

function slotsFull(id) {
  return d1(`SELECT id, ord, kind, name, url, status, arrived_rev FROM sources WHERE session_id = ${sql(id)} ORDER BY ord`);
}

// AC-13, AC-13b: photos and sets share one ordered list; sets are arrived at publish.
test("a publish with 12 photos and 3 sets stores all 15 in order, sets arrived at once", async () => {
  const photos = Array.from({ length: 12 }, () => randomUUID());
  const sets = Array.from({ length: 3 }, () => randomUUID());
  // Sets interleaved with photos: positions 3, 7 and 14.
  const sources = [];
  let p = 0;
  let s = 0;
  for (let order = 0; order < 15; order++) {
    if ([3, 7, 14].includes(order)) {
      sources.push({ id: sets[s], order, kind: "set", name: `Set ${s++}`, url: SET_URL });
    } else {
      sources.push({ id: photos[p++], order });
    }
  }
  const { id } = await publish({
    sources: sources.slice().reverse(),
    entries: [{ word: "apple", translation: "яблуко", sourceId: photos[0] }],
  });

  const stored = slotsFull(id);
  assert.deepEqual(stored.map((r) => r.id), sources.map((r) => r.id));
  assert.deepEqual(stored.map((r) => r.kind), sources.map((r) => (r.kind ?? "photo")));
  for (const row of stored) {
    if (row.kind === "set") {
      assert.equal(row.status, "arrived");
      assert.equal(row.arrived_rev, 0);
      assert.equal(row.url, SET_URL);
      assert.match(row.name, /^Set \d$/);
    } else {
      assert.equal(row.status, "pending");
      assert.equal(row.name, null);
      assert.equal(row.url, null);
    }
  }

  // No bytes for a set: upload is "not declared" and nothing is served.
  assert.equal((await uploadSource(id, sets[0], Buffer.from("x"))).status, 404);
  assert.equal((await get(`/s/${id}/sources/${sets[0]}`)).status, 404);
  assert.equal(sessionRecord(id).rev, 0);
  assert.equal(slotsFull(id).find((r) => r.id === sets[0]).status, "arrived");
});

test("an older payload without kind still publishes photos, and kind photo is the same", async () => {
  const [a, b] = [randomUUID(), randomUUID()];
  const { id } = await publish({
    sources: [{ id: a, order: 0 }, { id: b, order: 1, kind: "photo" }],
    entries: [{ word: "apple", translation: "яблуко", sourceId: a }],
  });
  assert.deepEqual(slotsFull(id).map((r) => [r.kind, r.status, r.name]), [["photo", "pending", null], ["photo", "pending", null]]);
  assert.equal((await uploadSource(id, a, Buffer.from("bytes"))).status, 200);
});

// sad §6 F4, §8: only a plain Quizlet set address is accepted; each failure is invalid_source.
test("a set source with a bad link, name or kind is refused as invalid_source", async () => {
  const entries = [{ word: "apple", translation: "яблуко" }];
  const set = (over) => ({ id: randomUUID(), order: 0, kind: "set", name: "Job interview", url: SET_URL, ...over });
  const bad = [
    { url: "https://quizlet.com/987534268/job-interview-flash-cards/?i=xxug6&x=1jqt" },
    { url: "https://quizlet.com/987534268/job-interview-flash-cards/#cards" },
    { url: "https://quizlet.com/ar/987534268/job-interview-flash-cards/" },
    { url: "https://quizlet.com/987534268/job-interview-flash-cards" },
    { url: "https://quizlet.com/987534268/" },
    { url: "https://quizlet.com/abc/job-interview-flash-cards/" },
    { url: "http://quizlet.com/987534268/job-interview-flash-cards/" },
    { url: "https://www.quizlet.com/987534268/job-interview-flash-cards/" },
    { url: "https://quizlet.com.evil.example/987534268/job-interview-flash-cards/" },
    { url: "https://evil.example/987534268/job-interview-flash-cards/" },
    { url: "https://quizlet.com/987534268/a/b/" },
    { url: "javascript:alert(1)" },
    { url: "" },
    { url: undefined },
    { url: 42 },
    { name: "" },
    { name: "   " },
    { name: undefined },
    { name: 7 },
    { kind: "video" },
  ];
  for (const over of bad) {
    const res = await publishRaw({ sources: [set(over)], entries });
    assert.equal(res.status, 400, JSON.stringify(over));
    assert.equal((await res.json()).code, "invalid_source", JSON.stringify(over));
  }
  // A photo may not carry a name or link.
  const photoWithName = await publishRaw({ sources: [{ id: randomUUID(), order: 0, name: "x" }], entries });
  assert.equal(photoWithName.status, 400);

  // The plain links the app produces are accepted.
  for (const url of [SET_URL, "https://quizlet.com/1/a/", "https://quizlet.com/123/job-interview-flash-cards-2_b/"]) {
    assert.equal((await publishRaw({ sources: [set({ url })], entries })).status, 200, url);
  }
});
