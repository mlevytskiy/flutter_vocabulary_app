// words-from-subtitles T2: the subtitle import allowance (ADR-0003,
// data-model.md). The take is tested directly against the real schema in
// node:sqlite; the daily clean-up through the running Worker's cron handler.
import { test } from "node:test";
import assert from "node:assert/strict";
import { sqliteD1 } from "./sqlite-d1.mjs";
import { d1, get, sql } from "./helpers.mjs";
import {
  SUBTITLE_WINDOW_LIMIT,
  SUBTITLE_DAY_LIMIT,
  hashAddress,
  windowStart,
  takeSubtitleImport,
} from "../src/subtitles/allowance.ts";

const at = new Date("2026-09-30T14:17:42.123Z");
const counts = (db) => ({
  windows: db.raw.prepare("SELECT ip_hash, window_start, used FROM subtitle_imports ORDER BY window_start").all(),
  days: db.raw.prepare("SELECT utc_day, used FROM all_subtitle_imports").all(),
});

test("the limits are the spec's: 10 per 10-minute window, 20 per UTC day", () => {
  assert.equal(SUBTITLE_WINDOW_LIMIT, 10);
  assert.equal(SUBTITLE_DAY_LIMIT, 20);
});

test("a window starts on the 10-minute boundary, in the stored ISO format", () => {
  assert.equal(windowStart(at), "2026-09-30T14:10:00.000Z");
  assert.equal(windowStart(new Date("2026-09-30T23:59:59.999Z")), "2026-09-30T23:50:00.000Z");
});

test("an address is stored as 64 hex characters of SHA-256, never itself", async () => {
  const hash = await hashAddress("203.0.113.7");
  assert.match(hash, /^[0-9a-f]{64}$/);
  assert.notEqual(hash, await hashAddress("203.0.113.8"));
  const db = { DB: sqliteD1() };
  await takeSubtitleImport(db, "203.0.113.7", at);
  const { windows } = counts(db.DB);
  assert.equal(windows[0].ip_hash, hash);
  assert.ok(!JSON.stringify(windows).includes("203.0.113.7"));
});

test("ten imports in one window are taken, the eleventh is refused and moves neither counter", async () => {
  const env = { DB: sqliteD1() };
  for (let i = 0; i < 10; i++) assert.deepEqual(await takeSubtitleImport(env, "203.0.113.1", at), { outcome: "taken" });
  assert.deepEqual(await takeSubtitleImport(env, "203.0.113.1", at), { outcome: "refused", reason: "window" });
  const { windows, days } = counts(env.DB);
  assert.equal(windows[0].used, 10);
  assert.deepEqual(days.map((d) => ({ ...d })), [{ utc_day: "2026-09-30", used: 10 }]);
  // The next window starts again.
  const later = new Date("2026-09-30T14:20:00.000Z");
  assert.deepEqual(await takeSubtitleImport(env, "203.0.113.1", later), { outcome: "taken" });
});

test("the twenty-first import of a UTC day is refused from any address, and its window stays at 0", async () => {
  const env = { DB: sqliteD1() };
  env.DB.raw.exec("INSERT INTO all_subtitle_imports (utc_day, used) VALUES ('2026-09-30', 20)");
  assert.deepEqual(await takeSubtitleImport(env, "203.0.113.99", at), { outcome: "refused", reason: "day" });
  const { windows, days } = counts(env.DB);
  assert.equal(windows[0].used, 0);
  assert.equal(days[0].used, 20);
  // A new UTC day starts again.
  assert.deepEqual(await takeSubtitleImport(env, "203.0.113.99", new Date("2026-10-01T00:00:01Z")), { outcome: "taken" });
});

test("the day total counts imports from every address", async () => {
  const env = { DB: sqliteD1() };
  for (let i = 0; i < 20; i++) {
    assert.equal((await takeSubtitleImport(env, `203.0.113.${i % 3}`, at)).outcome, "taken");
  }
  assert.deepEqual(await takeSubtitleImport(env, "203.0.113.200", at), { outcome: "refused", reason: "day" });
});

test("the daily clean-up deletes every finished window and keeps the current one and the day totals", async () => {
  const past = "0000000000000000000000000000000000000000000000000000000000000001";
  const current = "0000000000000000000000000000000000000000000000000000000000000002";
  d1(`INSERT OR REPLACE INTO subtitle_imports (ip_hash, window_start, used) VALUES
        (${sql(past)}, '2000-01-01T00:00:00.000Z', 3),
        (${sql(current)}, '9999-12-31T23:50:00.000Z', 1)`);
  d1(`INSERT OR REPLACE INTO all_subtitle_imports (utc_day, used) VALUES ('2000-01-01', 3)`);

  const run = await get(`/__scheduled?cron=${encodeURIComponent("0 3 * * *")}`);
  assert.equal(run.status, 200);

  const left = d1(`SELECT ip_hash FROM subtitle_imports WHERE ip_hash IN (${sql(past)}, ${sql(current)})`);
  assert.deepEqual(left.map((r) => r.ip_hash), [current]);
  assert.equal(d1(`SELECT used FROM all_subtitle_imports WHERE utc_day = '2000-01-01'`)[0].used, 3);
});
