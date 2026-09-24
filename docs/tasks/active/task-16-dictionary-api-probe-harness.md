# Task 16 — Probe harness: fetch, measure, record

|  |  |
|---|---|
| **Roadmap step** | [#9](../../roadmap.md#steps) |
| **Size** | M |
| **Wave** | 7 |
| **Depends on** | **task-14**, **task-15** |
| **Blocked on** | — (keyless providers fully testable; keyed ones degrade gracefully to `skipped`) |
| **Unlocks** | task-18 |
| **Files** | `investigations/dictionary-apis/src/probe.mjs` (new) · `investigations/dictionary-apis/src/providers/*.mjs` (new, one adapter per provider) · `investigations/dictionary-apis/out/results.json` (generated) |
| **Status** | **done 2026-09-24** — AC-1..AC-4 verified (keyed adapters unverified until keys exist) |

## The report

> ... table with info about 10 words that we try to get from them. ... Column in the table: word, definition, pronunciation British, pronunciation American, pronunciation B response time, pronunciation A response time, definition response time.

A script that asks every probeable provider for all ten words and records, per word: the definition text and how many senses came back, whether BrE and AmE pronunciation audio came back, and **how long each call took**. Output is a JSON file the page renders — the numbers must be measured, never estimated.

## What is already there

`data/words.json` (task-14) and `data/providers.json` (task-15) exist. Node v23 is present, so `fetch` is built in — no HTTP dependency needed. The keyless providers (dictionaryapi.dev, datamuse, Wiktionary REST) need no key; the rest read their key from process env (loaded from the gitignored `.env` in task-14) and, when a key is missing, must record the provider as `skipped: "no key"` rather than crashing.

Known shape facts from the earlier probe: datamuse returns `defs` (tab-separated, first line `adj\t…`) and ARPAbet in `tags` (`pron:…`), **no audio**. Wiktionary REST returns `en[].definitions[].definition` wrapped in anchor HTML that must be stripped, no reliable audio. dictionaryapi.dev returns `meanings[].definitions[]` plus `phonetics[].audio`, with `-gb`/`-us` in the filenames when both dialects exist.

## What it should do instead

One adapter per provider behind a common `probe(word) -> { definitions: string[], senseCount, audio: { brE, amE }, ms }` shape. The runner loops providers × words, times each `fetch` with `performance.now()` around the awaited call, tolerates non-200 (records the status code and treats audio/defs as absent), and writes `out/results.json` keyed by provider id then word id. Three timed columns are captured separately where the API allows: the definition call time, and — for APIs whose audio is a *separate* request (none of the keyless three, but MW/Oxford/Cambridge serve audio from a CDN URL that is fetched) — the BrE and AmE audio fetch times. For APIs that return audio URLs inline in the definition response, the audio time is recorded as the audio-URL fetch, measured separately, so the "definition response time" stays clean.

## Prompt

Read `CLAUDE.md`, `docs/tasks/active/task-14-*.md`, `docs/tasks/active/task-15-*.md`. One commit.

1. **`src/providers/<id>.mjs`** — one module per probeable provider exporting `id` and `probe(word)`. Start with the three keyless ones (they are fully testable today); add adapter stubs for the keyed ones that return `skipped` when their env key is absent. Strip HTML from Wiktionary definitions; normalise datamuse's `defs` into plain strings.
2. **`src/probe.mjs`** — the runner. Read `data/words.json` and `data/providers.json`, skip `excluded` and `!probeable`, loop, time each call with `performance.now()`, catch every error per (provider, word) so one failure never aborts the run, and write `out/results.json`.
3. **Time honestly.** The recorded `ms` is wall-clock around the awaited `fetch`. Note in the output that the first call to a host pays DNS/TLS, so the task-18 run should warm each host once before measurement (add a `--warm` flag).
4. **Record failures as data.** A 522/404/timeout becomes `{ status, error }` in the result for that word — the page shows it (e.g. dictionaryapi.dev's current 522 is a real row, not a blank).
5. **`npm run probe`** wired in `package.json`; `out/` stays gitignored.
6. **No page work** — task-17 renders this file; do not build HTML here.

## Acceptance criteria

- [x] **AC-1** `npm run probe` exits 0 with a valid `.env` absent (keyless providers fully probed; keyed providers recorded as `skipped: "no key"`), and writes `out/results.json`.
- [x] **AC-2** `out/results.json` has an entry for every non-excluded, probeable provider × each of the ten words, each with `ms` (a number) and either `definitions` or a `status`/`error`.
- [x] **AC-3** Re-running with `--warm` warms each host before timing; a second run's `ms` values are visibly lower for at least one provider (documented, not asserted strictly).
- [x] **AC-4** Simulating a failure (a bogus provider URL) leaves the other providers' results intact — one failure does not abort the run.

## Open points

- Separating BrE vs AmE timing is only meaningful for APIs that expose two distinct audio URLs; for single-audio APIs both columns will hold the same number or one will be `n/a`. The page must show that honestly.
- Merriam-Webster requires constructing the audio URL from an `audio` filename; the adapter does that, but it needs a real key to verify — deferred to task-18.

## Implementation notes (2026-09-24)

- **Result row shape:** `{ word, ms, status, definitions, senseCount, audio: { brE, amE } }`. Each audio value is `null` or `{ url, ms, status, bytes | error }`. Optional fields: `otherAudio` (audio URLs with no dialect marker) and `extra` (Datamuse `arpabet`, WordsAPI `ipa`, Merriam-Webster `suggestions`). Failures are `{ word, ms, status, error }`, where `status` is an HTTP code, `"timeout"`, `"network-error"`, `"adapter-error"` or `"no-adapter"`. Skipped rows are `{ word, ms: 0, status: "skipped", skipped: "no key" }`. The `ms: 0` satisfies AC-2's "a number", but the page must show these rows as *skipped*, not as 0 ms.
- **Verification runs (no `.env`):**
  - AC-1: `npm run probe` exited 0 after 3 min 23 s. dictionaryapi.dev returned **HTTP 522 on all ten words, ≈19.5 s each**. Datamuse was 136–330 ms. Wiktionary REST was 165–780 ms and **404 on `think of one's feet`**.
  - Both keyless sources recognised `determinated` as nonstandard for *determined*. Datamuse returned 0 senses for the idiom.
  - AC-3: with `--warm`, the first word dropped from 330 → 107 ms on Datamuse and 167 → 45 ms on Wiktionary, and the medians went 151 → 43 ms and 326 → 45 ms. Part of Wiktionary's drop is probably its edge cache, because the same words had just been requested twice. Task 18 should use `--warm` and treat repeat-run Wiktionary numbers as cache-assisted.
  - AC-4: with `BASE_URL_DATAMUSE=https://bogus.invalid/words`, every Datamuse row became `network-error ENOTFOUND`, and the dictionaryapi.dev and Wiktionary rows were unaffected.
- **No audio from the keyless three right now:** the Wiktionary definition endpoint has no audio field, Datamuse has none, and dictionaryapi.dev is down (522). The audio timing path is written, but it has not run against a real audio URL yet. It will once dictionaryapi.dev recovers or a Merriam-Webster key exists.
- **The keyed adapters are written from the providers' public docs but have never been run.** Merriam-Webster builds the audio URL with the documented subdirectory rule. Oxford reads `dialects`. Cambridge and Collins share `src/lib/idm.mjs`, and its `class="def"` / `.mp3` extraction is a guess to check against a real response in task 18.
- `npm run probe` now needs **Node ≥ 20.12** for `process.loadEnvFile`, and `engines` is updated. The 30 s timeout is deliberate: a shorter one would hide dictionaryapi.dev's 522 behind our own timeout.
