// The learn plan and the word-to-learn rule (learn-part-step-1 T1, AC-04, AC-08b).
// Pure unit tests: no Worker needed (Node strips the TypeScript types on import).
import assert from "node:assert/strict";
import { test } from "node:test";
import { EXERCISES, findAvailable, isWordToLearn } from "../src/learn/exercises.ts";

test("learn-kit S-02, AC-01: the plan has the thirteen exercises in order, with their stages and names", () => {
  assert.deepEqual(
    EXERCISES.map((e) => [e.id, e.name, e.stage]),
    [
      ["mnemonic-story", "Mnemonic story", 1],
      ["dialogs-from-movie", "Dialogs from movie", 1],
      ["match-synonyms", "Match synonyms", 1],
      ["match-definitions", "Match word and definition", 1],
      ["guess-my-word", "Guess my word", 1],
      ["pick-the-answer", "Pick the right answer", 1],
      ["fill-the-gaps", "Fill the gaps", 2],
      ["remember-or-not", "Remember or not", 2],
      ["sentence-patterns", "Sentence patterns", 2],
      ["own-sentences", "Make your own sentences", 3],
      ["translate-sentences", "Translate sentences", 3],
      ["explain-to-friend", "Explain it to a friend", 3],
      ["quiz", "Quiz", 3],
    ],
  );
});

test("learn-kit S-02: the removed and cancelled exercises are gone", () => {
  for (const id of ["match-antonyms", "own-sentences-spoken", "translate-sentences-spoken", "chain-story"]) {
    assert.equal(EXERCISES.some((e) => e.id === id), false, id);
    assert.equal(findAvailable(id), undefined, id);
  }
});

test("every entry has exactly id, name, stage and available", () => {
  for (const e of EXERCISES) {
    assert.deepEqual(Object.keys(e).sort(), ["available", "id", "name", "stage"]);
  }
});

test("only mnemonic-story, dialogs-from-movie, match-synonyms, pick-the-answer and remember-or-not are available", () => {
  assert.deepEqual(EXERCISES.filter((e) => e.available).map((e) => e.id), ["mnemonic-story", "dialogs-from-movie", "match-synonyms", "pick-the-answer", "remember-or-not"]);
  assert.equal(findAvailable("match-synonyms")?.name, "Match synonyms");
  assert.equal(findAvailable("remember-or-not")?.name, "Remember or not");
  assert.equal(findAvailable("pick-the-answer")?.name, "Pick the right answer");
  assert.equal(findAvailable("mnemonic-story")?.name, "Mnemonic story");
  assert.equal(findAvailable("dialogs-from-movie")?.name, "Dialogs from movie");
  assert.equal(findAvailable("quiz"), undefined);
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
