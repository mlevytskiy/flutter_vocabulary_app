// mnemonic-story T4: the Anthropic and OpenCode Zen text adapters (AC-08b). Pure Node
// tests against the local stubs: no Worker needed (Node strips the TypeScript types).
import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { startAnthropicStub } from "./anthropic-stub.mjs";
import { startZenStub } from "./zen-stub.mjs";
import { writeText, DEFAULT_TEXT_TIMEOUT_MS } from "../src/story/providers/text.ts";
import { picturePromptWriterPrompt, storyWriterPrompt } from "../src/story/prompts.ts";

let anthropic;
let zen;
let env;

before(async () => {
  anthropic = await startAnthropicStub();
  zen = await startZenStub();
  env = {
    ANTHROPIC_API_KEY: "anthropic-key",
    ANTHROPIC_API_URL: anthropic.url,
    OPENCODE_ZEN_API_KEY: "zen-key",
    OPENCODE_ZEN_API_URL: zen.url,
  };
});
after(() => {
  anthropic.close();
  zen.close();
});

const ask = (model, user, extra = {}) => writeText(env, { model, system: "Write.", user, ...extra });
const calls = async (stub) => (await fetch(new URL("__calls", stub.url))).json();

test("the default limit is 90 s (AC-08b)", () => {
  assert.equal(DEFAULT_TEXT_TIMEOUT_MS, 90_000);
});

test("Anthropic: the text and the reported usage come back, sent with the app's key", async () => {
  const result = await ask("claude-sonnet-5-5", "tell a story");
  assert.equal(result.failed, undefined);
  assert.ok(result.text.length > 0);
  assert.deepEqual(result.usage, { modelId: "claude-sonnet-5-5", inputTokens: 1200, outputTokens: 340 });
  const seen = await calls(anthropic);
  assert.equal(seen.lastApiKey, "anthropic-key");
  assert.equal(seen.last.model, "claude-sonnet-5-5");
  assert.equal(seen.last.system, "Write.");
});

test("Anthropic: a refusal is a failure, not text", async () => {
  const result = await ask("claude-sonnet-5-5", "STUB:refusal");
  assert.equal(result.failed, "refused");
  assert.equal(result.text, undefined);
});

test("Anthropic: an HTTP error is a failure", async () => {
  const result = await ask("claude-opus-5-5", "STUB:error");
  assert.equal(result.failed, "error");
});

test("Anthropic: a cut-off reply is a failure", async () => {
  const result = await ask("claude-sonnet-5-5", "STUB:cutoff");
  assert.equal(result.failed, "error");
});

test("Anthropic: no answer within the limit is a timeout with no usage", async () => {
  const startedAt = Date.now();
  const result = await ask("claude-sonnet-5-5", "STUB:slow:3000", { timeoutMs: 300 });
  assert.equal(result.failed, "timeout");
  assert.equal(result.usage, undefined);
  assert.ok(Date.now() - startedAt < 2000, "aborted at the limit, not when the stub answered");
});

test("Zen: the text and the reported usage come back, sent as a bearer key to chat/completions", async () => {
  const result = await ask("deepseek-v4-flash", "tell a story");
  assert.equal(result.failed, undefined);
  assert.match(result.text, /tackle/);
  assert.deepEqual(result.usage, { modelId: "deepseek-v4-flash", inputTokens: 910, outputTokens: 275 });
  const seen = await calls(zen);
  assert.equal(seen.lastAuth, "Bearer zen-key");
  assert.equal(seen.lastPath, "/chat/completions");
  assert.equal(seen.last.model, "deepseek-v4-flash");
  assert.deepEqual(seen.last.messages.map((m) => m.role), ["system", "user"]);
});

test("Zen: a refusal or a content filter is a refusal", async () => {
  assert.equal((await ask("gpt-5.4-mini", "STUB:refusal")).failed, "refused");
  assert.equal((await ask("gpt-5.4-mini", "STUB:filtered")).failed, "refused");
});

test("Zen: an HTTP error, a cut-off reply and an empty reply are errors", async () => {
  assert.equal((await ask("gpt-5.4-mini", "STUB:error")).failed, "error");
  assert.equal((await ask("gpt-5.4-mini", "STUB:cutoff")).failed, "error");
  assert.equal((await ask("gpt-5.4-mini", "STUB:empty")).failed, "error");
});

test("Zen: no answer within the limit is a timeout with no usage", async () => {
  const result = await ask("deepseek-v4-flash", "STUB:slow:3000", { timeoutMs: 300 });
  assert.equal(result.failed, "timeout");
  assert.equal(result.usage, undefined);
});

test("a server that cannot be reached is an error", async () => {
  const result = await writeText({ ...env, OPENCODE_ZEN_API_URL: "http://127.0.0.1:1/" }, { model: "gpt-5.4-mini", system: "s", user: "u" });
  assert.equal(result.failed, "error");
});

test("the limit can come from the env override when the call gives none", async () => {
  const result = await writeText({ ...env, STORY_TEXT_TIMEOUT_MS: "300" }, { model: "deepseek-v4-flash", system: "s", user: "STUB:slow:3000" });
  assert.equal(result.failed, "timeout");
});

test("a model that is not an offered text model is a programming error", async () => {
  await assert.rejects(() => ask("grok-imagine-image", "x"), /text model/);
  await assert.rejects(() => ask("nope", "x"), /text model/);
});

test("the story writer prompt carries every word as written, the arrow format and the sample", () => {
  const { system, user } = storyWriterPrompt(["tackle", "live up to", "in a pinch"]);
  for (const word of ["tackle", "live up to", "in a pinch"]) assert.ok(user.includes(word), word);
  assert.match(system, /→/);
  assert.match(system, /Ukrainian/i);
  assert.match(system, /veers off/, "the owner's sample is the example");
});

test("the picture prompt writer prompt carries the story", () => {
  const { system, user } = picturePromptWriterPrompt("Ви tackle проблему → ви live up до очікувань");
  assert.ok(user.includes("tackle проблему"));
  assert.match(system, /picture/i);
});
