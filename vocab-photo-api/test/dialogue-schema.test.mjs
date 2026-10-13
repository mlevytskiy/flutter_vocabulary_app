// get-words-from-subtitles-improvment T1: scene-run columns and the published-dialogue
// tables (AC-10, AC-14, AC-20). Tested against the real migration in node:sqlite.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";
import { sqliteD1 } from "./sqlite-d1.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const migrations = join(root, "migrations");
const staged = join(root, "..", "docs", "features", "get-words-from-subtitles-improvment", "migrations");
const NEW_TABLES = ["dialogue_imports", "dialogue_words", "dialogues"];
const dialogueTables = (db) =>
  db.raw.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE '%dialogue%' ORDER BY name").all().map((r) => r.name);
const count = (db, table) => db.raw.prepare(`SELECT count(*) AS n FROM ${table}`).get().n;

const seedSession = (db, id = "s1") => {
  db.raw.prepare("INSERT INTO sessions (id, created_at, expires_at) VALUES (?, 't', 't2')").run(id);
  db.raw.prepare("INSERT INTO rows (session_id, id, position) VALUES (?, 'r1', 0)").run(id);
  db.raw.prepare("INSERT INTO dialogues (session_id, id, position, lines_json, import_id, added_rev) VALUES (?, 'd1', 0, '[]', 'imp1', 1)").run(id);
  db.raw.prepare("INSERT INTO dialogue_words (session_id, dialogue_id, row_id) VALUES (?, 'd1', 'r1')").run(id);
  db.raw.prepare("INSERT INTO dialogue_imports (session_id, import_id) VALUES (?, 'imp1')").run(id);
};

test("the migration creates the three dialogue tables", () => {
  assert.deepEqual(dialogueTables(sqliteD1()), NEW_TABLES);
});

test("the staged pair is identical to the promoted pair", () => {
  assert.ok(existsSync(join(staged, "01_film_dialogues.up.sql")));
  assert.equal(readFileSync(join(staged, "01_film_dialogues.up.sql"), "utf8"), readFileSync(join(migrations, "0005_film_dialogues.sql"), "utf8"));
  assert.equal(
    readFileSync(join(staged, "01_film_dialogues.down.sql"), "utf8"),
    readFileSync(join(migrations, "down", "0005_film_dialogues.sql"), "utf8"),
  );
});

test("a story run keeps kind 'story' by default and scene_text null; scene runs are allowed (AC-10)", () => {
  const db = sqliteD1();
  const ins = db.raw.prepare("INSERT INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model) VALUES (?, 't', '[]', ?, 'p', 'pic')");
  ins.run("old", "m-story");
  const row = db.raw.prepare("SELECT kind, scene_text FROM story_runs WHERE run_id = 'old'").get();
  assert.equal(row.kind, "story");
  assert.equal(row.scene_text, null);
  db.raw.prepare("INSERT INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model, kind, scene_text) VALUES ('sc','t','[]','','p','pic','scene','A: hi')").run();
  assert.equal(db.raw.prepare("SELECT scene_text FROM story_runs WHERE run_id = 'sc'").get().scene_text, "A: hi");
  assert.throws(() =>
    db.raw.prepare("INSERT INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model, kind) VALUES ('bad','t','[]','','p','pic','bogus')").run(),
  );
});

test("a dialogue is keyed by session and id; its words and import ids are unique per session (AC-20)", () => {
  const db = sqliteD1();
  seedSession(db);
  assert.throws(() => db.raw.prepare("INSERT INTO dialogues (session_id, id, position, lines_json, import_id, added_rev) VALUES ('s1','d1',1,'[]','imp1',2)").run());
  assert.throws(() => db.raw.prepare("INSERT INTO dialogue_words (session_id, dialogue_id, row_id) VALUES ('s1','d1','r1')").run());
  assert.throws(() => db.raw.prepare("INSERT INTO dialogue_imports (session_id, import_id) VALUES ('s1','imp1')").run());
  assert.throws(() => db.raw.prepare("INSERT INTO dialogues (session_id, id, position, lines_json, import_id, added_rev) VALUES ('nope','d9',0,'[]','i',1)").run());
  const d = db.raw.prepare("SELECT picture_media_type, picture_bytes, picture_arrived_rev FROM dialogues").get();
  assert.deepEqual({ ...d }, { picture_media_type: null, picture_bytes: null, picture_arrived_rev: null });
});

test("the change feed query for dialogues uses the (session_id, added_rev) index (AC-20)", () => {
  const db = sqliteD1();
  const plan = db.raw.prepare("EXPLAIN QUERY PLAN SELECT * FROM dialogues WHERE session_id = 's1' AND added_rev > 3").all();
  assert.ok(plan.some((p) => /USING INDEX dialogues_added_idx/.test(p.detail)), JSON.stringify(plan));
});

test("deleting a session removes its dialogues, dialogue words and import ids (AC-14)", () => {
  const db = sqliteD1();
  seedSession(db, "s1");
  seedSession(db, "s2");
  db.raw.prepare("DELETE FROM sessions WHERE id = 's1'").run();
  for (const t of NEW_TABLES) assert.equal(count(db, t), 1, t);
  assert.equal(db.raw.prepare("SELECT session_id FROM dialogues").get().session_id, "s2");
});

test("deleting a dialogue removes its words", () => {
  const db = sqliteD1();
  seedSession(db);
  db.raw.prepare("DELETE FROM dialogues WHERE session_id = 's1' AND id = 'd1'").run();
  assert.equal(count(db, "dialogue_words"), 0);
  assert.equal(count(db, "dialogue_imports"), 1);
});

test("the down file drops the tables and columns, and forgets the migration", () => {
  const db = sqliteD1();
  db.raw.exec("CREATE TABLE d1_migrations (name TEXT)");
  db.raw.exec("INSERT INTO d1_migrations VALUES ('0005_film_dialogues.sql'), ('0004_story_runs.sql')");
  db.raw.exec(readFileSync(join(migrations, "down", "0005_film_dialogues.sql"), "utf8"));
  assert.deepEqual(dialogueTables(db), []);
  const cols = db.raw.prepare("PRAGMA table_info(story_runs)").all().map((c) => c.name);
  assert.ok(!cols.includes("kind") && !cols.includes("scene_text"), cols.join());
  assert.deepEqual(db.raw.prepare("SELECT name FROM d1_migrations").all().map((r) => r.name), ["0004_story_runs.sql"]);
});
