import { detailOf, type SessionDetail, type SessionDocument, type SessionEntry } from "./types";

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
 * Fixed columns in every mode (ADR-0005): word, translation, definition, tags.
 * The column the word detail mode hides is written empty, so a column never
 * changes meaning between exports.
 */
export function renderAnkiFile(entries: SessionEntry[], detail: SessionDetail = "translation"): string {
  const lines = ["#separator:tab", "#html:true", "#tags column:4"];
  const showTranslation = detail !== "definition";
  const showDefinition = detail !== "translation";
  for (const entry of entries) {
    const definition = entry.definition ?? "";
    // A record with every field blank is never written (the app keeps a
    // trailing empty row by design; it must not become an empty card).
    if (entry.word.trim() === "" && entry.translation.trim() === "" && definition.trim() === "") continue;
    const translationCell = showTranslation ? ankiField(entry.translation) : "";
    const definitionCell = showDefinition ? ankiField(definition) : "";
    lines.push(`${ankiField(entry.word)}\t${translationCell}\t${definitionCell}\t`);
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

export function renderAnkiFileFor(doc: SessionDocument): string {
  return renderAnkiFile(doc.entries, detailOf(doc));
}
