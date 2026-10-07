// mnemonic-story T8: the story run's steps (AC-08, AC-08b, AC-09, AC-10), run against the
// stub providers, a real-schema node:sqlite D1 and an in-memory R2. The Workflow class
// only hands `step.do` to `runStoryRun`; here a small stand-in for `step.do` plays the
// engine, including its replay of a finished step after a restart.
import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";
import { sqliteD1 } from "./sqlite-d1.mjs";
import { startZenStub, ZEN_STUB_TEXT } from "./zen-stub.mjs";
import { startXaiStub, PICTURE_BYTES } from "./xai-stub.mjs";
import { takeStoryRun, takeDrawAgain } from "../src/story/allowance.ts";
import { recordStep, runStatus } from "../src/story/store.ts";
import { runStoryRun, STEP_CONFIG } from "../src/story/run-steps.ts";

const STORY_MODEL = "deepseek-v4.1-flash";
const PICTURE_MODEL = "grok-imagine-image";
let zen;
let xai;
let env;

before(async () => {
  zen = await startZenStub();
  xai = await startXaiStub();
});
after(() => {
  zen.close();
  xai.close();
});

function fakeR2() {
  const objects = new Map();
  return {
    objects,
    async put(key, value, options) {
      objects.set(key, { value, contentType: options?.httpMetadata?.contentType });
    },
  };
}

beforeEach(async () => {
  await fetch(new URL("__reset", zen.url), { method: "POST", body: "{}" });
  await fetch(new URL("__reset", xai.url), { method: "POST", body: "{}" });
  env = {
    DB: sqliteD1(),
    SOURCES: fakeR2(),
    ANTHROPIC_API_KEY: "a",
    OPENCODE_ZEN_API_KEY: "zen-key",
    OPENCODE_ZEN_API_URL: zen.url,
    XAI_API_KEY: "xai-key",
    XAI_API_URL: xai.url,
    HIGGSFIELD_API_KEY: "h",
    STORY_TEXT_TIMEOUT_MS: "300",
    STORY_PICTURE_TIMEOUT_MS: "300",
  };
});

const script = (stub, markers) =>
  fetch(new URL("__script", stub.url), { method: "POST", body: JSON.stringify(markers) });
const calls = async (stub) => (await fetch(new URL("__calls", stub.url))).json();

/** The engine's `step.do`: runs a step once per name and replays the stored result after that. */
function engine(cache = new Map(), seen = []) {
  return {
    cache,
    seen,
    async do(name, config, fn) {
      seen.push({ name, config });
      if (cache.has(name)) return cache.get(name);
      const result = await fn();
      cache.set(name, JSON.parse(JSON.stringify(result ?? null)));
      return cache.get(name);
    },
  };
}

const WORDS = ["tackle", "live up"];
const newRun = (runId, words = WORDS) => ({
  runId,
  words,
  storyModel: STORY_MODEL,
  promptModel: STORY_MODEL,
  pictureModel: PICTURE_MODEL,
});
async function start(runId, words) {
  assert.deepEqual(await takeStoryRun(env, newRun(runId, words)), { outcome: "taken" });
}
const steps = async (runId) => (await runStatus(env, [runId]))[0].steps;
const byRole = (list, role) => list.filter((s) => s.role === role);

test("every step runs once with no retries (AC-10, ADR-0002)", () => {
  assert.equal(STEP_CONFIG.retries.limit, 0);
});

test("a full run records story, prompt and picture with prices and times, and keeps the picture in R2 (AC-08)", async () => {
  await start("r1");
  const e = engine();
  await runStoryRun(env, e, { runId: "r1", mode: "full", attempt: 1 });

  const list = await steps("r1");
  assert.deepEqual(list.map((s) => [s.role, s.attempt, s.outcome]), [
    ["story", 1, "done"],
    ["prompt", 1, "done"],
    ["picture", 1, "done"],
  ]);
  const [story, prompt, picture] = list;
  assert.equal(story.text, ZEN_STUB_TEXT);
  assert.equal(prompt.text, ZEN_STUB_TEXT);
  assert.deepEqual(story.missedWords, null);
  // 910 in x 0.3 + 275 out x 1.2 per million tokens
  assert.ok(Math.abs(story.priceUsd - (910 * 0.3 + 275 * 1.2) / 1e6) < 1e-12);
  assert.equal(story.priceEstimated, false);
  assert.equal(picture.priceUsd, 0.02);
  for (const s of list) {
    assert.equal(typeof s.ms, "number");
    assert.ok(s.finishedAt);
  }
  assert.equal(picture.pictureKey, "story-runs/r1/1");
  assert.deepEqual(Buffer.from(env.SOURCES.objects.get("story-runs/r1/1").value), PICTURE_BYTES);
  assert.equal(env.SOURCES.objects.get("story-runs/r1/1").contentType, "image/png");
  assert.equal((await calls(zen)).count, 2);
  assert.equal((await calls(xai)).count, 1);
  assert.ok(e.seen.every((s) => s.config.retries.limit === 0));
  // The picture prompt writer was given the story, the picture maker the written prompt.
  assert.equal((await calls(xai)).last.prompt, ZEN_STUB_TEXT);
});

test("a missed word stops the run at the story and lists the words (AC-08)", async () => {
  await start("r2", ["tackle", "absent word"]);
  await runStoryRun(env, engine(), { runId: "r2", mode: "full", attempt: 1 });
  const list = await steps("r2");
  assert.deepEqual(list.map((s) => [s.role, s.outcome]), [["story", "failed"]]);
  assert.deepEqual(list[0].missedWords, ["absent word"]);
  assert.equal(list[0].text, ZEN_STUB_TEXT);
  assert.ok(list[0].priceUsd > 0);
  assert.equal((await calls(zen)).count, 1);
  assert.equal((await calls(xai)).count, 0);
});

for (const [marker, price] of [["STUB:refusal", "tokens"], ["STUB:error", "none"], ["STUB:slow:2000", "estimated"]]) {
  test(`a story writer failure (${marker}) stops at the story step (AC-08b)`, async () => {
    await start("r3");
    await script(zen, [marker]);
    await runStoryRun(env, engine(), { runId: "r3", mode: "full", attempt: 1 });
    const list = await steps("r3");
    assert.deepEqual(list.map((s) => [s.role, s.outcome]), [["story", "failed"]]);
    assert.equal(typeof list[0].ms, "number");
    if (price === "estimated") {
      assert.equal(list[0].priceEstimated, true);
      assert.ok(list[0].priceUsd > 0);
    }
    if (price === "none") assert.equal(list[0].priceUsd, 0);
    assert.equal((await calls(zen)).count, 1);
    assert.equal((await calls(xai)).count, 0);
  });
}

test("a picture prompt writer failure stops at the prompt step and keeps the story (AC-08b)", async () => {
  await start("r4");
  await script(zen, ["ok", "STUB:error"]);
  await runStoryRun(env, engine(), { runId: "r4", mode: "full", attempt: 1 });
  const list = await steps("r4");
  assert.deepEqual(list.map((s) => [s.role, s.outcome]), [["story", "done"], ["prompt", "failed"]]);
  assert.equal((await calls(xai)).count, 0);
});

for (const marker of ["STUB:refusal", "STUB:error", "STUB:slow:2000"]) {
  test(`a picture failure (${marker}) stops at the picture step with the story and prompt kept (AC-09)`, async () => {
    await start("r5");
    await script(xai, [marker]);
    await runStoryRun(env, engine(), { runId: "r5", mode: "full", attempt: 1 });
    const list = await steps("r5");
    assert.deepEqual(list.map((s) => [s.role, s.outcome]), [["story", "done"], ["prompt", "done"], ["picture", "failed"]]);
    assert.equal(list[2].pictureKey, null);
    assert.equal(typeof list[2].ms, "number");
    assert.equal(env.SOURCES.objects.size, 0);
    if (marker.includes("slow")) {
      assert.equal(list[2].priceEstimated, true);
      assert.equal(list[2].priceUsd, 0.02);
    }
  });
}

test("every stub is called once per step even when the run is replayed after a restart or the client left (AC-10)", async () => {
  await start("r6");
  const e = engine();
  const params = { runId: "r6", mode: "full", attempt: 1 };
  await runStoryRun(env, e, params);
  // The engine runs the instance again from its stored step results.
  await runStoryRun(env, engine(e.cache), params);
  assert.equal((await calls(zen)).count, 2);
  assert.equal((await calls(xai)).count, 1);
  assert.equal((await steps("r6")).length, 3);
});

test("a run that was never counted is not run (AC-19)", async () => {
  await runStoryRun(env, engine(), { runId: "ghost", mode: "full", attempt: 1 });
  assert.equal((await calls(zen)).count, 0);
  assert.equal((await calls(xai)).count, 0);
});

test("prompt redo runs the prompt step from the same story, then the picture (AC-08b)", async () => {
  await start("r7");
  await script(zen, ["ok", "STUB:error"]);
  await runStoryRun(env, engine(), { runId: "r7", mode: "full", attempt: 1 });
  await fetch(new URL("__reset", zen.url), { method: "POST", body: "{}" });
  await runStoryRun(env, engine(), { runId: "r7", mode: "prompt", attempt: 1 });
  const list = await steps("r7");
  assert.deepEqual(list.map((s) => [s.role, s.attempt, s.outcome]), [
    ["story", 1, "done"],
    ["prompt", 1, "done"],
    ["picture", 1, "done"],
  ]);
  const seen = await calls(zen);
  assert.equal(seen.count, 1, "only the prompt step called the text AI");
  assert.match(seen.last.messages.find((m) => m.role === "user").content, /Story:\n/);
  assert.equal((await calls(xai)).count, 1);
});

test("picture redo draws again from the same prompt with the picture AI chosen now, as a new attempt (AC-09)", async () => {
  await start("r8");
  await script(xai, ["STUB:error"]);
  await runStoryRun(env, engine(), { runId: "r8", mode: "full", attempt: 1 });
  assert.deepEqual(await takeDrawAgain(env, "r8", 2), { outcome: "taken" });
  await fetch(new URL("__reset", zen.url), { method: "POST", body: "{}" });
  await runStoryRun(env, engine(), { runId: "r8", mode: "picture", pictureModel: PICTURE_MODEL, attempt: 2 });

  const pictures = byRole(await steps("r8"), "picture");
  assert.deepEqual(pictures.map((s) => [s.attempt, s.outcome]), [[1, "failed"], [2, "done"]]);
  assert.equal(pictures[1].pictureKey, "story-runs/r8/2");
  assert.equal((await calls(zen)).count, 0, "no text AI call");
  assert.equal((await calls(xai)).count, 2);
  assert.equal((await calls(xai)).last.prompt, ZEN_STUB_TEXT);
  assert.equal(env.SOURCES.objects.has("story-runs/r8/1"), false);
});

test("a redo for a step whose input is missing records a failure instead of calling an AI", async () => {
  await start("r9");
  await runStoryRun(env, engine(), { runId: "r9", mode: "picture", attempt: 1 });
  assert.equal((await calls(xai)).count, 0);
  const list = await steps("r9");
  assert.deepEqual(list.map((s) => [s.role, s.outcome]), [["picture", "failed"]]);
});

test("a picture AI that is not offered fails the step without a call", async () => {
  await start("r10");
  await runStoryRun(env, engine(), { runId: "r10", mode: "full", pictureModel: "not-a-model", attempt: 1 });
  const list = await steps("r10");
  assert.deepEqual(list.map((s) => [s.role, s.outcome]), [["story", "done"], ["prompt", "done"], ["picture", "failed"]]);
  assert.equal((await calls(xai)).count, 0);
});

test("recordStep is the writer for results (sanity: a running row is replaced)", async () => {
  await start("r11");
  await recordStep(env, { runId: "r11", role: "story", attempt: 1, modelId: STORY_MODEL, outcome: "running", startedAt: "2026-10-07T00:00:00Z" });
  await runStoryRun(env, engine(), { runId: "r11", mode: "full", attempt: 1 });
  assert.equal(byRole(await steps("r11"), "story").length, 1);
  assert.equal(byRole(await steps("r11"), "story")[0].outcome, "done");
});
