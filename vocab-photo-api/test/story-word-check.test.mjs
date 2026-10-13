// mnemonic-story T3: the word check every story must pass (AC-08). Pure unit tests:
// no Worker needed (Node strips the TypeScript types on import).
import assert from "node:assert/strict";
import { test } from "node:test";
import { missedWords } from "../src/story/word-check.ts";

test("a word present as a whole word is not missed; an absent one is", () => {
  assert.deepEqual(missedWords("Він бачить tide і тікає", ["tide", "harbour"]), ["harbour"]);
});

test("letter case does not matter, in the story or in the word", () => {
  assert.deepEqual(missedWords("TIDE rises. Harbour is calm.", ["tide", "HARBOUR"]), []);
});

test("a phrase counts when its words are in order and next to each other", () => {
  assert.deepEqual(missedWords("Ти live up to очікувань", ["live up to"]), []);
  assert.deepEqual(missedWords("Ти live очікувань up to", ["live up to"]), ["live up to"]);
  assert.deepEqual(missedWords("Ти up live to очікувань", ["live up to"]), ["live up to"]);
  assert.deepEqual(missedWords("Ти live, потім up to", ["live up to"]), ["live up to"]);
});

test("each English word may carry -s, -es, -ed or -ing", () => {
  assert.deepEqual(missedWords("he walks", ["walk"]), []);
  assert.deepEqual(missedWords("she watches", ["watch"]), []);
  assert.deepEqual(missedWords("they walked", ["walk"]), []);
  assert.deepEqual(missedWords("we are walking", ["walk"]), []);
});

test("other forms and translations do not count", () => {
  assert.deepEqual(missedWords("he tackled it", ["tackle"]), ["tackle"]);
  assert.deepEqual(missedWords("running fast", ["run"]), ["run"]);
  assert.deepEqual(missedWords("he walker", ["walk"]), ["walk"]);
  assert.deepEqual(missedWords("він ходить", ["walk"]), ["walk"]);
});

test("\"veers off\" counts for \"veer off\"", () => {
  assert.deepEqual(missedWords("він пугається і veers off з дороги", ["veer off"]), []);
});

test("\"live\" inside \"deliver\" does not count", () => {
  assert.deepEqual(missedWords("Вони deliver пошту", ["live"]), ["live"]);
  assert.deepEqual(missedWords("Вони olive та lives", ["live"]), []);
  assert.deepEqual(missedWords("Вони olive", ["live"]), ["live"]);
});

test("the missed words come back as given, in the group's order", () => {
  assert.deepEqual(missedWords("only fog", ["Tide", "fog", "rope"]), ["Tide", "rope"]);
});

test("the owner's sample story contains all of its words", () => {
  const story =
    "Вы tackle огромную проблему-монстра → карабкаетесь вверх, чтобы live up to планки ожиданий → цепляетесь за неё как tenacious осьминог → ваш determined компас всё равно показывает вперёд → in a pinch вы используете запасную лестницу → наверху сидит one-finger typer и одним пальцем стучит по клавиатуре → spell check подчёркивает его ошибку красным → он пугается и veers off с дороги → встречает очень chatty рекрутера → и сообщает ему, что willing to relocate, показывая уже собранный чемодан.";
  const words = ["tackle", "live up to", "tenacious", "determined", "in a pinch", "one-finger", "typer", "spell check", "veer off", "chatty", "willing to relocate"];
  assert.deepEqual(missedWords(story, words), []);
  assert.deepEqual(missedWords(story, [...words, "harbour"]), ["harbour"]);
});

test("a blank word is never missed", () => {
  assert.deepEqual(missedWords("anything", ["  ", ""]), []);
});
