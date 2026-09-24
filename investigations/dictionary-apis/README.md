Standalone investigation: compare free and cheap English dictionary APIs for the vocab app's "extra word detail" need (roadmap step 9, decision D3).

This folder is independent of the Flutter app (`lib/`) and the Worker (`vocab-photo-api/`). It ends up as a web page with a short description of each dictionary, a cost table, and a table of what each API returns for the same ten test words.

## Run

```sh
cd investigations/dictionary-apis
npm install
cp .env.example .env   # fill in the keys you have; .env is gitignored
npm run probe            # writes out/results.json (gitignored)
npm run probe -- --warm  # one discarded call per host first, so DNS/TLS isn't in the timings
```

Keyed providers without a key in `.env` are recorded as `skipped: "no key"`; the run still exits 0. To simulate a broken provider, point it elsewhere with `BASE_URL_<ID>`, e.g. `BASE_URL_DATAMUSE=https://bogus.invalid/words npm run probe`.

Node 20.12+ (uses `process.loadEnvFile` and the built-in `fetch`; no HTTP client package).

## Layout

| Path | What |
|---|---|
| `data/words.json` | Frozen fixture: the ten test words, each with a stable `id` and a `note`. Every provider is asked exactly these. |
| `data/providers.json` | Shortlist: description, returns, BrE/AmE audio, free tier, paid, key, registration, `probeable`, `excluded` per provider. Read by the probe and the page. |
| `src/probe.mjs` | Runner: providers × words, sequential, every failure recorded as a row. Output `out/results.json` = `{ meta, providerStatus, results[providerId][wordId] }`. |
| `src/providers/<id>.mjs` | One adapter per probeable provider: `probe(word) → { ms, status, definitions, senseCount, audio: { brE, amE } }` or `{ ms, status, error }` or `{ skipped }`. Audio URLs are fetched separately by the runner, so each has its own `ms`. |
| `src/lib/` | `timedFetch` (wall-clock incl. body, 30 s timeout, never throws), HTML stripping, audio dialect classification, the shared Cambridge/Collins client. |
| `.env.example` | Every provider key the project may hold, blank. Copy to `.env`. Cambridge and Collins need **manual approval** — apply early. |

Two fixture words are deliberately non-standard and kept verbatim: `determinated` (misspelling of *determined*) and `think of one's feet` (the idiom is *think on one's feet*). They test how each API behaves on a misspelling and on a (wrong) idiom.

## Providers considered (14)

9 probeable live APIs (3 keyless: dictionaryapi.dev, Datamuse, Wiktionary REST), 1 bulk-download-only source (Wiktextract/kaikki.org), and 4 considered and rejected (ECDICT, Google Dictionary, Linguee, dict.cc) — see `data/providers.json`.

**Needs your help to register:** the `registrationHelp` array in `data/providers.json` — currently **Cambridge** and **Collins** (manual approval, apply in advance). The self-serve ones (Merriam-Webster, Oxford, WordsAPI, API Ninjas) give a key instantly.

## Status

- [x] task-14 — scaffold (this folder, fixture, key template)
- [x] task-15 — provider shortlist + cost table (`data/providers.json`)
- [x] task-16 — probe harness (`npm run probe`)
- [ ] task-17 — comparison page (`npm run build` / `npm run serve`, currently stubs)
- [ ] task-18 — run the comparison, write findings
