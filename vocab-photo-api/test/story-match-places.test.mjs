// get-words-from-subtitles-improvment T2: where each word appears (AC-05, AC-06, AC-11),
// pinned by the case file the Dart port also reads. Pure unit tests.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { matchPlaces, missedWords } from "../src/story/word-check.ts";

const { cases } = JSON.parse(readFileSync(new URL("../src/story/match-cases.json", import.meta.url), "utf8"));

for (const c of cases) {
  test(`matchPlaces: ${c.name}`, () => {
    assert.deepEqual(matchPlaces(c.text, c.word), c.places);
  });
}

test("the case file agrees with missedWords", () => {
  for (const c of cases) {
    const missed = missedWords(c.text, [c.word]).length > 0;
    const blank = c.word.trim() === "";
    assert.equal(missed, !blank && c.places.length === 0, c.name);
  }
});
