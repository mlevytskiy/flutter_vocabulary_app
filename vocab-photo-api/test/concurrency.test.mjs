import assert from "node:assert/strict";
import { test } from "node:test";
import { baseUrl, pagePost, publish, storedRows } from "./helpers.mjs";

// sad §10 QG-1: lost edits under concurrent editing = 0. Every save either
// lands or comes back as a conflict that names the value saved meanwhile.

const save = (id, body) => pagePost(`/s/${id}/cells`, body);
const sleep = (ms) => new Promise((ok) => setTimeout(ok, Math.max(0, ms)));

async function changes(id, since) {
  const res = await fetch(`${baseUrl}/s/${id}/changes?since=${since}`);
  return { status: res.status, body: await res.json() };
}

const CLIENTS = 3;
const EDITS_PER_CLIENT = 100;

/**
 * One partner's page: `edits` saves, one at a time as the page sends them,
 * each from the revision this client last saw for that cell. A conflict is
 * resolved the way AC-11 lets a partner resolve it -- keep theirs -- by saving
 * again from the revision the conflict named, until it lands. Returns the log
 * of every answer.
 */
async function client(name, sessionId, cells) {
  const seen = new Map(cells.map((cell) => [cell.key, 0]));
  const log = [];
  for (let i = 0; i < EDITS_PER_CLIENT; i += 1) {
    const cell = cells[i % cells.length];
    const value = `${name}-${i}`;
    for (let attempt = 0; ; attempt += 1) {
      assert.ok(attempt < 50, `${value} did not land after 50 conflicts`);
      const baseRev = seen.get(cell.key);
      const res = await save(sessionId, { rowId: cell.rowId, field: cell.field, value, baseRev });
      log.push({ client: name, cell: cell.key, value, baseRev, status: res.status, body: res.body });
      if (res.status === 200) {
        seen.set(cell.key, res.body.rev);
        break;
      }
      assert.equal(res.status, 409, `unexpected answer ${res.status} ${JSON.stringify(res.body)}`);
      assert.equal(res.body.code, "conflict");
      seen.set(cell.key, res.body.rev);
    }
  }
  return log;
}

test("3 clients × 100 edits on shared and own cells: every edit lands or is a conflict, none is lost", { timeout: 180_000 }, async () => {
  const { id } = await publish({
    entries: [
      { word: "shared", translation: "спільне" },
      { word: "a", translation: "а" },
      { word: "b", translation: "б" },
      { word: "c", translation: "в" },
    ],
  });
  const [shared, ...own] = storedRows(id);
  const cell = (row, field) => ({ key: `${row.id}/${field}`, rowId: row.id, field });
  // Every client edits the same two cells of the first row and a cell of its own row.
  const common = [cell(shared, "translation"), cell(shared, "definition")];
  const names = ["A", "B", "C"].slice(0, CLIENTS);
  const logs = await Promise.all(
    names.map((name, n) => client(name, id, [common[0], cell(own[n], "translation"), common[1]]))
  );
  const all = logs.flat();

  const landed = all.filter((entry) => entry.status === 200);
  const conflicts = all.filter((entry) => entry.status === 409);
  assert.equal(landed.length, CLIENTS * EDITS_PER_CLIENT, "every edit lands once");
  assert.ok(conflicts.length > 0, "the shared cells produced no conflict; the test is not concurrent");

  // Each landed save has its own revision, and the session revision counts them all.
  const revs = landed.map((entry) => entry.body.rev);
  assert.equal(new Set(revs).size, revs.length, "two saves share a revision");
  const feed = await changes(id, 0);
  assert.equal(feed.status, 200);
  assert.equal(feed.body.rev, landed.length);

  // Per cell, the landed saves form one chain: each started from the revision of
  // the save before it. A save that overwrote a value it never saw would break
  // the chain -- that is a lost edit.
  const byCell = Object.groupBy(landed, (entry) => entry.cell);
  for (const [key, chain] of Object.entries(byCell)) {
    chain.sort((a, b) => a.body.rev - b.body.rev);
    chain.forEach((entry, i) => {
      assert.equal(entry.baseRev, i === 0 ? 0 : chain[i - 1].body.rev, `${key}: ${entry.value} overwrote an unseen edit`);
    });
  }

  // Every conflict named a value that really was saved, at the revision it was saved at.
  const savedAt = new Map(landed.map((entry) => [`${entry.cell}@${entry.body.rev}`, entry.value]));
  for (const entry of conflicts) {
    assert.equal(savedAt.get(`${entry.cell}@${entry.body.rev}`), entry.body.value, `${entry.value}: conflict named a phantom value`);
  }

  // Cells only one client edits never conflict (AC-12: different cells both land).
  for (const key of own.map((row) => `${row.id}/translation`)) {
    assert.equal(conflicts.filter((entry) => entry.cell === key).length, 0);
  }

  // What D1 holds, and what the change feed hands a page, is the last save of each cell.
  const stored = new Map(storedRows(id).map((row) => [row.id, row]));
  const fed = new Map(feed.body.cells.map((c) => [`${c.rowId}/${c.field}`, c]));
  for (const [key, chain] of Object.entries(byCell)) {
    const last = chain.at(-1);
    const [rowId, field] = key.split("/");
    assert.equal(stored.get(rowId)[field], last.value);
    assert.equal(stored.get(rowId)[`${field}_rev`], last.body.rev);
    assert.deepEqual(fed.get(key), { rowId, field, value: last.value, rev: last.body.rev });
  }
  // The row words nobody edited are untouched.
  assert.equal(stored.get(shared.id).word, "shared");

  console.log(`# concurrency: ${landed.length} landed, ${conflicts.length} conflicts resolved, 0 lost`);
});

// spec §6: another partner's saved edit appears on an open page ≤ 10 s. The
// page polls the change feed every 5 s (POLL_MS in src/session/client/page.js);
// here a writer saves 20 edits and a reader polls at that pace.
test("20 edits from one partner reach a polling partner within 10 s each", { timeout: 120_000 }, async () => {
  const POLL_MS = 5000;
  const EDITS = 20;
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
    ],
  });
  const rows = storedRows(id);
  const savedAt = new Map();
  const polls = [];
  let writing = true;

  const writer = (async () => {
    const revs = new Map();
    for (let i = 0; i < EDITS; i += 1) {
      const row = rows[i % rows.length];
      const value = `edit-${i}`;
      const res = await save(id, { rowId: row.id, field: "translation", value, baseRev: revs.get(row.id) ?? 0 });
      assert.equal(res.status, 200);
      revs.set(row.id, res.body.rev);
      savedAt.set(res.body.rev, Date.now());
      await sleep(700);
    }
    writing = false;
  })();

  const reader = (async () => {
    let since = 0;
    // Keep polling until one poll after the last edit.
    for (let last = false; !last; ) {
      last = !writing;
      const feed = await changes(id, since);
      assert.equal(feed.status, 200);
      polls.push({ at: Date.now(), rev: feed.body.rev });
      since = feed.body.rev;
      if (!last) await sleep(POLL_MS);
    }
  })();

  await Promise.all([writer, reader]);
  // An edit is on the reader's page from the first poll whose revision covers
  // it (a cell saved twice between polls arrives once, as its newer value).
  // A poll that read the new revision can answer a moment before the writer's own answer: 0 ms.
  const delays = [...savedAt].map(([rev, at]) => Math.max(0, (polls.find((poll) => poll.rev >= rev)?.at ?? NaN) - at));
  assert.equal(delays.length, EDITS);
  assert.ok(delays.every(Number.isFinite), "an edit never reached the reader");
  const max = Math.max(...delays);
  const sorted = [...delays].sort((a, b) => a - b);
  const p95 = sorted[Math.ceil(0.95 * sorted.length) - 1];
  console.log(`# propagation over ${EDITS} edits: p95 ${p95} ms, max ${max} ms`);
  assert.ok(max <= 10_000, `an edit took ${max} ms to appear`);
});
