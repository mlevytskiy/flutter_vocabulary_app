// word-context T6 (AC-10, ADR-0002): with `context=true` the photo prompt asks for the photo's running text
// (`full_text`) and, per word, the context with its kind (`context_source`: "photo" quoted, "ai" written on an
// exercise sheet or word list); the parser still takes an answer without the new fields. Without `context=true`
// the prompts stay byte for byte what they were (test/fixtures/analyze-prompts-without-context.json, captured
// from the code before T6). Pure unit tests: no Worker needed.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { buildSystemPrompt, parseAnalyzeAnswer, parseOptions } from "../src/analyze.ts";

const BEFORE = JSON.parse(readFileSync(new URL("./fixtures/analyze-prompts-without-context.json", import.meta.url), "utf8"));
const withContext = parseOptions(new URL("https://x/analyze?context=true&translation=true&with_desc=true"));
const withoutContext = parseOptions(new URL("https://x/analyze?translation=true&with_desc=true"));

test("T6: without context=true the prompts are byte-identical to before", () => {
  for (const [name, { options, prompt }] of Object.entries(BEFORE)) {
    assert.equal(buildSystemPrompt(options), prompt, name);
  }
});

test("T6: with context=true the prompt asks for full_text, context and context_source with the exercise-sheet rule", () => {
  const prompt = buildSystemPrompt(withContext);
  assert.match(prompt, /"full_text": /);
  assert.match(prompt, /"context_source": "<photo or ai>"/);
  assert.match(prompt, /strict JSON object/);
  assert.match(prompt, /exercise sheet, a word list/);
  assert.match(prompt, /set context_source to "ai"/);
  assert.match(prompt, /full_text is an empty string/);
});

test("T6: running text — the full text and quoted contexts marked photo", () => {
  const text = JSON.stringify({
    full_text: "  The tide was coming in. We waited on the shore.  ",
    words: [
      { word: "tide", context: "The tide was coming in.", context_source: "photo", translation: "приплив", description: "The rise of the sea." },
      { word: "shore", context: "We waited on the shore.", context_source: "photo", translation: "берег", description: "Land by the sea." },
    ],
  });
  const answer = parseAnalyzeAnswer(text, withContext);
  assert.equal(answer.full_text, "The tide was coming in. We waited on the shore.");
  assert.deepEqual(answer.words.map((w) => [w.word, w.context, w.context_source]), [
    ["tide", "The tide was coming in.", "photo"],
    ["shore", "We waited on the shore.", "photo"],
  ]);
});

test("T6: an exercise sheet — empty full text and AI-written contexts marked ai, in a fenced block", () => {
  const text = "```json\n" + JSON.stringify({
    full_text: "",
    words: [
      { word: "reluctant", context: "She was reluctant to leave.", context_source: "ai", translation: "неохочий", description: "Unwilling." },
      { word: "wary", context: "Be wary of strangers.", context_source: "ai", translation: "обережний", description: "Careful." },
    ],
  }) + "\n```";
  const answer = parseAnalyzeAnswer(text, withContext);
  assert.equal(answer.full_text, "");
  assert.deepEqual(answer.words.map((w) => w.context_source), ["ai", "ai"]);
});

test("T6: an old-shape answer (bare array, no full_text, no context_source) is accepted", () => {
  const old = [{ word: "fog", context: "Fog on the hills.", translation: "туман", description: "Thick mist." }];
  const fromArray = parseAnalyzeAnswer(JSON.stringify(old), withContext);
  assert.deepEqual(fromArray, { full_text: "", words: [{ ...old[0], context_source: "photo" }] });
  const fromObject = parseAnalyzeAnswer(JSON.stringify({ words: old }), withContext);
  assert.deepEqual(fromObject, { full_text: "", words: [{ ...old[0], context_source: "photo" }] });
  // An unknown kind or a non-string full text falls back the same way.
  const odd = parseAnalyzeAnswer(JSON.stringify({ full_text: 3, words: [{ ...old[0], context_source: "book" }] }), withContext);
  assert.deepEqual(odd, { full_text: "", words: [{ ...old[0], context_source: "photo" }] });
});

test("T6: a word without its context, or no words list, is still refused", () => {
  assert.equal(parseAnalyzeAnswer(JSON.stringify({ full_text: "x", words: [{ word: "fog", translation: "t", description: "d" }] }), withContext), null);
  assert.equal(parseAnalyzeAnswer(JSON.stringify({ full_text: "x" }), withContext), null);
  assert.throws(() => parseAnalyzeAnswer("Here are the words: fog.", withContext));
});

test("T6: without context=true the answer is the plain words list, no full_text, no context_source", () => {
  const words = [{ word: "fog", translation: "туман", description: "Thick mist." }];
  assert.deepEqual(parseAnalyzeAnswer(JSON.stringify(words), withoutContext), { words });
  assert.equal(parseAnalyzeAnswer(JSON.stringify({ full_text: "", words }), withoutContext), null);
});
