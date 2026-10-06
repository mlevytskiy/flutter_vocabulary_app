// The learn plan (ADR-0003): the single source of truth for which exercises exist, their
// stage and order, and which are available. The app's Dart copy is tested against
// exercises.json. Ids are frozen: they appear in web links and will key learning progress.
import data from "./exercises.json" with { type: "json" };

export interface Exercise {
  id: string;
  name: string;
  stage: 1 | 2 | 3;
  available: boolean;
}

/** All eleven exercises in plan order. */
export const EXERCISES: readonly Exercise[] = data as Exercise[];

/** The exercise with this id when it exists and is available; otherwise undefined. */
export function findAvailable(id: string): Exercise | undefined {
  return EXERCISES.find((e) => e.id === id && e.available);
}

/** A saved row as the learn page sees it. */
export interface LearnRow {
  word: string;
  translation: string;
  definition: string;
  deleted?: boolean;
}

/**
 * Is this row a "word to learn"? Same rule as the app's `WordPair.isFilled`: a non-blank
 * word plus a non-blank translation or definition, and the row not deleted.
 */
export function isWordToLearn(row: LearnRow): boolean {
  if (row.deleted) return false;
  return (
    row.word.trim().length > 0 &&
    (row.translation.trim().length > 0 || row.definition.trim().length > 0)
  );
}
