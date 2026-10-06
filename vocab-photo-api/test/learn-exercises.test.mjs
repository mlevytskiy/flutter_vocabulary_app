// The learn plan and the word-to-learn rule (learn-part-step-1 T1, AC-04, AC-08b).
// Pure unit tests: no Worker needed (Node strips the TypeScript types on import).
import assert from "node:assert/strict";
import { test } from "node:test";
import { EXERCISES, findAvailable, isWordToLearn } from "../src/learn/exercises.ts";

test("the plan has the eleven exercises of AC-04 in order, with their stages and names", () => {
  assert.deepEqual(
    EXERCISES.map((e) => [e.id, e.name, e.stage]),
    [
      ["mnemonic-story", "Mnemonic story", 1],
      ["match-synonyms", "Match synonyms", 1],
      ["match-antonyms", "Match antonyms", 1],
      ["match-definitions", "Match word and definition", 1],
      ["pick-the-answer", "Pick the right answer", 2],
      ["fill-the-gaps", "Fill the gaps", 2],
      ["remember-or-not", "Remember or not", 2],
      ["own-sentences", "Make your own sentences", 3],
      ["translate-sentences", "Translate sentences", 3],
      ["own-sentences-spoken", "Make your own sentences (speak)", 3],
      ["translate-sentences-spoken", "Translate sentences (speak)", 3],
    ],
  );
});

test("every entry has exactly id, name, stage and available", () => {
  for (const e of EXERCISES) {
    assert.deepEqual(Object.keys(e).sort(), ["available", "id", "name", "stage"]);
  }
});

test("only mnemonic-story is available", () => {
  assert.deepEqual(EXERCISES.filter((e) => e.available).map((e) => e.id), ["mnemonic-story"]);
  assert.equal(findAvailable("mnemonic-story")?.name, "Mnemonic story");
  assert.equal(findAvailable("match-synonyms"), undefined);
  assert.equal(findAvailable("nope"), undefined);
});

const row = (word, translation, definition, extra = {}) => ({ word, translation, definition, ...extra });

test("a word to learn needs a word plus a translation or a definition", () => {
  assert.equal(isWordToLearn(row("apple", "яблуко", "")), true);
  assert.equal(isWordToLearn(row("apple", "", "a fruit")), true);
  assert.equal(isWordToLearn(row("apple", "яблуко", "a fruit")), true);
});

test("a blank word or whitespace-only translation and definition is not a word to learn", () => {
  assert.equal(isWordToLearn(row("", "яблуко", "a fruit")), false);
  assert.equal(isWordToLearn(row("   ", "яблуко", "")), false);
  assert.equal(isWordToLearn(row("apple", "  ", "\t ")), false);
  assert.equal(isWordToLearn(row("apple", "", "")), false);
});

test("a deleted row is not a word to learn", () => {
  assert.equal(isWordToLearn(row("apple", "яблуко", "", { deleted: true })), false);
});
