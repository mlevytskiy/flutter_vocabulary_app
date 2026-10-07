// mnemonic-story T1: the story allowance, story run and step tables (AC-10, AC-15,
// AC-19). Tested against the real migration in node:sqlite, no `wrangler dev`.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { sqliteD1 } from "./sqlite-d1.mjs";

const migrations = join(dirname(fileURLToPath(import.meta.url)), "..", "migrations");
const tables = (db) =>
  db.raw.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE '%story%' ORDER BY name").all().map((r) => r.name);

const insertRun = (db, id = "run-1") =>
  db.raw
    .prepare(
      "INSERT OR IGNORE INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model) VALUES (?, ?, ?, ?, ?, ?)",
    )
    .run(id, "2026-10-07T10:00:00.000Z", '["apple"]', "m-story", "m-prompt", "m-picture");

test("the migration creates the three tables", () => {
  assert.deepEqual(tables(sqliteD1()), ["all_story_runs", "story_run_steps", "story_runs"]);
});

test("a run inserted twice by run_id is one row (AC-10: a repeated start is free)", () => {
  const db = sqliteD1();
  insertRun(db);
  insertRun(db);
  assert.equal(db.raw.prepare("SELECT count(*) AS n FROM story_runs").get().n, 1);
  assert.throws(() =>
    db.raw
      .prepare("INSERT INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model) VALUES ('run-1','t','[]','a','b','c')")
      .run(),
  );
});

test("the day count starts at 0 by default and cannot go negative (AC-19)", () => {
  const db = sqliteD1();
  db.raw.prepare("INSERT INTO all_story_runs (utc_day) VALUES ('2026-10-07')").run();
  assert.equal(db.raw.prepare("SELECT used FROM all_story_runs").get().used, 0);
  assert.throws(() => db.raw.prepare("INSERT INTO all_story_runs (utc_day, used) VALUES ('2026-10-08', -1)").run());
  assert.throws(() => db.raw.prepare("INSERT INTO all_story_runs (utc_day) VALUES ('2026-10-07')").run());
});

test("steps are keyed by run, role and attempt; an index serves lookup by run (AC-15)", () => {
  const db = sqliteD1();
  insertRun(db);
  const step = (role, attempt, outcome = "done") =>
    db.raw
      .prepare(
        "INSERT INTO story_run_steps (run_id, role, attempt, model_id, outcome, started_at) VALUES ('run-1', ?, ?, 'm', ?, '2026-10-07T10:00:01.000Z')",
      )
      .run(role, attempt, outcome);
  step("story", 1);
  step("picture", 1, "failed");
  step("picture", 2);
  assert.throws(() => step("picture", 2));
  assert.throws(() => step("story", 2, "bogus"));
  assert.throws(() => step("bogus", 1));
  const row = db.raw.prepare("SELECT price_estimated, price_usd FROM story_run_steps WHERE role = 'story'").get();
  assert.equal(row.price_estimated, 0);
  assert.equal(row.price_usd, null);
  const plan = db.raw.prepare("EXPLAIN QUERY PLAN SELECT * FROM story_run_steps WHERE run_id = 'run-1'").all();
  assert.ok(plan.some((p) => /USING (COVERING )?INDEX|PRIMARY KEY/.test(p.detail)), JSON.stringify(plan));
  assert.throws(() =>
    db.raw.prepare("INSERT INTO story_run_steps (run_id, role, attempt, model_id, outcome, started_at) VALUES ('nope','story',1,'m','done','t')").run(),
  );
});

test("the down file drops all three tables and forgets the migration", () => {
  const db = sqliteD1();
  db.raw.exec("CREATE TABLE d1_migrations (name TEXT)");
  db.raw.exec("INSERT INTO d1_migrations VALUES ('0004_story_runs.sql')");
  db.raw.exec(readFileSync(join(migrations, "down", "0004_story_runs.sql"), "utf8"));
  assert.deepEqual(tables(db), []);
  assert.equal(db.raw.prepare("SELECT count(*) AS n FROM d1_migrations").get().n, 0);
});
