// mnemonic-story T6: the story allowance take and the run store (AC-10, AC-15, AC-19).
// Tested directly against the real schema in node:sqlite and a small in-memory R2.
import { test } from "node:test";
import assert from "node:assert/strict";
import { sqliteD1 } from "./sqlite-d1.mjs";
import { STORY_DAY_LIMIT, takeStoryRun, takeDrawAgain } from "../src/story/allowance.ts";
import {
  PICTURE_MAX_AGE_DAYS,
  createRun,
  recordStep,
  runStatus,
  findCountedRun,
  putPicture,
  getPicture,
  deletePicture,
  deleteOldPictures,
} from "../src/story/store.ts";

const at = new Date("2026-10-07T14:17:42.123Z");
const run = (id, extra = {}) => ({
  runId: id,
  words: ["apple", "pear"],
  storyModel: "m-story",
  promptModel: "m-prompt",
  pictureModel: "m-picture",
  ...extra,
});
const days = (db) => db.raw.prepare("SELECT utc_day, used FROM all_story_runs ORDER BY utc_day").all().map((r) => ({ ...r }));
const count = (db, table) => db.raw.prepare(`SELECT count(*) AS n FROM ${table}`).get().n;

/** An in-memory R2 bucket: put, get, delete, list with a cursor, and a settable upload time. */
function fakeR2() {
  const objects = new Map();
  return {
    objects,
    async put(key, value, options) {
      objects.set(key, { value, uploaded: new Date(), contentType: options?.httpMetadata?.contentType });
    },
    async get(key) {
      const o = objects.get(key);
      if (!o) return null;
      return { key, httpMetadata: { contentType: o.contentType }, uploaded: o.uploaded, arrayBuffer: async () => o.value };
    },
    async delete(keys) {
      for (const k of Array.isArray(keys) ? keys : [keys]) objects.delete(k);
    },
    async list({ prefix = "", cursor, limit = 1000 } = {}) {
      const all = [...objects.entries()].filter(([k]) => k.startsWith(prefix)).sort(([a], [b]) => (a < b ? -1 : 1));
      const start = cursor ? Number(cursor) : 0;
      const page = all.slice(start, start + limit);
      const more = start + limit < all.length;
      return {
        objects: page.map(([key, o]) => ({ key, uploaded: o.uploaded })),
        truncated: more,
        cursor: more ? String(start + limit) : undefined,
      };
    },
  };
}

test("the limit is the spec's: 20 story runs per UTC day", () => {
  assert.equal(STORY_DAY_LIMIT, 20);
  assert.equal(PICTURE_MAX_AGE_DAYS, 7);
});

test("20 starts of one UTC day are taken and the 21st is refused with nothing recorded (AC-19)", async () => {
  const env = { DB: sqliteD1() };
  for (let i = 0; i < 20; i++) assert.deepEqual(await takeStoryRun(env, run(`r${i}`), at), { outcome: "taken" });
  assert.deepEqual(await takeStoryRun(env, run("r20"), at), { outcome: "refused", reason: "day" });
  assert.deepEqual(days(env.DB), [{ utc_day: "2026-10-07", used: 20 }]);
  assert.equal(count(env.DB, "story_runs"), 20);
  assert.equal(await findCountedRun(env, "r20"), null);
});

test("a repeated run id takes nothing, even with the day used up (AC-10)", async () => {
  const env = { DB: sqliteD1() };
  assert.deepEqual(await takeStoryRun(env, run("same"), at), { outcome: "taken" });
  assert.deepEqual(await takeStoryRun(env, run("same"), at), { outcome: "existing" });
  assert.deepEqual(days(env.DB), [{ utc_day: "2026-10-07", used: 1 }]);
  env.DB.raw.exec("UPDATE all_story_runs SET used = 20");
  assert.deepEqual(await takeStoryRun(env, run("same"), at), { outcome: "existing" });
  assert.equal(count(env.DB, "story_runs"), 1);
});

test("two takes for the last unit: exactly one succeeds", async () => {
  const env = { DB: sqliteD1() };
  env.DB.raw.exec("INSERT INTO all_story_runs (utc_day, used) VALUES ('2026-10-07', 19)");
  const results = await Promise.all([takeStoryRun(env, run("a"), at), takeStoryRun(env, run("b"), at)]);
  assert.deepEqual(results.map((r) => r.outcome).sort(), ["refused", "taken"]);
  assert.deepEqual(days(env.DB), [{ utc_day: "2026-10-07", used: 20 }]);
  assert.equal(count(env.DB, "story_runs"), 1);
});

test("a new UTC day resets the count", async () => {
  const env = { DB: sqliteD1() };
  env.DB.raw.exec("INSERT INTO all_story_runs (utc_day, used) VALUES ('2026-10-07', 20)");
  assert.equal((await takeStoryRun(env, run("x"), at)).outcome, "refused");
  const next = new Date("2026-10-08T00:00:01Z");
  assert.deepEqual(await takeStoryRun(env, run("x"), next), { outcome: "taken" });
  assert.deepEqual(days(env.DB), [
    { utc_day: "2026-10-07", used: 20 },
    { utc_day: "2026-10-08", used: 1 },
  ]);
});

test("a Draw again takes one unit and records its running step; the same attempt again takes nothing (AC-19)", async () => {
  const env = { DB: sqliteD1() };
  await takeStoryRun(env, run("r"), at);
  assert.deepEqual(await takeDrawAgain(env, "r", 2, at), { outcome: "taken" });
  assert.deepEqual(days(env.DB), [{ utc_day: "2026-10-07", used: 2 }]);
  const step = env.DB.raw.prepare("SELECT role, attempt, outcome, model_id FROM story_run_steps").get();
  assert.deepEqual({ ...step }, { role: "picture", attempt: 2, outcome: "running", model_id: "m-picture" });
  assert.deepEqual(await takeDrawAgain(env, "r", 2, at), { outcome: "existing" });
  assert.deepEqual(await takeDrawAgain(env, "r", 3, at), { outcome: "taken" });
  assert.equal(days(env.DB)[0].used, 3);
});

test("a Draw again for an unknown run is refused and takes nothing", async () => {
  const env = { DB: sqliteD1() };
  assert.deepEqual(await takeDrawAgain(env, "ghost", 2, at), { outcome: "refused", reason: "unknown_run" });
  assert.deepEqual(days(env.DB), []);
});

test("a Draw again on a used-up day is refused with no step recorded; the last unit goes to one of two", async () => {
  const env = { DB: sqliteD1() };
  await takeStoryRun(env, run("r"), at);
  env.DB.raw.exec("UPDATE all_story_runs SET used = 19");
  const results = await Promise.all([takeDrawAgain(env, "r", 2, at), takeDrawAgain(env, "r", 3, at)]);
  assert.deepEqual(results.map((r) => r.outcome).sort(), ["refused", "taken"]);
  assert.equal(count(env.DB, "story_run_steps"), 1);
  assert.equal(days(env.DB)[0].used, 20);
});

test("createRun inserts a run once and says whether it was new; findCountedRun reads it back", async () => {
  const env = { DB: sqliteD1() };
  assert.equal(await findCountedRun(env, "r"), null);
  assert.equal(await createRun(env, run("r"), at), true);
  assert.equal(await createRun(env, run("r", { words: ["other"] }), at), false);
  assert.deepEqual(await findCountedRun(env, "r"), {
    runId: "r",
    createdAt: "2026-10-07T14:17:42.123Z",
    words: ["apple", "pear"],
    storyModel: "m-story",
    promptModel: "m-prompt",
    pictureModel: "m-picture",
  });
  assert.deepEqual(days(env.DB), [], "createRun takes no allowance");
});

test("recordStep writes a running step, then the same attempt's result; runStatus returns runs with steps", async () => {
  const env = { DB: sqliteD1() };
  await takeStoryRun(env, run("r1"), at);
  await takeStoryRun(env, run("r2"), at);
  await recordStep(env, { runId: "r1", role: "story", attempt: 1, modelId: "m-story", outcome: "running", startedAt: "2026-10-07T14:18:00.000Z" });
  await recordStep(env, {
    runId: "r1",
    role: "story",
    attempt: 1,
    modelId: "m-story",
    outcome: "done",
    text: "A story.",
    missedWords: ["pear"],
    priceUsd: 0.002,
    priceEstimated: true,
    ms: 1234,
    startedAt: "2026-10-07T14:18:00.000Z",
    finishedAt: "2026-10-07T14:18:01.234Z",
  });
  await recordStep(env, {
    runId: "r1",
    role: "picture",
    attempt: 1,
    modelId: "m-picture",
    outcome: "failed",
    startedAt: "2026-10-07T14:18:02.000Z",
    finishedAt: "2026-10-07T14:18:03.000Z",
  });
  assert.equal(count(env.DB, "story_run_steps"), 2);

  const status = await runStatus(env, ["r1", "r2", "unknown"]);
  assert.deepEqual(status.map((s) => s.runId).sort(), ["r1", "r2"]);
  const r1 = status.find((s) => s.runId === "r1");
  assert.deepEqual(r1.words, ["apple", "pear"]);
  assert.equal(r1.steps.length, 2);
  assert.deepEqual(r1.steps[0], {
    role: "story",
    attempt: 1,
    modelId: "m-story",
    outcome: "done",
    text: "A story.",
    missedWords: ["pear"],
    pictureKey: null,
    priceUsd: 0.002,
    priceEstimated: true,
    ms: 1234,
    startedAt: "2026-10-07T14:18:00.000Z",
    finishedAt: "2026-10-07T14:18:01.234Z",
  });
  assert.equal(r1.steps[1].outcome, "failed");
  assert.equal(r1.steps[1].priceUsd, null);
  assert.equal(r1.steps[1].priceEstimated, false);
  assert.deepEqual(status.find((s) => s.runId === "r2").steps, []);
  assert.deepEqual(await runStatus(env, []), []);
});

test("runStatus copes with more run ids than one query can bind", async () => {
  const env = { DB: sqliteD1() };
  const ids = Array.from({ length: 230 }, (_, i) => `r${i}`);
  for (const id of ids) await createRun(env, run(id), at);
  assert.equal((await runStatus(env, ids)).length, 230);
});

test("pictures round-trip through R2 under story-runs/<runId>/<attempt> and can be deleted", async () => {
  const env = { DB: sqliteD1(), SOURCES: fakeR2() };
  const bytes = new Uint8Array([1, 2, 3, 4]).buffer;
  const key = await putPicture(env, "r1", 2, bytes, "image/png");
  assert.equal(key, "story-runs/r1/2");
  assert.ok(env.SOURCES.objects.has("story-runs/r1/2"));
  const got = await getPicture(env, "r1", 2);
  assert.equal(got.contentType, "image/png");
  assert.deepEqual([...new Uint8Array(got.bytes)], [1, 2, 3, 4]);
  assert.equal(await getPicture(env, "r1", 1), null);

  await createRun(env, run("r1"), at);
  await recordStep(env, { runId: "r1", role: "picture", attempt: 2, modelId: "m", outcome: "done", pictureKey: key, startedAt: "t" });
  await deletePicture(env, "r1", 2);
  assert.equal(await getPicture(env, "r1", 2), null);
  const [step] = (await runStatus(env, ["r1"]))[0].steps;
  assert.equal(step.pictureKey, null, "the step row stays, without its key");
});

test("the picture store throws when R2 is not configured", async () => {
  const env = { DB: sqliteD1() };
  await assert.rejects(putPicture(env, "r", 1, new ArrayBuffer(1), "image/png"));
  assert.equal(await getPicture(env, "r", 1), null);
  assert.equal(await deleteOldPictures(env, at), 0);
});

test("deleteOldPictures removes only pictures older than 7 days, keeps every row, and ignores other keys", async () => {
  const env = { DB: sqliteD1(), SOURCES: fakeR2() };
  await createRun(env, run("r1"), at);
  const day = 24 * 60 * 60 * 1000;
  for (const attempt of [1, 2, 3]) {
    const key = await putPicture(env, "r1", attempt, new ArrayBuffer(2), "image/png");
    await recordStep(env, { runId: "r1", role: "picture", attempt, modelId: "m", outcome: "done", pictureKey: key, startedAt: "t" });
  }
  await env.SOURCES.put("sessions/other", new ArrayBuffer(1));
  env.SOURCES.objects.get("sessions/other").uploaded = new Date(at.getTime() - 30 * day);
  env.SOURCES.objects.get("story-runs/r1/1").uploaded = new Date(at.getTime() - 8 * day);
  env.SOURCES.objects.get("story-runs/r1/2").uploaded = new Date(at.getTime() - 7 * day + 1000);
  env.SOURCES.objects.get("story-runs/r1/3").uploaded = new Date(at.getTime() - 1 * day);

  assert.equal(await deleteOldPictures(env, at), 1);
  assert.deepEqual([...env.SOURCES.objects.keys()].sort(), ["sessions/other", "story-runs/r1/2", "story-runs/r1/3"]);
  assert.equal(count(env.DB, "story_runs"), 1);
  assert.equal(count(env.DB, "story_run_steps"), 3);
  const keys = (await runStatus(env, ["r1"]))[0].steps.map((s) => s.pictureKey);
  assert.deepEqual(keys, [null, "story-runs/r1/2", "story-runs/r1/3"]);
});
