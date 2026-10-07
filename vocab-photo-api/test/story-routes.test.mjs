// mnemonic-story T9: the start, status, redo and picture routes and the 7-day clean-up wiring
// (AC-06, AC-09, AC-10, AC-13, AC-18, AC-19; sad §6 S-02, S-04, S-05, S-09, §8). Run through
// `npm test`: the routes need the local Worker, whose Workflow calls the zen, xai and higgsfield
// stubs that scripts/test.mjs starts. The Worker is started with stub URLs and dummy keys, so
// even a real key in .dev.vars is never sent anywhere: the first test proves that.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { appHeaders, baseUrl, d1, get, publish, sql } from "./helpers.mjs";
import { PICTURE_BYTES } from "./xai-stub.mjs";

const zenUrl = process.env.VOCAB_API_ZEN_STUB_URL;
const xaiUrl = process.env.VOCAB_API_XAI_STUB_URL;
const higgsfieldUrl = process.env.VOCAB_API_HIGGSFIELD_STUB_URL;
const calls = async (url) => (await fetchAgain(new URL("__calls", url))).json();

const WORDS = ["tackle", "live up"];
const MODELS = { storyModel: "deepseek-v4.1-flash", promptModel: "deepseek-v4.1-flash", pictureModel: "grok-imagine-image" };
const json = { "content-type": "application/json" };
const newId = () => randomUUID();

// A keep-alive socket the local server dropped while a test ran a wrangler subprocess (`d1`)
// resets before any answer; none of these requests is harmed by being sent again (see helpers.mjs).
async function fetchAgain(url, init) {
  try {
    return await fetch(url, init);
  } catch (err) {
    if (err?.cause?.code !== "ECONNRESET") throw err;
    return fetch(url, init);
  }
}

const start = (body, headers = appHeaders(json)) =>
  fetchAgain(`${baseUrl}/story/runs`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });
const redo = (body, headers = appHeaders(json)) =>
  fetchAgain(`${baseUrl}/story/runs/redo`, { method: "POST", headers, body: JSON.stringify(body) });
const status = async (ids) => {
  const res = await fetchAgain(`${baseUrl}/story/runs?ids=${ids.join(",")}`, { headers: appHeaders() });
  assert.equal(res.status, 200);
  return (await res.json()).runs;
};
const picture = (runId, attempt, headers = appHeaders()) =>
  fetchAgain(`${baseUrl}/story/runs/${runId}/pictures/${attempt}`, { headers });

const today = () => new Date().toISOString().slice(0, 10);
const used = () => d1(`SELECT used FROM all_story_runs WHERE utc_day = ${sql(today())}`)[0]?.used ?? 0;
const setUsed = (n) => d1(`INSERT OR REPLACE INTO all_story_runs (utc_day, used) VALUES (${sql(today())}, ${n})`);

/** Waits until `check(run)` holds for the run, polling the status route like the app does. */
async function waitFor(runId, check, ms = 20000) {
  const deadline = Date.now() + ms;
  let run;
  while (Date.now() < deadline) {
    [run] = await status([runId]);
    if (run && check(run)) return run;
    await new Promise((ok) => setTimeout(ok, 200));
  }
  assert.fail(`run ${runId} did not get there: ${JSON.stringify(run)}`);
}
const stepOf = (run, role, attempt = 1) => run.steps.find((s) => s.role === role && s.attempt === attempt);

/** A counted run seeded straight into D1 (no Workflow), with the steps given. */
function seedRun(runId, steps) {
  d1(
    `INSERT INTO story_runs (run_id, created_at, words_json, story_model, prompt_model, picture_model)
     VALUES (${sql(runId)}, '2026-10-07T00:00:00.000Z', ${sql(JSON.stringify(WORDS))}, 'deepseek-v4.1-flash', 'deepseek-v4.1-flash', 'grok-imagine-image')`,
  );
  for (const [role, attempt, outcome, text] of steps) {
    d1(
      `INSERT INTO story_run_steps (run_id, role, attempt, model_id, outcome, text, started_at)
       VALUES (${sql(runId)}, ${sql(role)}, ${attempt}, 'deepseek-v4.1-flash', ${sql(outcome)}, ${text ? sql(text) : "NULL"}, '2026-10-07T00:00:01.000Z')`,
    );
  }
}
const STORY = "Ви tackle проблему → ви live up до очікувань";

test("the Worker under test talks to the stubs, never to a real provider", async () => {
  const run = newId();
  const before = { zen: (await calls(zenUrl)).count, xai: (await calls(xaiUrl)).count };
  assert.equal((await start({ runId: run, words: WORDS, ...MODELS })).status, 200);
  await waitFor(run, (r) => stepOf(r, "picture")?.outcome === "done");
  const zen = await calls(zenUrl);
  const xai = await calls(xaiUrl);
  assert.equal(zen.count - before.zen, 2, "story and prompt went to the zen stub");
  assert.equal(xai.count - before.xai, 1, "the picture went to the xai stub");
  assert.equal(zen.lastAuth, "Bearer test-key");
  assert.equal(xai.lastAuth, "Bearer test-key", "the dummy key, not the one in .dev.vars");
});

test("AC-18: every story route answers 401 without the app secret, and nothing is started", async () => {
  const run = newId();
  const bare = (path, init = {}) => fetch(`${baseUrl}${path}`, init);
  const body = JSON.stringify({ runId: run, words: WORDS, ...MODELS });
  for (const headers of [json, { ...json, "x-app-secret": "wrong" }]) {
    assert.equal((await bare("/story/runs", { method: "POST", headers, body })).status, 401);
    assert.equal((await bare("/story/runs/redo", { method: "POST", headers, body: JSON.stringify({ runId: run, step: "picture" }) })).status, 401);
  }
  assert.equal((await bare(`/story/runs?ids=${run}`)).status, 401);
  assert.equal((await bare(`/story/runs/${run}/pictures/1`)).status, 401);
  assert.deepEqual(await status([run]), [], "no run was counted");
});

test("AC-06, AC-10: start counts the run, returns started and the run goes on to a picture", async () => {
  const run = newId();
  const before = used();
  const res = await start({ runId: run, words: WORDS, ...MODELS });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { started: true });
  assert.equal(used(), before + 1);

  const done = await waitFor(run, (r) => stepOf(r, "picture")?.outcome === "done");
  assert.deepEqual(done.words, WORDS);
  assert.equal(stepOf(done, "story").outcome, "done");
  assert.equal(stepOf(done, "prompt").outcome, "done");
  assert.equal(typeof stepOf(done, "story").priceUsd, "number");

  const pic = await picture(run, 1);
  assert.equal(pic.status, 200);
  assert.match(pic.headers.get("content-type") ?? "", /^image\//);
  assert.deepEqual(Buffer.from(await pic.arrayBuffer()), PICTURE_BYTES);
  assert.equal((await picture(run, 2)).status, 404);
  assert.equal((await picture(newId(), 1)).status, 404);
});

test("AC-19: a repeated run id is free and starts nothing twice", async () => {
  const run = newId();
  const first = await start({ runId: run, words: WORDS, ...MODELS });
  assert.equal(first.status, 200);
  const before = used();
  const zenBefore = (await calls(zenUrl)).count;
  const again = await start({ runId: run, words: WORDS, ...MODELS });
  assert.equal(again.status, 200);
  assert.deepEqual(await again.json(), { started: true });
  assert.equal(used(), before, "nothing taken for a repeated run id");
  await waitFor(run, (r) => stepOf(r, "picture")?.outcome === "done");
  assert.ok((await calls(zenUrl)).count - zenBefore <= 2, "the repeat did not write the story again");
});

test("AC-13, AC-19: start refuses an AI that is not offered, with no unit taken and no run counted", async () => {
  const before = used();
  const zenBefore = (await calls(zenUrl)).count;
  for (const bad of [
    { storyModel: "gpt-nonexistent" },
    { promptModel: "claude-haiku-4-5-20251001" },
    { pictureModel: "deepseek-v4.1-flash" }, // a text AI is not a picture AI
    { storyModel: "grok-imagine-image" }, // a picture AI is not a text AI
  ]) {
    const run = newId();
    const res = await start({ runId: run, words: WORDS, ...MODELS, ...bad });
    assert.equal(res.status, 422, JSON.stringify(bad));
    const body = await res.json();
    assert.equal(body.code, "not_offered");
    assert.equal(body.model, Object.values(bad)[0]);
    assert.deepEqual(await status([run]), []);
  }
  assert.equal(used(), before);
  assert.equal((await calls(zenUrl)).count, zenBefore);
});

test("start answers 400 for a malformed body and counts nothing", async () => {
  const before = used();
  for (const bad of [
    "not json",
    {},
    { runId: "", words: WORDS, ...MODELS },
    { runId: "has space", words: WORDS, ...MODELS },
    { runId: "x".repeat(100), words: WORDS, ...MODELS },
    { runId: newId(), words: [], ...MODELS },
    { runId: newId(), words: ["ok", ""], ...MODELS },
    { runId: newId(), words: "tackle", ...MODELS },
    { runId: newId(), words: WORDS, storyModel: 1, promptModel: "x", pictureModel: "y" },
    { runId: newId(), words: WORDS, storyModel: MODELS.storyModel },
  ]) {
    assert.equal((await start(bad)).status, 400, JSON.stringify(bad));
  }
  assert.equal(used(), before);
});

test("status returns several runs' steps in one call and leaves out ids never counted", async () => {
  const a = newId();
  const b = newId();
  seedRun(a, [["story", 1, "done", STORY], ["prompt", 1, "failed", null]]);
  seedRun(b, [["story", 1, "running", null]]);
  const runs = await status([a, newId(), b]);
  assert.deepEqual(runs.map((r) => r.runId).sort(), [a, b].sort());
  const ra = runs.find((r) => r.runId === a);
  assert.deepEqual(ra.steps.map((s) => `${s.role}:${s.outcome}`), ["story:done", "prompt:failed"]);
  assert.equal(stepOf(ra, "story").text, STORY);
  assert.equal(runs.find((r) => r.runId === b).steps[0].outcome, "running");

  assert.equal((await fetchAgain(`${baseUrl}/story/runs`, { headers: appHeaders() })).status, 400);
  assert.equal((await fetch(`${baseUrl}/story/runs?ids=`, { headers: appHeaders() })).status, 400);
});

test("AC-08b, AC-19: redo refuses a bad body, an unknown run, a step that has not failed, and takes no unit", async () => {
  const before = used();
  const zenBefore = (await calls(zenUrl)).count;
  const done = newId();
  seedRun(done, [["story", 1, "done", STORY], ["prompt", 1, "done", "a picture prompt"], ["picture", 1, "done", null]]);
  const storyFailed = newId();
  seedRun(storyFailed, [["story", 1, "failed", null]]);
  const running = newId();
  seedRun(running, [["story", 1, "done", STORY], ["prompt", 1, "done", "p"], ["picture", 1, "running", null]]);

  assert.equal((await redo({ runId: newId(), step: "picture" })).status, 404);
  assert.equal((await redo({ runId: newId(), step: "prompt" })).status, 404);
  assert.equal((await redo({ runId: done, step: "story" })).status, 400, "the story is redone as a new run");
  assert.equal((await redo({ runId: done, step: "nope" })).status, 400);
  assert.equal((await redo({ step: "picture" })).status, 400);
  for (const [runId, step] of [[done, "picture"], [done, "prompt"], [storyFailed, "prompt"], [storyFailed, "picture"], [running, "picture"]]) {
    const res = await redo({ runId, step });
    assert.equal(res.status, 409, `${runId} ${step}`);
    assert.equal((await res.json()).code, "not_failed");
  }
  assert.equal(used(), before);
  assert.equal((await calls(zenUrl)).count, zenBefore);
});

test("AC-08b: redo of the picture prompt takes no unit and carries on to the picture from the same story", async () => {
  const run = newId();
  seedRun(run, [["story", 1, "done", STORY], ["prompt", 1, "failed", null]]);
  const before = used();
  const res = await redo({ runId: run, step: "prompt" });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { started: true });
  assert.equal(used(), before, "redoing the prompt takes nothing");
  const done = await waitFor(run, (r) => stepOf(r, "picture")?.outcome === "done");
  assert.equal(stepOf(done, "prompt").outcome, "done");
  assert.equal(stepOf(done, "story").text, STORY, "the story was not written again");
  // The step is no longer failed, so a second redo is refused.
  assert.equal((await redo({ runId: run, step: "prompt" })).status, 409);
});

test("AC-09, AC-19: Draw again takes one unit, makes attempt 2 with the chosen picture AI and keeps attempt 1", async () => {
  const run = newId();
  seedRun(run, [["story", 1, "done", STORY], ["prompt", 1, "done", "a picture prompt"], ["picture", 1, "failed", null]]);
  const before = used();
  const higgsBefore = (await calls(higgsfieldUrl)).submits;
  const res = await redo({ runId: run, step: "picture", pictureModel: "marketing-studio/image/sunburst" });
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { started: true, attempt: 2 });
  assert.equal(used(), before + 1);

  const done = await waitFor(run, (r) => stepOf(r, "picture", 2)?.outcome === "done");
  assert.equal(stepOf(done, "picture", 1).outcome, "failed");
  assert.equal(stepOf(done, "picture", 2).modelId, "marketing-studio/image/sunburst");
  assert.equal((await calls(higgsfieldUrl)).submits - higgsBefore, 1);
  assert.equal(used(), before + 1, "the run itself took nothing more");
  assert.deepEqual(Buffer.from(await (await picture(run, 2)).arrayBuffer()), PICTURE_BYTES);
  assert.equal((await picture(run, 1)).status, 404);
});

test("AC-13: Draw again with an AI that is not offered is refused and takes no unit", async () => {
  const run = newId();
  seedRun(run, [["story", 1, "done", STORY], ["prompt", 1, "done", "p"], ["picture", 1, "failed", null]]);
  const before = used();
  const res = await redo({ runId: run, step: "picture", pictureModel: "deepseek-v4.1-flash" });
  assert.equal(res.status, 422);
  assert.equal((await res.json()).code, "not_offered");
  assert.equal(used(), before);
  assert.equal(stepOf((await status([run]))[0], "picture", 2), undefined);
});

test("AC-19: the 21st unit of a day is refused for a start and for Draw again, a repeated run id stays free", async () => {
  const counted = newId();
  const failedPicture = newId();
  seedRun(failedPicture, [["story", 1, "done", STORY], ["prompt", 1, "done", "p"], ["picture", 1, "failed", null]]);
  try {
    setUsed(19);
    const twentieth = newId();
    assert.equal((await start({ runId: twentieth, words: WORDS, ...MODELS })).status, 200);
    assert.equal(used(), 20);
    await waitFor(twentieth, (r) => stepOf(r, "picture")?.outcome === "done");

    const zenBefore = (await calls(zenUrl)).count;
    const refused = await start({ runId: counted, words: WORDS, ...MODELS });
    assert.equal(refused.status, 429);
    assert.equal((await refused.json()).code, "day_limit");
    assert.deepEqual(await status([counted]), []);

    const again = await redo({ runId: failedPicture, step: "picture" });
    assert.equal(again.status, 429);
    assert.equal((await again.json()).code, "day_limit");
    assert.equal(stepOf((await status([failedPicture]))[0], "picture", 2), undefined);

    assert.equal((await start({ runId: twentieth, words: WORDS, ...MODELS })).status, 200, "an already counted run id is free");
    assert.equal(used(), 20);
    assert.equal((await calls(zenUrl)).count, zenBefore, "nothing was written for the refused ones");
  } finally {
    setUsed(0);
  }
});

test("AC-18: the web learn page and its coming-soon link answer as before, with no way to start a run", async () => {
  const { id } = await publish();
  const page = await get(`/s/${id}/learn`);
  assert.equal(page.status, 200);
  const html = await page.text();
  assert.match(html, /Coming soon/);
  assert.doesNotMatch(html.replace(/<style>[\s\S]*?<\/style>/, ""), /\/story|<form|runs/i);
  const soon = await get(`/s/${id}/learn/mnemonic-story`);
  assert.equal(soon.status, 200);
  assert.match(await soon.text(), /Coming soon — this exercise is not ready yet\./);
  // A public caller cannot reach the story routes through the page's paths either.
  for (const path of [`/s/${id}/story/runs`, `/s/${id}/learn/story`]) {
    assert.ok([404, 405].includes((await fetch(`${baseUrl}${path}`, { method: "POST", headers: json, body: "{}" })).status), path);
  }
});

test("the daily cron also runs the picture clean-up and keeps a picture younger than 7 days", async () => {
  const run = newId();
  assert.equal((await start({ runId: run, words: WORDS, ...MODELS })).status, 200);
  await waitFor(run, (r) => stepOf(r, "picture")?.outcome === "done");
  const cron = await fetch(`${baseUrl}/__scheduled?cron=0+3+*+*+*`);
  assert.equal(cron.status, 200);
  assert.equal((await picture(run, 1)).status, 200, "a fresh picture is not deleted");
  assert.ok(stepOf((await status([run]))[0], "picture").pictureKey);
});
