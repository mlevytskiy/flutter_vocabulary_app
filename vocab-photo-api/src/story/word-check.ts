// The word check (spec AC-08): every word of a mnemonic story's group must appear in
// the story as written. A word counts as a whole word in any letter case; a phrase
// counts when its words appear in order, next to each other; each English word may
// carry the ending -s, -es, -ed or -ing. Anything else (a word inside another word,
// another form, a translation) does not count. Pure, so it runs anywhere.

const ENDINGS = ["", "s", "es", "ed", "ing"] as const;

interface Token {
  /** Lower-cased text, for comparing. */
  text: string;
  /** Where the token sits in the original text: UTF-16 code units, [start, end). */
  start: number;
  end: number;
}

/** Words: runs of letters, digits and inner apostrophes. Other characters separate. */
function tokenize(text: string): Token[] {
  const found: Token[] = [];
  for (const m of text.matchAll(/[\p{L}\p{N}]+(?:['\u2019][\p{L}\p{N}]+)*/gu)) {
    found.push({ text: m[0].toLowerCase(), start: m.index, end: m.index + m[0].length });
  }
  return found;
}

/** Does this story token equal the word, or the word plus one allowed ending? */
function matches(token: string, word: string): boolean {
  return ENDINGS.some((ending) => token === word + ending);
}

function phraseAt(story: readonly Token[], start: number, phrase: readonly Token[]): boolean {
  return start + phrase.length <= story.length && phrase.every((word, i) => matches(story[start + i].text, word.text));
}

/**
 * Every place the word (or phrase) appears in the text under AC-08/AC-05's rule, as
 * [start, end) in UTF-16 code units, in text order, without overlap. Empty when the
 * word is blank or absent. Pinned by match-cases.json, which the Dart port reads too.
 */
export function matchPlaces(text: string, word: string): [number, number][] {
  const phrase = tokenize(word);
  const story = tokenize(text);
  const places: [number, number][] = [];
  if (phrase.length === 0) return places;
  for (let start = 0; start < story.length; ) {
    if (phraseAt(story, start, phrase)) {
      places.push([story[start].start, story[start + phrase.length - 1].end]);
      start += phrase.length;
    } else {
      start++;
    }
  }
  return places;
}

/** The group words the story does not contain under AC-08's rule, as given, in order. */
export function missedWords(story: string, words: readonly string[]): string[] {
  return words.filter((word) => tokenize(word).length > 0 && matchPlaces(story, word).length === 0);
}
