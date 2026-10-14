// learn-kit: the two exercise allowances (spec AC-21, AC-24, AC-27, AC-34b, AC-34c; S-18, S-19).
// The take runs against the real schema in node:sqlite; the routes against the local Worker, whose
// day rows are seeded through d1() and put back afterwards.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { sqliteD1 } from "./sqlite-d1.mjs";
import { appHeaders, baseUrl, d1 } from "./helpers.mjs";
import { LEARN_CHECK_DAY_LIMIT, LEARN_DATA_DAY_LIMIT, takeLearnCheck, takeLearnData } from "../src/learn/allowance.ts";

const at = new Date("2026-10-14T23:59:59.000Z");
const used = (db, table) => db.raw.prepare(`SELECT utc_day, used FROM ${table} ORDER BY utc_day`).all().map((r) => ({ ...r }));

test("S-18: the limits are 200 data calls and 500 checks a UTC day", () => {
  assert.equal(LEARN_DATA_DAY_LIMIT, 200);
  assert.equal(LEARN_CHECK_DAY_LIMIT, 500);
});

test("S-18: each take uses one unit of its own UTC day, up to the limit and no further", async () => {
  const db = sqliteD1();
  const env = { DB: db };
  assert.equal(await takeLearnData(env, at), true);
  assert.equal(await takeLearnCheck(env, at), true);
  assert.deepEqual(used(db, "all_learn_data"), [{ utc_day: "2026-10-14", used: 1 }]);
  assert.deepEqual(used(db, "all_learn_checks"), [{ utc_day: "2026-10-14", used: 1 }]);
  assert.deepEqual(used(db, "all_story_runs"), [], "the story allowance is not touched");

  db.raw.prepare("UPDATE all_learn_data SET used = 199").run();
  assert.equal(await takeLearnData(env, at), true);
  assert.equal(await takeLearnData(env, at), false);
  assert.deepEqual(used(db, "all_learn_data"), [{ utc_day: "2026-10-14", used: 200 }]);

  db.raw.prepare("UPDATE all_learn_checks SET used = 500").run();
  assert.equal(await takeLearnCheck(env, at), false);
  // A new UTC day starts at zero.
  assert.equal(await takeLearnCheck(env, new Date("2026-10-15T00:00:00.000Z")), true);
  assert.deepEqual(used(db, "all_learn_checks"), [{ utc_day: "2026-10-14", used: 500 }, { utc_day: "2026-10-15", used: 1 }]);
});

test("0006 reverts cleanly with its down file and forgets itself", () => {
  const db = sqliteD1();
  const migrations = new URL("../migrations/", import.meta.url);
  db.raw.exec("CREATE TABLE d1_migrations (name TEXT)");
  db.raw.exec("INSERT INTO d1_migrations VALUES ('0005_film_dialogues.sql'), ('0006_learn_allowance.sql')");
  db.raw.exec(readFileSync(new URL("down/0006_learn_allowance.sql", migrations), "utf8"));
  const tables = db.raw.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'all_learn%'").all();
  assert.deepEqual(tables, []);
  assert.deepEqual(db.raw.prepare("SELECT name FROM d1_migrations").all().map((r) => r.name), ["0005_film_dialogues.sql"]);
  assert.ok(db.raw.prepare("SELECT 1 FROM sqlite_master WHERE name = 'all_story_runs'").get(), "the story allowance stays");
});

// ---- the routes ----

const today = () => new Date().toISOString().slice(0, 10);
const dayUsed = (table) => d1(`SELECT used FROM ${table} WHERE utc_day = '${today()}'`)[0]?.used ?? 0;
const setUsed = (table, n) => d1(`INSERT INTO ${table} (utc_day, used) VALUES ('${today()}', ${n}) ON CONFLICT (utc_day) DO UPDATE SET used = ${n}`);
const json = (headers = appHeaders()) => ({ ...headers, "content-type": "application/json" });
const post = (path, body, headers = json()) => fetch(`${baseUrl}${path}`, { method: "POST", headers, body: JSON.stringify(body) });
const words = (n) => {
  const tag = randomUUID().slice(0, 8);
  return Array.from({ length: n }, (_, i) => ({ rowId: `r${i}`, word: `allow${tag}x${i}`, translation: tag }));
};
const check = (sentence = "I walk home today.") => ({ word: "walk", translation: "гуляти", sentence, task: "own" });

test("AC-24, AC-27: a data request with misses takes one unit; a fully cached one takes none", async () => {
  const group = words(5);
  const before = dayUsed("all_learn_data");
  assert.equal((await post("/learn/data", { kind: "synonym", words: group })).status, 200);
  assert.equal(dayUsed("all_learn_data"), before + 1, "one unit for one AI call, whatever the word count");
  assert.equal((await post("/learn/data", { kind: "synonym", words: group })).status, 200);
  assert.equal(dayUsed("all_learn_data"), before + 1, "all hits take nothing");
  // A failed AI call keeps its unit (AC-24).
  assert.equal((await post("/learn/data", { kind: "synonym", words: [{ rowId: "e", word: "STUB:error", translation: randomUUID() }] })).status, 502);
  assert.equal(dayUsed("all_learn_data"), before + 2);
  // A bad request takes nothing (AC-23).
  assert.equal((await post("/learn/data", { kind: "antonym", words: words(2) })).status, 400);
  assert.equal(dayUsed("all_learn_data"), before + 2);
});

test("AC-27: with the day used up a miss is refused 429 day_limit, a cached request is still served", async () => {
  const cachedGroup = words(3);
  await post("/learn/data", { kind: "definition", words: cachedGroup });
  const keep = dayUsed("all_learn_data");
  const story = d1(`SELECT used FROM all_story_runs WHERE utc_day = '${today()}'`);
  setUsed("all_learn_data", 200);
  try {
    const res = await post("/learn/data", { kind: "definition", words: words(3) });
    assert.equal(res.status, 429);
    assert.equal((await res.json()).code, "day_limit");
    assert.equal((await post("/learn/data", { kind: "definition", words: cachedGroup })).status, 200);
    assert.equal(dayUsed("all_learn_data"), 200);
    assert.deepEqual(d1(`SELECT used FROM all_story_runs WHERE utc_day = '${today()}'`), story, "the story allowance is not touched");
  } finally {
    setUsed("all_learn_data", keep);
  }
});

test("AC-34b: each check takes one unit; with the day used up it is refused 429 day_limit", async () => {
  const keep = dayUsed("all_learn_checks");
  assert.equal((await post("/learn/check", check())).status, 200);
  assert.equal((await post("/learn/check", check())).status, 200);
  assert.equal(dayUsed("all_learn_checks"), keep + 2, "the same sentence counts again");
  // A failed check keeps its unit; a bad request takes none.
  assert.equal((await post("/learn/check", check("STUB:error I walk."))).status, 502);
  assert.equal((await post("/learn/check", check("Walk"))).status, 400);
  assert.equal(dayUsed("all_learn_checks"), keep + 3);
  setUsed("all_learn_checks", 500);
  try {
    const res = await post("/learn/check", check());
    assert.equal(res.status, 429);
    assert.equal((await res.json()).code, "day_limit");
  } finally {
    setUsed("all_learn_checks", keep + 3);
  }
});

test("AC-34c: the per-device limit every app service shares refuses with a plain 429 and takes no unit", async () => {
  const headers = json(appHeaders({ "cf-connecting-ip": `198.51.100.${Math.floor(Math.random() * 250) + 1}` }));
  const keep = { data: dayUsed("all_learn_data"), checks: dayUsed("all_learn_checks") };
  // 20 requests a minute from one address; bad requests spend nothing else.
  for (let i = 0; i < 20; i += 1) assert.equal((await post("/learn/check", check("Walk"), headers)).status, 400);
  const data = await post("/learn/data", { kind: "synonym", words: words(2) }, headers);
  assert.equal(data.status, 429);
  assert.equal((await data.json()).code, undefined, "no code: the app shows the rate-limit line");
  assert.equal((await post("/learn/check", check(), headers)).status, 429);
  assert.deepEqual({ data: dayUsed("all_learn_data"), checks: dayUsed("all_learn_checks") }, keep);
});
