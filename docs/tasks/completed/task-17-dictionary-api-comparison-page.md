# Task 17 — Static comparison page

|  |  |
|---|---|
| **Roadmap step** | [#9](../../roadmap.md#steps) |
| **Size** | M |
| **Wave** | 7 |
| **Depends on** | **task-15** (data), **task-16** (results shape) |
| **Blocked on** | — |
| **Unlocks** | task-18 |
| **Files** | `investigations/dictionary-apis/src/build.mjs` (new) · `investigations/dictionary-apis/src/page/template.html` (new) · `investigations/dictionary-apis/index.html` (generated) |
| **Status** | **done 2026-09-27** — AC-1..AC-5 verified |

## The report

> Web-page where I can see small description about each dictionary, table with info about how much cost to use them and table with info about 10 words that we try to get from them. ... Column in the table: word, definition, pronunciation British, pronunciation American, pronunciation B response time, pronunciation A response time, definition response time. We should simplify the naming of columns to use less space. For example for pronunciation British we can use pronunciation {British flag}, instead of "response time" just "t".

One self-contained HTML page with three parts: (1) a short description block per dictionary, (2) a cost/limits table across all dictionaries, (3) a 10-word results table **per dictionary**, with compact headers.

## What is already there

No web tooling in the repo. `providers.json` (task-15) holds descriptions and cost; `out/results.json` (task-16) holds, per provider×word: `definitions[]`, `senseCount`, `audio.{brE,amE}`, `ms`, and the three times. Node v23 can read both and write a single HTML file with no bundler.

## What it should do instead

A zero-build page: `build.mjs` reads `providers.json` + `results.json`, renders `src/page/template.html` into a top-level `index.html`, and `npm run serve` (`python3 -m http.server`, already available) shows it. No framework, no Vite, no CDN — matching the repo's no-toolchain style.

**Compact column headers (the owner's explicit requirement).** The ten-word table, one per dictionary:

| Word | Definition | 🔊🇬🇧 | 🔊🇺🇸 | 🇬🇧 t | 🇺🇸 t | def t |
|---|---|---|---|---|---|---|

- `🔊🇬🇧` / `🔊🇺🇸` = British / American pronunciation — a play-link when audio exists, `—` when the API doesn't return it, `n/a` when the API offers no such dialect at all.
- `🇬🇧 t` / `🇺🇸 t` / `def t` = response times in ms (the owner's "instead of response time just t").
- Keep the header row sticky, widths narrow so the whole table fits without horizontal scroll on a laptop.

Three sections in order: **Descriptions** (one short paragraph + docs link + registration badge per dictionary) → **Cost & limits** (Free tier · Paid · Key · Registration columns, from `providers.json`) → **Results** (one collapsible table per dictionary, plus a "considered and rejected" list at the end). Audio cells carry an inline `<audio>` or a link to the MP3 URL — no autoplay.

## Prompt

Read `CLAUDE.md`, `docs/tasks/completed/task-15-*.md`, `docs/tasks/completed/task-16-*.md`. One commit.

1. **`src/page/template.html`** — the page skeleton + a tiny inline `<style>` (system font, sticky header, monospace numbers, flag emojis in headers). Placeholder markers where the three tables go.
2. **`src/build.mjs`** — read `data/providers.json` and `out/results.json`, escape all text (the definitions come from third-party HTML — strip and escape, never inject raw), and write `index.html`. If `out/results.json` is missing, still render descriptions + cost with the results tables showing a "run `npm run probe`" note.
3. **Render the cost table** straight from `providers.json` — columns: Provider · Free tier · Paid · Key · Registration. Manual-approval providers get a visible badge.
4. **Render one results table per probeable dictionary** with the compact header set above; fill audio/timing cells from `results.json`; show `—`/`n/a`/status codes honestly (no blank cells that could read as zero).
5. **`npm run build`** writes `index.html`; `npm run serve` serves the folder. Both wired in `package.json`.
6. **No app/Worker changes.**

## Acceptance criteria

- [x] **AC-1** `npm run build` produces `investigations/dictionary-apis/index.html` that opens in a browser with the three sections present.
- [x] **AC-2** Headers are the compact forms: `🔊🇬🇧`, `🔊🇺🇸`, `🇬🇧 t`, `🇺🇸 t`, `def t` — no cell says "response time".
- [x] **AC-3** Each dictionary has its own 10-word table; a dictionary missing a BrE audio URL shows `—`/`n/a`, not a broken player.
- [x] **AC-4** Definitions from third-party HTML render as plain text (no raw `<a>`/markup leaks onto the page).
- [x] **AC-5** With `out/results.json` deleted, the build still succeeds and the page shows the "run `npm run probe`" note.

## Open points

- Flag emoji rendering varies by OS/browser; a text fallback (`BrE`/`AmE` in a tooltip via `title=`) covers systems without emoji fonts. Confirm with the owner if the emojis must be images instead.
- Rows for providers that returned all errors (e.g. dictionaryapi.dev while 522) — show the status code, and consider a small "sources-with-issues" callout at the top.

## Implementation notes (2026-09-27)

- `npm run build` renders `index.html`. `npm run serve` runs `python3 -m http.server 8000`. The page has no CDN, framework or JS; it has light and dark themes via `prefers-color-scheme`.
- AC-1/AC-3 were checked in Chrome. The three sections render, and each probeable dictionary has its own collapsible 10-word table. Tables with data start open, skipped and all-failed ones start collapsed. Merriam-Webster shows `n/a` under 🔊🇬🇧 because the API has no BrE, and `—` for the two words without audio.
- AC-2: `grep -i "response time" index.html` finds nothing. Headers carry a `title=` text fallback ("British pronunciation (BrE)" and similar) for systems without flag emoji.
- AC-4: every definition goes through `stripHtml` and is then escaped. `grep '&lt;[a-z/]' index.html` finds nothing.
- AC-5: with `out/results.json` moved away, the build succeeds and shows the "run `npm run probe`" note.
- The time cells are bare numbers (the legend says they are ms). Each table summary line gives words defined, median def t, failures and audio counts. An all-failed provider (dictionaryapi.dev) gets a "Sources with issues" callout at the top. Skipped rows read "skipped: no key", never 0 ms.
