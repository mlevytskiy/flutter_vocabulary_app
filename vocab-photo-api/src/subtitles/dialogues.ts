/**
 * The check on the dialogues of a subtitle reply (get-words-from-subtitles-improvment
 * AC-04, AC-05; sad §4 choice 2, sad §8). Pure: it keeps only what can be trusted and
 * never fails the import. Matching is the story word check's rule (`matchPlaces`).
 */
import { matchPlaces } from "../story/word-check.ts";

/** A dialogue as the model returns it. */
export interface RawDialogue {
  lines: string[];
  words: string[];
}

/** A dialogue that passed the check: every word appears in at least one line. */
export interface CheckedDialogue {
  lines: string[];
  /** The kept words' own spelling, each once, in the order the model linked them. */
  words: string[];
}

export const MAX_DIALOGUES = 10;
export const MAX_DIALOGUE_LINES = 8;
export const MAX_DIALOGUE_LINE_LENGTH = 200;

const key = (word: string) => word.trim().toLowerCase();

/**
 * Drops links to words that are not kept, unlinks words that appear in none of the
 * dialogue's lines (checked line by line, so a phrase never spans two lines), drops
 * dialogues over 8 lines, with a line over 200 characters, or left without words, and
 * keeps the first 10 of the rest. A word may stay linked to several dialogues (AC-06).
 */
export function checkDialogues(dialogues: readonly RawDialogue[], keptWords: readonly { word: string }[]): CheckedDialogue[] {
  const kept = new Map<string, string>();
  for (const { word } of keptWords) if (!kept.has(key(word))) kept.set(key(word), word);

  const out: CheckedDialogue[] = [];
  for (const { lines, words } of dialogues) {
    if (lines.length === 0 || lines.length > MAX_DIALOGUE_LINES) continue;
    if (lines.some((line) => line.length > MAX_DIALOGUE_LINE_LENGTH)) continue;

    const linked: string[] = [];
    for (const name of words) {
      const own = kept.get(key(name));
      if (own === undefined || linked.includes(own)) continue;
      if (lines.some((line) => matchPlaces(line, own).length > 0)) linked.push(own);
    }
    if (linked.length === 0) continue;

    out.push({ lines: [...lines], words: linked });
    if (out.length === MAX_DIALOGUES) break;
  }
  return out;
}
