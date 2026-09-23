import type { SessionDocument, SessionSource } from "./types";

/**
 * Server-rendered HTML for the public page. No build step, no framework:
 * plain markup and inline CSS, written for a phone held in portrait. Every
 * value that came from a request goes through `escapeHtml` -- a word field
 * that renders as markup on a page handed to someone else is the obvious hole.
 */

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const STYLE = `
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body { margin: 0; font: 16px/1.45 -apple-system, "Segoe UI", Roboto, sans-serif;
         background: #fafafa; color: #1b1b1b; }
  main { max-width: 640px; margin: 0 auto; padding: 16px; }
  h1 { font-size: 1.4rem; margin: 0 0 4px; }
  h2 { font-size: 1.05rem; margin: 24px 0 8px; }
  .meta { color: #666; font-size: 0.9rem; margin: 0 0 16px; }
  table { width: 100%; border-collapse: collapse; background: #fff;
          border: 1px solid #ddd; border-radius: 6px; overflow: hidden; }
  th, td { padding: 10px 8px; text-align: left; vertical-align: top;
           border-bottom: 1px solid #e6e6e6; overflow-wrap: anywhere; }
  th { background: #eee; font-weight: 600; font-size: 0.9rem; }
  td.n { color: #888; width: 2.5em; text-align: right; }
  tr:last-child td { border-bottom: 0; }
  .actions { margin: 0 0 16px; }
  .btn { display: inline-block; padding: 10px 16px; border-radius: 6px; background: #2962ff;
         color: #fff; font-weight: 600; text-decoration: none; }
  .btn:active { background: #1e4fd6; }
  figure { margin: 0; }
  figure img { display: block; width: 100%; height: auto; border-radius: 6px; border: 1px solid #ddd; }
  .gone { text-align: center; padding: 48px 0; color: #444; }
  @media (prefers-color-scheme: dark) {
    body { background: #121212; color: #ececec; }
    table { background: #1c1c1c; border-color: #333; }
    th { background: #262626; }
    th, td { border-color: #2e2e2e; }
    .meta, td.n { color: #9a9a9a; }
    figure img { border-color: #333; }
    .gone { color: #ccc; }
  }
`;

function shell(title: string, body: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)}</title>
<style>${STYLE}</style>
</head>
<body>
<main>
${body}
</main>
</body>
</html>
`;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric" });
}

function renderSource(sessionId: string, source: SessionSource): string {
  switch (source.kind) {
    case "photo": {
      const src = `/s/${encodeURIComponent(sessionId)}/sources/${encodeURIComponent(source.id)}`;
      return `<figure><img src="${escapeHtml(src)}" alt="The photo these words were collected from" loading="lazy"></figure>`;
    }
    default:
      return "";
  }
}

export function renderSessionPage(doc: SessionDocument): string {
  const rows = doc.entries
    .map(
      (entry, i) =>
        `<tr><td class="n">${i + 1}</td><td>${escapeHtml(entry.word)}</td><td>${escapeHtml(entry.translation)}</td></tr>`
    )
    .join("\n");
  const count = doc.entries.length;
  const sources = doc.sources.map((s) => renderSource(doc.id, s)).filter((html) => html !== "");
  const sourcesHtml =
    sources.length > 0
      ? `<section><h2>${sources.length === 1 ? "Source" : "Sources"}</h2>\n${sources.join("\n")}\n</section>`
      : "";
  const body = `<h1>Vocabulary</h1>
<p class="meta">${count} ${count === 1 ? "word" : "words"} · published ${escapeHtml(formatDate(doc.createdAt))} · available until ${escapeHtml(formatDate(doc.expiresAt))}</p>
<p class="actions"><a class="btn" href="/s/${encodeURIComponent(doc.id)}/words.txt" download>Download for AnkiDroid</a></p>
<table>
<thead><tr><th>#</th><th>Word</th><th>Translation</th></tr></thead>
<tbody>
${rows}
</tbody>
</table>
${sourcesHtml}`;
  return shell(`Vocabulary — ${count} ${count === 1 ? "word" : "words"}`, body);
}

export function renderNotFoundPage(): string {
  return shell(
    "This word list is gone",
    `<div class="gone">
<h1>This word list is gone</h1>
<p>Shared lists stay up for 30 days. This one has expired, or the link is not quite right.</p>
</div>`
  );
}
