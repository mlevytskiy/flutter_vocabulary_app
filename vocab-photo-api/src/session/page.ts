import { STYLE } from "./style";
import { MAX_ENTRIES, type StoredRow, type StoredSession, type StoredSource } from "./types";

/**
 * Server-rendered HTML for the public page (ADR-0002). The table is complete
 * and readable before the browser script (src/session/client/page.js) runs;
 * the script only adds editing and the rest on top. Every value that came
 * from a request goes through `escapeHtml` -- a word field that renders as
 * markup on a page handed to someone else is the obvious hole (AC-33).
 *
 * The data the script needs rides on attributes: the session and its
 * revision on <main>, the row id and source photo on <tr>, the field and
 * its revision on <td>. Cell text sits in `<div class="v">` with
 * `white-space: pre-wrap`, so a definition keeps its line break and the
 * script reads back exactly the stored text.
 */

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function shell(title: string, body: string, scriptPath?: string): string {
  const script = scriptPath ? `\n<script type="module" src="${escapeHtml(scriptPath)}"></script>` : "";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)}</title>
<style>${STYLE}</style>${script}
</head>
<body>
${body}
</body>
</html>
`;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
}

/** `28.10.2026`: the short date of the phone layout's meta line. */
function formatShortDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const two = (n: number) => String(n).padStart(2, "0");
  return `${two(d.getUTCDate())}.${two(d.getUTCMonth() + 1)}.${d.getUTCFullYear()}`;
}

type Field = "word" | "translation" | "definition";

const FIELD_TITLES: Record<Field, string> = { word: "Word", translation: "Translation", definition: "Definition" };

/**
 * Translation and Definition show when any row holds text in them; an
 * all-empty one collapses to a narrow "add" control (AC-21, AC-22, AC-27).
 * The page decides from the data, not from the learner's word detail mode.
 */
function collapsedColumns(session: StoredSession): Field[] {
  const fields: Field[] = ["translation", "definition"];
  return fields.filter((field) => session.rows.every((row) => row[field] === ""));
}

function sourceUrl(sessionId: string, sourceId: string): string {
  return `/s/${encodeURIComponent(sessionId)}/sources/${encodeURIComponent(sourceId)}`;
}

/** A card needs a word: the download leaves out a row whose word is blank (AC-31). */
function needsWord(row: StoredRow): boolean {
  return row.word.trim() === "";
}

function renderCell(row: StoredRow, field: Field): string {
  const rev = field === "word" ? row.wordRev : field === "translation" ? row.translationRev : row.definitionRev;
  const mark =
    field === "word" ? `<p class="needs-word-mark">not in the download — needs a word</p>` : "";
  return `<td class="c-${field}" data-field="${field}" data-rev="${rev}"><div class="v">${escapeHtml(row[field])}</div>${mark}</td>`;
}

function renderRow(row: StoredRow): string {
  const source = row.sourceId !== null ? ` data-source="${escapeHtml(row.sourceId)}"` : "";
  const cls = needsWord(row) ? ` class="needs-word"` : "";
  // The number itself is a CSS counter, so added and hidden rows renumber by themselves.
  const number = `<td class="n"><button type="button" class="del" aria-label="Delete this row">×</button></td>`;
  return `<tr data-row="${escapeHtml(row.id)}"${source}${cls}>${number}${renderCell(row, "word")}${renderCell(row, "translation")}${renderCell(row, "definition")}</tr>`;
}

/** The row the plus button adds (AC-13): the script clones it and gives it an id. */
const BLANK_ROW: StoredRow = {
  id: "",
  position: 0,
  sourceId: null,
  word: "",
  wordRev: 0,
  translation: "",
  translationRev: 0,
  definition: "",
  definitionRev: 0,
};

function renderBlankRow(): string {
  return `<template id="blank-row">${renderRow(BLANK_ROW).replace(` class="needs-word"`, "")}</template>`;
}

function renderHeader(field: Field, collapsed: boolean): string {
  const title = FIELD_TITLES[field];
  const content = collapsed
    ? `<button type="button" class="add-col" data-open="${field}" aria-label="Add ${title}">+ ${title}</button>`
    : title;
  return `<th class="c-${field}" scope="col">${content}</th>`;
}

/**
 * The photo pager (wide layout) and the phone's photo dialog, from the
 * declared slots in order. A slot whose bytes never arrived is an empty
 * placeholder in its place. No slots (none declared, or "include photos"
 * off) renders neither (AC-08, AC-24, AC-26). The pager's arrows and the
 * phone's photo dialog (AC-05, AC-07) are wired by the script, which fills
 * the dialog's strip from the pager's slides when it opens.
 */
function renderPhotos(session: StoredSession): string {
  const slots = [...session.sources].sort((a, b) => a.ord - b.ord);
  if (slots.length === 0) return "";
  const total = slots.length;
  const slide = (slot: StoredSource, i: number): string => {
    const position = `${i + 1} of ${total}`;
    const picture =
      slot.status === "arrived"
        ? `<img src="${escapeHtml(sourceUrl(session.id, slot.id))}" alt="Source photo ${position}" loading="lazy">`
        : `<div class="placeholder" role="img" aria-label="Source photo ${position}, not available">Photo not available</div>`;
    return `<figure class="slide" data-source="${escapeHtml(slot.id)}">${picture}<figcaption>${position}</figcaption></figure>`;
  };
  return `<aside class="photos" aria-label="Source photos">
<div class="pager-track" tabindex="0" aria-label="Source photos, use the arrow keys to move">
${slots.map(slide).join("\n")}
</div>
<div class="pager-nav" hidden><button type="button" data-pager="prev" aria-label="Previous photo">‹</button><button type="button" data-pager="next" aria-label="Next photo">›</button></div>
</aside>
<dialog class="photo-dialog" aria-label="Source photos">
<div class="dialog-bar"><button type="button" data-dialog="prev" aria-label="Previous photo">‹</button><span class="dialog-count" aria-live="polite"></span><button type="button" data-dialog="next" aria-label="Next photo">›</button><button type="button" data-dialog="close" aria-label="Close the photos">×</button></div>
<div class="dialog-view"><div class="dialog-strip"></div></div>
</dialog>`;
}

/**
 * The phone layout's photo button, next to the download link: up to three
 * stacked thumbnails that open the photo dialog. Nothing without slots.
 */
function renderPhotoButton(session: StoredSession): string {
  const slots = [...session.sources].sort((a, b) => a.ord - b.ord);
  if (slots.length === 0) return "";
  const total = slots.length;
  const thumbs = slots
    .slice(0, 3)
    .map((slot) =>
      slot.status === "arrived"
        ? `<img class="thumb" src="${escapeHtml(sourceUrl(session.id, slot.id))}" alt="" loading="lazy">`
        : `<span class="thumb"></span>`
    )
    .join("");
  const label = total === 1 ? "Show the source photo" : `Show the ${total} source photos`;
  return `<button type="button" class="photo-button${total > 1 ? " stack" : ""}" aria-label="${label}">${thumbs}</button>`;
}

export function renderSessionPage(session: StoredSession, scriptPath: string): string {
  const collapsed = collapsedColumns(session);
  const count = session.rows.length;
  const words = `${count} ${count === 1 ? "word" : "words"}`;
  const photos = renderPhotos(session);
  const classes = [photos ? "has-photos" : "", ...collapsed.map((field) => `no-${field}`)].filter((c) => c !== "");
  const head = (["word", "translation", "definition"] as Field[])
    .map((field) => renderHeader(field, collapsed.includes(field)))
    .join("");
  const body = `<main data-session="${escapeHtml(session.id)}" data-rev="${session.rev}" data-max-rows="${MAX_ENTRIES}"${classes.length > 0 ? ` class="${classes.join(" ")}"` : ""}>
<header class="title"><h1>Vocabulary</h1><span class="meta-short">${words} · available until ${escapeHtml(formatShortDate(session.expiresAt))}</span></header>
<p class="meta">${words} · published ${escapeHtml(formatDate(session.createdAt))} · available until ${escapeHtml(formatDate(session.expiresAt))}</p>
<p class="actions"><a class="btn" href="/s/${encodeURIComponent(session.id)}/words.txt" download>Download for AnkiDroid</a>${renderPhotoButton(session)}</p>
<div class="layout">
<div class="table-area">
<div class="table-scroll">
<table>
<thead><tr><th class="n" scope="col">#</th>${head}</tr></thead>
<tbody>
${session.rows.map(renderRow).join("\n")}
</tbody>
</table>
${renderBlankRow()}
</div>
<p class="add-row"><button type="button" class="add">+ Add a word</button></p>
<p class="credit">Definitions: Merriam-Webster</p>
</div>
${photos}
</div>
<div class="toasts" aria-live="polite"></div>
</main>`;
  return shell(`Vocabulary — ${count} ${count === 1 ? "word" : "words"}`, body, scriptPath);
}

export function renderNotFoundPage(): string {
  return shell(
    "This word list is gone",
    `<main>
<div class="gone">
<h1>This word list is gone</h1>
<p>Shared lists stay up for 30 days. This one has expired, or the link is not quite right.</p>
</div>
</main>`
  );
}
