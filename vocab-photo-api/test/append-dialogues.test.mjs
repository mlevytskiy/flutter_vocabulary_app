import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { appHeaders, baseUrl, d1, get, pagePost, publish, sql, storedRows } from "./helpers.mjs";

// AC-20 (dialogues and pictures added later reach the same link), AC-22 (only the app, with the
// session's edit token, writes; the page and anyone else cannot).

const entries = [
  { word: "apple", translation: "яблуко" },
  { word: "pear", translation: "груша" },
];

const png = Buffer.from("89504e470d0a1a0a-scene", "utf8");

function post(path, body, { token, headers = {} } = {}) {
  return fetch(`${baseUrl}${path}`, {
    method: "POST",
    headers: appHeaders({
      "content-type": "application/json",
      ...(token == null ? {} : { "x-edit-token": token }),
      ...headers,
    }),
    body: JSON.stringify(body),
  });
}

const append = (session, body, token = session.editToken) => post(`/sessions/${session.id}/dialogues`, body, { token });

function uploadPicture(session, dialogueId, bytes = png, { token = session.editToken, type = "image/png" } = {}) {
  return fetch(`${baseUrl}/sessions/${session.id}/dialogues/${dialogueId}/picture`, {
    method: "POST",
    headers: appHeaders({ "content-type": type, ...(token == null ? {} : { "x-edit-token": token }) }),
    body: bytes,
  });
}

const rev = (id) => d1(`SELECT rev FROM sessions WHERE id = ${sql(id)}`)[0].rev;
const dialogueRows = (id) =>
  d1(
    `SELECT id, position, lines_json, import_id, added_rev, picture_media_type, picture_bytes, picture_arrived_rev
     FROM dialogues WHERE session_id = ${sql(id)} ORDER BY position`
  );
const wordsOf = (id, dialogueId) =>
  d1(
    `SELECT r.word FROM dialogue_words dw JOIN rows r ON r.session_id = dw.session_id AND r.id = dw.row_id
     WHERE dw.session_id = ${sql(id)} AND dw.dialogue_id = ${sql(dialogueId)} ORDER BY r.position`
  ).map((r) => r.word);
const imports = (id) =>
  d1(`SELECT import_id FROM dialogue_imports WHERE session_id = ${sql(id)} ORDER BY import_id`).map((r) => r.import_id);

/** Whether the local R2 bucket holds `key` (wrangler reads the state `wrangler dev` writes). */
function r2Has(key) {
  const dir = mkdtempSync(join(tmpdir(), "r2-probe-"));
  try {
    const out = join(dir, "object");
    const res = spawnSync(
      "npx",
      ["wrangler", "r2", "object", "get", `vocab-photo-sources/${key}`, "--local", "--persist-to", process.env.VOCAB_API_STATE_DIR, "--file", out],
      { cwd: fileURLToPath(new URL("..", import.meta.url)), encoding: "utf8", env: { ...process.env, CI: "1" } }
    );
    return res.status === 0 && existsSync(out) ? readFileSync(out) : null;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const importBody = (importId, dialogueId = randomUUID()) => ({
  importId,
  entries: [
    { word: "kettle", translation: "чайник", definition: "a pot" },
    { word: "ladle", translation: "черпак" },
  ],
  dialogues: [{ id: dialogueId, lines: ["A: The kettle!", "B: Where is the ladle?"], entries: [0, 1] }],
});

test("an append adds rows after the existing ones and dialogues after the existing dialogues, at one new revision", async () => {
  const firstDialogue = randomUUID();
  const session = await publish({
    entries,
    dialogues: [{ id: firstDialogue, lines: ["Eat an apple."], entries: [0] }],
  });
  const before = rev(session.id);

  const second = randomUUID();
  const res = await append(session, importBody("import-1", second));
  assert.equal(res.status, 200);
  const answer = await res.json();
  assert.equal(answer.importId, "import-1");
  assert.equal(answer.rev, before + 1);
  assert.equal(rev(session.id), before + 1);

  const rows = storedRows(session.id);
  assert.deepEqual(
    rows.map((r) => [r.word, r.position]),
    [["apple", 0], ["pear", 1], ["kettle", 2], ["ladle", 3]]
  );
  // The new rows are at the new revision, so polling pages fetch them; the old rows are untouched.
  assert.deepEqual(rows.slice(0, 2).map((r) => r.word_rev), [0, 0]);
  assert.deepEqual(rows.slice(2).map((r) => [r.word_rev, r.translation_rev, r.definition_rev]), [
    [before + 1, before + 1, before + 1],
    [before + 1, before + 1, before + 1],
  ]);
  assert.equal(rows[2].definition, "a pot");

  const dialogues = dialogueRows(session.id);
  assert.deepEqual(dialogues.map((d) => [d.id, d.position, d.added_rev, d.import_id]), [
    [firstDialogue, 0, 0, ""],
    [second, 1, before + 1, "import-1"],
  ]);
  assert.deepEqual(wordsOf(session.id, second), ["kettle", "ladle"]);
  assert.deepEqual(imports(session.id), ["import-1"]);
  // The page shows the new words.
  assert.match(await (await get(`/s/${session.id}`)).text(), /kettle/);
});

test("an append may bring only rows, or only dialogues about existing-free entries", async () => {
  const session = await publish({ entries });
  const res = await append(session, { importId: "rows-only", entries: [{ word: "cup", translation: "чашка" }], dialogues: [] });
  assert.equal(res.status, 200);
  assert.deepEqual(storedRows(session.id).map((r) => r.word), ["apple", "pear", "cup"]);
  assert.deepEqual(dialogueRows(session.id), []);
});

test("a repeated import id adds nothing and answers the same", async () => {
  const session = await publish({ entries });
  const body = importBody("import-1");
  const first = await append(session, body);
  const afterFirst = rev(session.id);
  const again = await append(session, body);
  assert.equal(again.status, 200);
  assert.deepEqual(await again.json(), await first.json());
  assert.equal(rev(session.id), afterFirst);
  assert.equal(storedRows(session.id).length, 4);
  assert.equal(dialogueRows(session.id).length, 1);
  assert.deepEqual(imports(session.id), ["import-1"]);
});

test("an append whose dialogue ids already came with a republish is a repeat, and a republish need not record the import", async () => {
  const session = await publish({ entries });
  const shared = randomUUID();
  // The app republished everything, this import's dialogue included, before its append was retried.
  await publish({
    publishedId: session.id,
    editToken: session.editToken,
    entries: [...entries, { word: "kettle", translation: "чайник" }, { word: "ladle", translation: "черпак" }],
    dialogues: [{ id: shared, lines: ["A: The kettle!"], entries: [2, 3], importId: "import-9" }],
  });
  const before = rev(session.id);
  const res = await append(session, importBody("import-9", shared));
  assert.equal(res.status, 200);
  assert.equal(rev(session.id), before);
  assert.equal(storedRows(session.id).length, 4);
  assert.equal(dialogueRows(session.id).length, 1);
});

test("a partner's edit on an existing row survives an append", async () => {
  const session = await publish({ entries });
  const [apple] = storedRows(session.id);
  const saved = await pagePost(`/s/${session.id}/cells`, {
    rowId: apple.id,
    field: "translation",
    value: "яблучко",
    baseRev: apple.translation_rev,
  });
  assert.equal(saved.status, 200);

  assert.equal((await append(session, importBody("import-1"))).status, 200);
  const rows = storedRows(session.id);
  assert.equal(rows[0].translation, "яблучко");
  assert.equal(rows[0].translation_rev, saved.body.rev);
  assert.equal(rows.length, 4);
});

test("a wrong or missing edit token is refused and changes nothing", async () => {
  const session = await publish({ entries });
  const other = await publish({ entries });
  const before = rev(session.id);
  for (const token of ["nope", other.editToken, null]) {
    const res = await append(session, importBody("import-1"), token);
    assert.equal(res.status, 403);
    assert.equal((await res.json()).code, "forbidden");
  }
  assert.equal(rev(session.id), before);
  assert.equal(storedRows(session.id).length, 2);
  assert.deepEqual(imports(session.id), []);
});

test("an unknown or expired session answers gone", async () => {
  const session = await publish({ entries });
  const unknown = await post(`/sessions/${randomUUID()}/dialogues`, importBody("i"), { token: session.editToken });
  assert.equal(unknown.status, 404);
  assert.equal((await unknown.json()).code, "gone");

  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(session.id)}`);
  const expired = await append(session, importBody("i"));
  assert.equal(expired.status, 404);
  assert.equal((await expired.json()).code, "gone");
  const picture = await uploadPicture(session, randomUUID());
  assert.equal(picture.status, 404);
  assert.equal((await picture.json()).code, "gone");
});

test("the write routes need the app secret: the page and anyone else cannot call them", async () => {
  const session = await publish({ entries });
  const dialogueId = randomUUID();
  await append(session, importBody("import-1", dialogueId));
  const noSecret = await fetch(`${baseUrl}/sessions/${session.id}/dialogues`, {
    method: "POST",
    headers: { "content-type": "application/json", "x-edit-token": session.editToken },
    body: JSON.stringify(importBody("import-2")),
  });
  assert.equal(noSecret.status, 401);
  const noSecretPicture = await fetch(`${baseUrl}/sessions/${session.id}/dialogues/${dialogueId}/picture`, {
    method: "POST",
    headers: { "content-type": "image/png", "x-edit-token": session.editToken },
    body: png,
  });
  assert.equal(noSecretPicture.status, 401);
  // The page's own (public) paths do not take these writes either.
  const viaPage = await pagePost(`/s/${session.id}/dialogues`, importBody("import-3"));
  assert.equal(viaPage.status, 404);
  assert.deepEqual(imports(session.id), ["import-1"]);
  assert.equal(dialogueRows(session.id)[0].picture_arrived_rev, null);
});

test("an append with a bad body is a 400 and writes nothing", async () => {
  const session = await publish({ entries });
  const bad = [
    { entries: [], dialogues: [] },
    { importId: "bad id!", entries: [], dialogues: [] },
    { importId: "i", entries: "nope" },
    { importId: "i", entries: [{ word: "cup", translation: "x" }], dialogues: [{ id: randomUUID(), lines: ["x"], entries: [5] }] },
    { importId: "i", entries: [{ word: "cup", translation: "x" }], dialogues: [{ id: randomUUID(), lines: [], entries: [0] }] },
  ];
  for (const body of bad) {
    const res = await append(session, body);
    assert.equal(res.status, 400, JSON.stringify(body));
  }
  assert.equal(storedRows(session.id).length, 2);
  assert.deepEqual(imports(session.id), []);
});

test("a picture upload makes the picture readable by its public link, once", async () => {
  const session = await publish({ entries });
  const dialogueId = randomUUID();
  await append(session, importBody("import-1", dialogueId));
  const url = `/s/${session.id}/dialogues/${dialogueId}/picture`;
  assert.equal((await get(url)).status, 404);

  const before = rev(session.id);
  const res = await uploadPicture(session, dialogueId);
  assert.equal(res.status, 200);
  const answer = await res.json();
  assert.equal(answer.dialogueId, dialogueId);
  assert.equal(answer.url.endsWith(url), true);
  assert.equal(rev(session.id), before + 1);
  const [stored] = dialogueRows(session.id);
  assert.deepEqual([stored.picture_media_type, stored.picture_bytes, stored.picture_arrived_rev], ["image/png", png.length, before + 1]);

  const read = await get(url);
  assert.equal(read.status, 200);
  assert.equal(read.headers.get("content-type"), "image/png");
  assert.deepEqual(Buffer.from(await read.arrayBuffer()), png);

  // A repeat after the bytes arrived answers the same and changes nothing.
  const again = await uploadPicture(session, dialogueId, Buffer.from("other bytes"));
  assert.equal(again.status, 200);
  assert.deepEqual(await again.json(), answer);
  assert.equal(rev(session.id), before + 1);
  assert.deepEqual(Buffer.from(await (await get(url)).arrayBuffer()), png);
  assert.equal(r2Has(`sessions/${session.id}/dialogues/${dialogueId}/picture`)?.equals(png), true);
});

test("a picture upload with a wrong token, a bad type or an undeclared dialogue is refused", async () => {
  const session = await publish({ entries });
  const dialogueId = randomUUID();
  await append(session, importBody("import-1", dialogueId));
  assert.equal((await uploadPicture(session, dialogueId, png, { token: "nope" })).status, 403);
  assert.equal((await uploadPicture(session, dialogueId, png, { token: null })).status, 403);
  assert.equal((await uploadPicture(session, dialogueId, png, { type: "text/html" })).status, 400);
  assert.equal((await uploadPicture(session, dialogueId, Buffer.alloc(0))).status, 400);
  assert.equal((await uploadPicture(session, randomUUID())).status, 404);
  assert.equal(dialogueRows(session.id)[0].picture_arrived_rev, null);
  assert.equal((await get(`/s/${session.id}/dialogues/${dialogueId}/picture`)).status, 404);
});

test("a picture is readable only while its session is live", async () => {
  const session = await publish({ entries });
  const dialogueId = randomUUID();
  await append(session, importBody("import-1", dialogueId));
  assert.equal((await uploadPicture(session, dialogueId)).status, 200);
  assert.equal((await get(`/s/${session.id}/dialogues/${dialogueId}/picture`)).status, 200);
  d1(`UPDATE sessions SET expires_at = '2000-01-01T00:00:00.000Z' WHERE id = ${sql(session.id)}`);
  assert.equal((await get(`/s/${session.id}/dialogues/${dialogueId}/picture`)).status, 404);
});

test("a republish deletes the stored pictures of dialogues that are gone and keeps the others' objects", async () => {
  const [gone, kept] = [randomUUID(), randomUUID()];
  const session = await publish({
    entries,
    dialogues: [
      { id: gone, lines: ["Old."], entries: [0] },
      { id: kept, lines: ["Stays."], entries: [1] },
    ],
  });
  await uploadPicture(session, gone);
  await uploadPicture(session, kept);
  const goneKey = `sessions/${session.id}/dialogues/${gone}/picture`;
  const keptKey = `sessions/${session.id}/dialogues/${kept}/picture`;
  assert.ok(r2Has(goneKey));

  await publish({
    publishedId: session.id,
    editToken: session.editToken,
    entries,
    dialogues: [{ id: kept, lines: ["Stays."], entries: [1] }],
  });
  assert.equal(r2Has(goneKey), null);
  assert.ok(r2Has(keptKey));
  assert.equal((await get(`/s/${session.id}/dialogues/${gone}/picture`)).status, 404);
});
