// collections-screen T21: the nullable `sessions.title` column (ADR-0008, AC-29).
// Tested against the real migration in node:sqlite.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { sqliteD1 } from "./sqlite-d1.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const migrations = join(root, "migrations");
const staged = join(root, "..", "docs", "features", "collections-screen", "migrations");
const columns = (db) => db.raw.prepare("PRAGMA table_info(sessions)").all().map((c) => c.name);

test("the promoted pair is the staged pair with <next> filled in as 0007", () => {
  const up = join(migrations, "0007_session_title.sql");
  const down = join(migrations, "down", "0007_session_title.sql");
  assert.ok(existsSync(up), "migrations/0007_session_title.sql is missing");
  assert.ok(existsSync(down), "migrations/down/0007_session_title.sql is missing");
  const fill = (f) => readFileSync(join(staged, f), "utf8").replaceAll("<next>", "0007");
  assert.equal(readFileSync(up, "utf8"), fill("01_add_session_title.up.sql"));
  assert.equal(readFileSync(down, "utf8"), fill("01_add_session_title.down.sql"));
  assert.ok(!readFileSync(down, "utf8").includes("<next>"));
});

test("sessions.title is a nullable TEXT column; a session without it stays NULL (AC-29)", () => {
  const db = sqliteD1();
  const col = db.raw.prepare("PRAGMA table_info(sessions)").all().find((c) => c.name === "title");
  assert.ok(col, "sessions.title is missing");
  assert.equal(col.type, "TEXT");
  assert.equal(col.notnull, 0);
  db.raw.prepare("INSERT INTO sessions (id, created_at, expires_at) VALUES ('old', 't', 't2')").run();
  assert.equal(db.raw.prepare("SELECT title FROM sessions WHERE id = 'old'").get().title, null);
  db.raw.prepare("INSERT INTO sessions (id, created_at, expires_at, title) VALUES ('new', 't', 't2', 'Speaking club 12')").run();
  assert.equal(db.raw.prepare("SELECT title FROM sessions WHERE id = 'new'").get().title, "Speaking club 12");
});

test("the down file drops the column and forgets the migration", () => {
  const db = sqliteD1();
  db.raw.exec("CREATE TABLE d1_migrations (name TEXT)");
  db.raw.exec("INSERT INTO d1_migrations VALUES ('0006_learn_allowance.sql'), ('0007_session_title.sql')");
  db.raw.exec(readFileSync(join(migrations, "down", "0007_session_title.sql"), "utf8"));
  assert.ok(!columns(db).includes("title"), columns(db).join());
  assert.deepEqual(db.raw.prepare("SELECT name FROM d1_migrations").all().map((r) => r.name), ["0006_learn_allowance.sql"]);
});
