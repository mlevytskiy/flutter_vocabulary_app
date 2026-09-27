import type { SessionDocument, SessionEntry } from "./types";

/**
 * The AnkiDroid import file. The SAME format lives in the app
 * (`lib/features/words_table/anki_export.dart`); both follow the spec in
 * `vocab-photo-api/README.md` § "AnkiDroid file format". Change one, change
 * the other, and update the spec -- a silently diverging import format is a
 * bug found weeks later, inside Anki.
 *
 * `#html:true` tells Anki to parse field content as HTML, so `&`, `<` and `>`
 * are escaped as entities: a word containing `<b>` must show up as those
 * characters, not as bold. Tabs and newlines inside a field would shift columns
 * or split the record, so any run of them collapses to one space.
 */

export function ankiField(value: string): string {
  return value
    .replace(/[\t\r\n]+/g, " ")
    .trim()
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

/**
 * Fixed columns (definition-mode ADR-0005): word, translation, definition,
 * tags. The page's file carries what the page saved (good-looking-web AC-30):
 * every stored translation and definition, whatever mode the learner
 * published with, so a column with no text anywhere -- collapsed on the page --
 * comes out empty in its place. A card needs a word: a row whose word is
 * blank, including a row whose cells were all cleared, is left out (AC-31).
 */
export function renderAnkiFile(entries: SessionEntry[]): string {
  const lines = ["#separator:tab", "#html:true", "#tags column:4"];
  for (const entry of entries) {
    const word = ankiField(entry.word);
    if (word === "") continue;
    lines.push(`${word}\t${ankiField(entry.translation)}\t${ankiField(entry.definition ?? "")}\t`);
  }
  return lines.join("\n") + "\n";
}

/** `vocabulary_<YYYY-MM-DD>.txt`, the app's own naming (`anki_export.dart`). */
export function ankiFileName(now: Date): string {
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  return `vocabulary_${y}-${m}-${d}.txt`;
}

/** The file for a session's live rows, in table order (read from D1 at request time). */
export function renderAnkiFileFor(doc: SessionDocument): string {
  return renderAnkiFile(doc.entries);
}
