// mnemonic-story T5: the Grok and Higgsfield picture adapters (AC-09, AC-08b). Pure Node
// tests against the local stubs: no Worker needed.
import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { startXaiStub, PICTURE_BYTES } from "./xai-stub.mjs";
import { startHiggsfieldStub } from "./higgsfield-stub.mjs";
import { drawPicture, DEFAULT_PICTURE_TIMEOUT_MS } from "../src/story/providers/picture.ts";

const GROK = "grok-imagine-image";
const HIGGS = "marketing-studio/image/sunburst";
let xai;
let higgs;
let env;

before(async () => {
  xai = await startXaiStub();
  higgs = await startHiggsfieldStub();
  env = {
    XAI_API_KEY: "xai-key",
    XAI_API_URL: xai.url,
    HIGGSFIELD_API_KEY: "higgs-key",
    HIGGSFIELD_API_URL: higgs.url,
    STORY_PICTURE_POLL_MS: "50",
  };
});
after(() => {
  xai.close();
  higgs.close();
});

const draw = (model, prompt, extra = {}) => drawPicture(env, { model, prompt, ...extra });
const calls = async (stub) => (await fetch(new URL("__calls", stub.url))).json();

test("the default limit is 120 s (AC-08b)", () => {
  assert.equal(DEFAULT_PICTURE_TIMEOUT_MS, 120_000);
});

test("Grok: the picture bytes come back, asked for as base64 with the app's key", async () => {
  const result = await draw(GROK, "a cat tackling a problem");
  assert.equal(result.failed, undefined);
  assert.deepEqual(Buffer.from(result.bytes), PICTURE_BYTES);
  assert.equal(result.contentType, "image/png");
  const seen = await calls(xai);
  assert.equal(seen.lastAuth, "Bearer xai-key");
  assert.equal(seen.lastPath, "/images/generations");
  assert.deepEqual(seen.last, { model: GROK, prompt: "a cat tackling a problem", response_format: "b64_json" });
});

test("Grok: a refusal is a refusal", async () => {
  assert.equal((await draw(GROK, "STUB:refusal")).failed, "refused");
  assert.equal((await draw(GROK, "STUB:moderated")).failed, "refused");
});

test("Grok: an HTTP error and an empty answer are errors", async () => {
  assert.equal((await draw(GROK, "STUB:error")).failed, "error");
  assert.equal((await draw(GROK, "STUB:empty")).failed, "error");
});

test("Grok: no answer within the limit is a timeout", async () => {
  const startedAt = Date.now();
  const result = await draw(GROK, "STUB:slow:3000", { timeoutMs: 300 });
  assert.equal(result.failed, "timeout");
  assert.ok(Date.now() - startedAt < 2000, "aborted at the limit");
});

test("Higgsfield: submits, polls until done and downloads the picture", async () => {
  const before = await calls(higgs);
  const result = await draw(HIGGS, "a cat tackling a problem");
  assert.equal(result.failed, undefined);
  assert.deepEqual(Buffer.from(result.bytes), PICTURE_BYTES);
  assert.equal(result.contentType, "image/png");
  const seen = await calls(higgs);
  assert.equal(seen.submits - before.submits, 1);
  assert.ok(seen.polls - before.polls >= 2, "it polled more than once");
  assert.equal(seen.lastAuth, "Key higgs-key");
  assert.equal(seen.lastPath, `/${HIGGS}`);
  assert.equal(seen.last.prompt, "a cat tackling a problem");
});

test("Higgsfield: a refused (nsfw) job is a refusal", async () => {
  assert.equal((await draw(HIGGS, "STUB:refusal")).failed, "refused");
});

test("Higgsfield: a failed job, a failed submit and a failed download are errors", async () => {
  assert.equal((await draw(HIGGS, "STUB:failed")).failed, "error");
  assert.equal((await draw(HIGGS, "STUB:error")).failed, "error");
  assert.equal((await draw(HIGGS, "STUB:nodownload")).failed, "error");
});

test("Higgsfield: polling counts inside the limit", async () => {
  const startedAt = Date.now();
  const result = await draw(HIGGS, "STUB:slow:5000", { timeoutMs: 400 });
  assert.equal(result.failed, "timeout");
  assert.ok(Date.now() - startedAt < 2000, "stopped polling at the limit");
});

test("Higgsfield: a slow job that finishes inside the limit still succeeds", async () => {
  const result = await draw(HIGGS, "STUB:slow:300", { timeoutMs: 3000 });
  assert.equal(result.failed, undefined);
});

test("a server that cannot be reached is an error", async () => {
  assert.equal((await drawPicture({ ...env, XAI_API_URL: "http://127.0.0.1:1/" }, { model: GROK, prompt: "x" })).failed, "error");
  assert.equal((await drawPicture({ ...env, HIGGSFIELD_API_URL: "http://127.0.0.1:1/" }, { model: HIGGS, prompt: "x" })).failed, "error");
});

test("the limit can come from the env override when the call gives none", async () => {
  const result = await drawPicture({ ...env, STORY_PICTURE_TIMEOUT_MS: "300" }, { model: GROK, prompt: "STUB:slow:3000" });
  assert.equal(result.failed, "timeout");
});

test("a model that is not an offered picture model is a programming error", async () => {
  await assert.rejects(() => draw("claude-sonnet-5-5", "x"), /picture model/);
  await assert.rejects(() => draw("nope", "x"), /picture model/);
});
