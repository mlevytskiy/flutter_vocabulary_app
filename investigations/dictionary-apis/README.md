Standalone investigation: compare free and cheap English dictionary APIs for the vocab app's "extra word detail" need (roadmap step 9, decision D3).

This folder is independent of the Flutter app (`lib/`) and the Worker (`vocab-photo-api/`). It ends up as a web page with a short description of each dictionary, a cost table, and a table of what each API returns for the same ten test words.

## Run

```sh
cd investigations/dictionary-apis
npm install
cp .env.example .env   # fill in the keys you have; .env is gitignored
npm run probe
```

Node 18+ (uses the built-in `fetch`; no HTTP client package).

## Layout

| Path | What |
|---|---|
| `data/words.json` | Frozen fixture: the ten test words, each with a stable `id` and a `note`. Every provider is asked exactly these. |
| `data/providers.json` | Shortlist: description, returns, BrE/AmE audio, free tier, paid, key, registration, `probeable`, `excluded` per provider. Read by the probe and the page. |
| `.env.example` | Every provider key the project may hold, blank. Copy to `.env`. Cambridge and Collins need **manual approval** — apply early. |

Two fixture words are deliberately non-standard and kept verbatim: `determinated` (misspelling of *determined*) and `think of one's feet` (the idiom is *think on one's feet*). They test how each API behaves on a misspelling and on a (wrong) idiom.

## Providers considered (14)

9 probeable live APIs (3 keyless: dictionaryapi.dev, Datamuse, Wiktionary REST), 1 bulk-download-only source (Wiktextract/kaikki.org), and 4 considered and rejected (ECDICT, Google Dictionary, Linguee, dict.cc) — see `data/providers.json`.

**Needs your help to register:** the `registrationHelp` array in `data/providers.json` — currently **Cambridge** and **Collins** (manual approval, apply in advance). The self-serve ones (Merriam-Webster, Oxford, WordsAPI, API Ninjas) give a key instantly.

## Status

- [x] task-14 — scaffold (this folder, fixture, key template)
- [x] task-15 — provider shortlist + cost table (`data/providers.json`)
- [ ] task-16 — probe harness (`npm run probe`, currently a stub)
- [ ] task-17 — comparison page (`npm run build` / `npm run serve`, currently stubs)
- [ ] task-18 — run the comparison, write findings
