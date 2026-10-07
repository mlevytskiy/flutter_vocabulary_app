// mnemonic-story T2: the offered AI list and the step pricing rule (AC-12, AC-13,
// ADR-0004). Pure unit tests: no Worker needed (Node strips the TypeScript types).
import assert from "node:assert/strict";
import { test } from "node:test";
import {
  GROUPING_MODEL,
  defaults,
  estimateOnTimeout,
  isOffered,
  offeredModels,
  priceOf,
  pricesAsOf,
} from "../src/story/models.ts";

test("every default names an offered model of the right role", () => {
  assert.equal(defaults.story, "claude-sonnet-5-5");
  assert.equal(defaults.prompt, "claude-sonnet-5-5");
  assert.equal(defaults.picture, "grok-imagine-image");
  assert.ok(isOffered("text", defaults.story));
  assert.ok(isOffered("text", defaults.prompt));
  assert.ok(isOffered("picture", defaults.picture));
});

test("the list carries the date of its prices and the fixed grouping model", () => {
  assert.equal(pricesAsOf, "2026-10-07");
  assert.equal(GROUPING_MODEL, "claude-haiku-4-5-20251001");
});

test("Sonnet 5.5 and Opus 5.5 are offered as text at the app's list prices", () => {
  const byId = Object.fromEntries(offeredModels.map((m) => [m.id, m]));
  assert.deepEqual(
    [byId["claude-sonnet-5-5"].inputUsdPerMTok, byId["claude-sonnet-5-5"].outputUsdPerMTok],
    [2, 10],
  );
  assert.deepEqual(
    [byId["claude-opus-5-5"].inputUsdPerMTok, byId["claude-opus-5-5"].outputUsdPerMTok],
    [4, 20],
  );
});

test("an unlisted id, or a text id asked for as a picture, is not offered", () => {
  assert.equal(isOffered("text", "gpt-nonexistent"), false);
  assert.equal(isOffered("picture", "claude-sonnet-5-5"), false);
  assert.equal(isOffered("text", "grok-imagine-image"), false);
  assert.equal(isOffered("text", GROUPING_MODEL), false);
  assert.equal(isOffered("text", ""), false);
});

test("a text step is priced as tokens times the list price", () => {
  // 100k in * $2/M + 20k out * $10/M = 0.2 + 0.2
  const price = priceOf({ modelId: "claude-sonnet-5-5", inputTokens: 100_000, outputTokens: 20_000 });
  assert.ok(Math.abs(price.usd - 0.4) < 1e-9);
  assert.equal(price.estimated, false);
  const opus = priceOf({ modelId: "claude-opus-5-5", inputTokens: 1_000_000, outputTokens: 1_000_000 });
  assert.ok(Math.abs(opus.usd - 24) < 1e-9);
});

test("a picture step is priced per picture; Higgsfield's price is marked approximate", () => {
  assert.deepEqual(priceOf({ modelId: "grok-imagine-image" }), { usd: 0.02, estimated: false });
  const higgs = priceOf({ modelId: "marketing-studio/image/sunburst" });
  assert.equal(higgs.usd, 0.013);
  assert.equal(higgs.estimated, true);
});

test("pricing a model that is not on the list throws", () => {
  assert.throws(() => priceOf({ modelId: "nope", inputTokens: 1, outputTokens: 1 }));
  assert.throws(() => estimateOnTimeout("nope", 1, 1));
});

test("a timeout is estimated from the input sent plus the output limit, marked estimated", () => {
  const est = estimateOnTimeout("claude-sonnet-5-5", 50_000, 4_000);
  // 50k * $2/M + 4k * $10/M = 0.1 + 0.04
  assert.ok(Math.abs(est.usd - 0.14) < 1e-9);
  assert.equal(est.estimated, true);
  assert.deepEqual(estimateOnTimeout("grok-imagine-image", 0, 0), { usd: 0.02, estimated: true });
});

test("every text AI has a positive 15-word estimate; every entry has a role and provider", () => {
  for (const m of offeredModels) {
    assert.ok(["text", "picture"].includes(m.role), m.id);
    assert.ok(["anthropic", "opencode-zen", "xai", "higgsfield"].includes(m.provider), m.id);
    if (m.role === "text") assert.ok(m.estimate15Usd > 0, m.id);
  }
  assert.equal(new Set(offeredModels.map((m) => m.id)).size, offeredModels.length);
});
