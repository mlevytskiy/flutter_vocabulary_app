// The word check (spec AC-08): every word of a mnemonic story's group must appear in
// the story as written. A word counts as a whole word in any letter case; a phrase
// counts when its words appear in order, next to each other; each English word may
// carry the ending -s, -es, -ed or -ing. Anything else (a word inside another word,
// another form, a translation) does not count. Pure, so it runs anywhere.

const ENDINGS = ["", "s", "es", "ed", "ing"] as const;

/** Lower-cased words: runs of letters, digits and inner apostrophes. Other characters separate. */
function tokens(text: string): string[] {
  return (text.toLowerCase().match(/[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*/gu) ?? []);
}

/** Does this story token equal the word, or the word plus one allowed ending? */
function matches(token: string, word: string): boolean {
  return ENDINGS.some((ending) => token === word + ending);
}

function containsPhrase(story: readonly string[], phrase: readonly string[]): boolean {
  for (let start = 0; start + phrase.length <= story.length; start++) {
    if (phrase.every((word, i) => matches(story[start + i], word))) return true;
  }
  return false;
}

/** The group words the story does not contain under AC-08's rule, as given, in order. */
export function missedWords(story: string, words: readonly string[]): string[] {
  const storyTokens = tokens(story);
  return words.filter((word) => {
    const phrase = tokens(word);
    return phrase.length > 0 && !containsPhrase(storyTokens, phrase);
  });
}
