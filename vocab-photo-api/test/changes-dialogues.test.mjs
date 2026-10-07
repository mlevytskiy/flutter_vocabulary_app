import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { appHeaders, baseUrl, pagePost, publish, storedRows } from "./helpers.mjs";

// AC-20 (dialogues and scene pictures reach the shared page through the change feed) and AC-21
// (a partner's edit or delete changes the dialogue's words by the AC-11 rules, on the page's data).

const png = Buffer.from("89504e470d0a1a0a-scene", "utf8");

async function changes(id, since) {
  const res = await fetch(`${baseUrl}/s/${id}/changes?since=${since}`);
  return { status: res.status, body: await res.json() };
}

const post = (path, session, body, headers = {}) =>
  fetch(`${baseUrl}${path}`, {
    method: "POST",
    headers: appHeaders({ "content-type": "application/json", "x-edit-token": session.editToken, ...headers }),
    body: JSON.stringify(body),
  });

const append = (session, body) => post(`/sessions/${session.id}/dialogues`, session, body);
const uploadPicture = (session, dialogueId) =>
  fetch(`${baseUrl}/sessions/${session.id}/dialogues/${dialogueId}/picture`, {
    method: "POST",
    headers: appHeaders({ "content-type": "image/png", "x-edit-token": session.editToken }),
    body: png,
  });

const LINES = ["A: Grab the rope!", "B: I can't lift it, the tide is coming."];

/** A session whose one dialogue (published with it) is about grab, rope and tide. */
async function sessionWithDialogue() {
  const dialogueId = randomUUID();
  const session = await publish({
    entries: [
      { word: "grab", translation: "хапати", definition: "to seize" },
      { word: "rope", translation: "мотузка" },
      { word: "tide", translation: "приплив" },
      { word: "apple", translation: "яблуко" },
    ],
    dialogues: [{ id: dialogueId, lines: LINES, entries: [0, 1, 2] }],
  });
  const rows = storedRows(session.id);
  const byWord = Object.fromEntries(rows.map((r) => [r.word, r.id]));
  return { session, dialogueId, byWord };
}

const editCell = (id, rowId, field, value, baseRev) =>
  pagePost(`/s/${id}/cells`, { rowId, field, value, baseRev });

const wordOf = (dialogue, word) => dialogue.words.find((w) => w.word === word);

test("a feed answer with no dialogue change carries no dialogue keys", async () => {
  const { session } = await sessionWithDialogue();
  const body = (await changes(session.id, 0)).body;
  assert.equal("dialogues" in body, false);
  assert.equal("removedDialogues" in body, false);
});

test("a dialogue appended after the cursor arrives with its lines, picture-less, and its words with bold places", async () => {
  const { session } = await sessionWithDialogue();
  const dialogueId = randomUUID();
  const res = await append(session, {
    importId: "import-1",
    entries: [
      { word: "kettle", translation: "чайник", definition: "a pot" },
      { word: "ladle", translation: "черпак" },
    ],
    dialogues: [{ id: dialogueId, lines: ["A: The kettle!", "B: Where is the ladle? The Kettle."], entries: [0, 1] }],
  });
  assert.equal(res.status, 200);
  const { rev } = await res.json();

  const { body } = await changes(session.id, rev - 1);
  assert.equal(body.rev, rev);
  assert.equal(body.dialogues.length, 1);
  const [dialogue] = body.dialogues;
  assert.equal(dialogue.id, dialogueId);
  assert.equal(dialogue.position, 1);
  assert.deepEqual(dialogue.lines, ["A: The kettle!", "B: Where is the ladle? The Kettle."]);
  assert.equal(dialogue.picture, null);
  assert.deepEqual(
    dialogue.words.map((w) => [w.word, w.translation, w.definition, w.places]),
    [
      ["kettle", "чайник", "a pot", [[[7, 13]], [[27, 33]]]],
      ["ladle", "черпак", "", [[], [[16, 21]]]],
    ]
  );
  assert.ok(dialogue.words.every((w) => typeof w.rowId === "string" && w.rowId.length > 0));
  // The appended rows come in the same answer, one snapshot.
  assert.deepEqual(body.rows.map((r) => r.word), ["kettle", "ladle"]);
  // A page already at the new revision hears nothing.
  assert.equal("dialogues" in (await changes(session.id, rev)).body, false);
});

test("a scene picture arriving after the cursor sends the dialogue with its picture link data", async () => {
  const { session, dialogueId } = await sessionWithDialogue();
  const up = await uploadPicture(session, dialogueId);
  assert.equal(up.status, 200);

  const { body } = await changes(session.id, 0);
  assert.equal(body.dialogues.length, 1);
  assert.equal(body.dialogues[0].id, dialogueId);
  assert.deepEqual(body.dialogues[0].picture, { mediaType: "image/png", rev: body.rev });
  assert.deepEqual(body.dialogues[0].words.map((w) => w.word), ["grab", "rope", "tide"]);
  assert.equal("dialogues" in (await changes(session.id, body.rev)).body, false);
});

test("an edited translation sends the dialogue in its new state; a row outside every dialogue sends none", async () => {
  const { session, dialogueId, byWord } = await sessionWithDialogue();
  assert.equal((await editCell(session.id, byWord.apple, "translation", "яблучко", 0)).status, 200);
  assert.equal("dialogues" in (await changes(session.id, 0)).body, false);

  assert.equal((await editCell(session.id, byWord.rope, "translation", "канат", 0)).status, 200);
  const { body } = await changes(session.id, 1);
  assert.equal(body.dialogues.length, 1);
  assert.equal(body.dialogues[0].id, dialogueId);
  assert.equal(wordOf(body.dialogues[0], "rope").translation, "канат");
  assert.deepEqual(wordOf(body.dialogues[0], "grab").translation, "хапати");
});

test("a deleted row is no longer one of the dialogue's words", async () => {
  const { session, dialogueId, byWord } = await sessionWithDialogue();
  const deleted = await pagePost(`/s/${session.id}/rows/delete`, {
    rowId: byWord.rope,
    revs: { word: 0, translation: 0, definition: 0 },
  });
  assert.equal(deleted.status, 200);

  const { body } = await changes(session.id, 0);
  assert.equal(body.dialogues.length, 1);
  assert.equal(body.dialogues[0].id, dialogueId);
  assert.deepEqual(body.dialogues[0].words.map((w) => w.word), ["grab", "tide"]);
  assert.deepEqual(body.removedDialogues ?? [], []);
});

test("a word edited so it no longer appears drops out; one still appearing stays with its new places", async () => {
  const { session, byWord } = await sessionWithDialogue();
  // "ropes" is not in the text; "Tide" still is (matching ignores case).
  assert.equal((await editCell(session.id, byWord.rope, "word", "ropes", 0)).status, 200);
  assert.equal((await editCell(session.id, byWord.tide, "word", "Tide", 0)).status, 200);

  const { body } = await changes(session.id, 0);
  const [dialogue] = body.dialogues;
  assert.deepEqual(dialogue.words.map((w) => w.word), ["grab", "Tide"]);
  assert.deepEqual(wordOf(dialogue, "Tide").places, [[], [[24, 28]]]);
  assert.deepEqual(wordOf(dialogue, "grab").places, [[[3, 7]], []]);
});

test("a dialogue left with no words is sent as removed", async () => {
  const { session, dialogueId, byWord } = await sessionWithDialogue();
  await pagePost(`/s/${session.id}/rows/delete`, {
    rowId: byWord.grab,
    revs: { word: 0, translation: 0, definition: 0 },
  });
  assert.equal((await editCell(session.id, byWord.rope, "word", "string", 0)).status, 200);
  const last = await pagePost(`/s/${session.id}/rows/delete`, {
    rowId: byWord.tide,
    revs: { word: 0, translation: 0, definition: 0 },
  });
  assert.equal(last.status, 200);

  const { body } = await changes(session.id, 0);
  assert.deepEqual(body.removedDialogues, [dialogueId]);
  assert.equal("dialogues" in body, false);
  // A page already past those edits is not told again.
  assert.equal("removedDialogues" in (await changes(session.id, body.rev)).body, false);
});
