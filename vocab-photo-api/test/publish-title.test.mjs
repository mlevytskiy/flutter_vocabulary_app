import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { appHeaders, baseUrl, d1, publish, publishRaw, sql } from "./helpers.mjs";

// collections-screen T22: POST /sessions takes an optional `title` (contracts/openapi.yaml
// createSession; AC-02, AC-29, AC-30). The rule's cases are the same list as the app's
// collection_name.dart (T3): emoji, Cyrillic, 60, 61, line break, spaces.

const entries = [{ word: "get over", translation: "подолати" }];
const titleOf = (id) => d1(`SELECT title FROM sessions WHERE id = ${sql(id)}`)[0].title;

test("a create with a title stores it as typed", async () => {
  const { id } = await publish({ title: "Speaking club 12", entries });
  assert.equal(titleOf(id), "Speaking club 12");
});

test("a create without a title stores NULL (an older app keeps the Vocabulary heading)", async () => {
  const { id } = await publish({ entries });
  assert.equal(titleOf(id), null);
});

test("a republish with the edit token replaces the title on the same page and link (AC-29)", async () => {
  const first = await publish({ title: "Speaking club 12", entries });
  const again = await publish({
    title: "Speaking club 12 — idioms",
    publishedId: first.id,
    editToken: first.editToken,
    entries,
  });
  assert.equal(again.id, first.id);
  assert.equal(again.url, first.url);
  assert.equal(titleOf(first.id), "Speaking club 12 — idioms");
});

test("a republish without a title stores NULL", async () => {
  const first = await publish({ title: "Speaking club 12", entries });
  await publish({ publishedId: first.id, editToken: first.editToken, entries });
  assert.equal(titleOf(first.id), null);
});

test("valid titles: 60 code points, emoji, Cyrillic, leading and trailing spaces kept", async () => {
  const valid = [
    "a".repeat(60),
    "😀".repeat(60), // 60 code points, 120 UTF-16 units
    "Розмовний клуб 12",
    "x",
    "  Unit 3  ",
    "16.10.2026 14:30",
  ];
  for (const title of valid) {
    const { id } = await publish({ title, entries });
    assert.equal(titleOf(id), title, JSON.stringify(title));
  }
});

test("an invalid title gets 400 title_invalid and nothing is published (AC-02)", async () => {
  const invalid = ["", " ", "   ", "\t", "a".repeat(61), "😀".repeat(61), "Unit\n3", "Unit\r3", "Unit\r\n3", 12, true, ["x"], {}];
  const before = d1(`SELECT count(*) AS n FROM sessions`)[0].n;
  for (const title of invalid) {
    const res = await publishRaw({ title, entries });
    assert.equal(res.status, 400, JSON.stringify(title));
    assert.deepEqual(await res.json(), { error: "`title` must be 1 to 60 characters on one line", code: "title_invalid" });
  }
  assert.equal(d1(`SELECT count(*) AS n FROM sessions`)[0].n, before);
});

test("an invalid title on a republish keeps the stored title", async () => {
  const first = await publish({ title: "Speaking club 12", entries });
  const res = await publishRaw({ title: "a".repeat(61), publishedId: first.id, editToken: first.editToken, entries });
  assert.equal(res.status, 400);
  assert.equal(titleOf(first.id), "Speaking club 12");
});

test("dialogue and picture deliveries never change the title (AC-29)", async () => {
  const session = await publish({ title: "Speaking club 12", entries });
  const dialogueId = randomUUID();
  const headers = (extra) => appHeaders({ "x-edit-token": session.editToken, ...extra });
  const append = await fetch(`${baseUrl}/sessions/${session.id}/dialogues`, {
    method: "POST",
    headers: headers({ "content-type": "application/json" }),
    body: JSON.stringify({
      importId: "import-1",
      title: "Not this",
      entries: [{ word: "kettle", translation: "чайник" }],
      dialogues: [{ id: dialogueId, lines: ["A: The kettle!"], entries: [0], picture: { mediaType: "image/png" } }],
    }),
  });
  assert.equal(append.status, 200, await append.clone().text());
  const picture = await fetch(`${baseUrl}/sessions/${session.id}/dialogues/${dialogueId}/picture`, {
    method: "POST",
    headers: headers({ "content-type": "image/png" }),
    body: Buffer.from("png-bytes"),
  });
  assert.equal(picture.status, 200, await picture.clone().text());
  assert.equal(titleOf(session.id), "Speaking club 12");
});
