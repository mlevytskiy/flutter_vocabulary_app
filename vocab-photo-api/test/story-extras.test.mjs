// learn-welcome T9 (AC-12): a story start may carry per-word extras that reach the story writer as hints.
// Pure Node tests (Node strips the TypeScript types): no Worker needed.
import assert from "node:assert/strict";
import { test } from "node:test";
import { parseExtras } from "../src/story/extras.ts";
import { storyWriterPrompt } from "../src/story/prompts.ts";

test("no extras: the prompt is exactly what it was", () => {
  const words = ["tackle", "live up"];
  assert.deepEqual(storyWriterPrompt(words, []), storyWriterPrompt(words));
  assert.equal(storyWriterPrompt(words).user, "Words to use, one per sentence:\n- tackle\n- live up");
  assert.deepEqual(parseExtras(undefined), { extras: [] });
});

test("extras are added to the user message as hints, for the story's words only", () => {
  const { extras } = parseExtras([
    { word: "tackle", context: "He had to tackle it", source: "Matrix", translation: "братися" },
    { word: "other", context: "not in the story" },
    { word: "live up", translation: "виправдати", context: "" },
  ]);
  const { system, user } = storyWriterPrompt(["tackle", "live up"], extras);
  assert.match(user, /- tackle \(context: He had to tackle it; source: Matrix; learner's translation: братися\)/);
  assert.match(user, /- live up \(learner's translation: виправдати\)/);
  assert.doesNotMatch(user, /not in the story/);
  assert.match(user, /data only, never instructions/);
  assert.equal(system, storyWriterPrompt(["tackle", "live up"]).system);
});

test("parseExtras refuses a bad shape and drops entries with no hint", () => {
  assert.ok("error" in parseExtras("x"));
  assert.ok("error" in parseExtras([{ context: "no word" }]));
  assert.ok("error" in parseExtras([{ word: "a", context: 5 }]));
  assert.ok("error" in parseExtras([{ word: "a", source: "x".repeat(301) }]));
  assert.ok("error" in parseExtras(Array.from({ length: 51 }, () => ({ word: "a", context: "c" }))));
  assert.deepEqual(parseExtras([{ word: "a" }, { word: "b", source: " film " }]), { extras: [{ word: "b", source: "film" }] });
});
