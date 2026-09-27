Standalone investigation: compare free and cheap English dictionary APIs for the vocab app's "extra word detail" need (roadmap step 9, decision D3).

This folder is independent of the Flutter app (`lib/`) and the Worker (`vocab-photo-api/`). It ends up as a web page with a short description of each dictionary, a cost table, and a table of what each API returns for the same ten test words.

## Run

```sh
cd investigations/dictionary-apis
npm install
cp .env.example .env   # fill in the keys you have; .env is gitignored
npm run probe            # writes out/results.json (gitignored)
npm run probe -- --warm  # one discarded call per host first, so DNS/TLS isn't in the timings
npm run build            # renders index.html from data/providers.json + out/results.json
npm run serve            # http://localhost:8000
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
| `src/build.mjs`, `src/page/template.html` | Page builder: strips + escapes every third-party string, writes a self-contained `index.html` (no CDN, no framework). Works without `out/results.json`. |
| `index.html` | The comparison page, committed so it can be opened without Node. |
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
- [x] task-17 — comparison page (`npm run build` / `npm run serve`)
- [x] task-18 — run the comparison, write findings (below)

## Findings (probe run 2026-09-27, `--warm`)

Measured from one machine on one day, with each host warmed first, so DNS/TLS setup is not in the numbers. Treat them as indicative, not a benchmark. The keyed runs used the owner's keys for Merriam-Webster, WordsAPI and API Ninjas. Oxford, Cambridge and Collins had no key and are recorded as `skipped: "no key"`.

| Provider | Words defined (of 10) | Median def t | Range | 🇬🇧 audio | 🇺🇸 audio |
|---|---|---|---|---|---|
| Datamuse | 9 | 148 ms | 139–335 ms | — | — |
| Merriam-Webster | 8 | 156 ms | 136–220 ms | n/a | **8/10** (median fetch 60 ms) |
| WordsAPI | 7 | 227 ms | 208–516 ms | — | — (IPA text only) |
| Wiktionary REST | 9 | 249 ms | 40–599 ms | — | — |
| API Ninjas | 6 | 597 ms | 453–750 ms | — | — |
| dictionaryapi.dev | 0 | all **HTTP 522** at ~19.6 s | | | |
| Oxford / Cambridge / Collins | skipped: no key | | | | |

- **Fastest:** Datamuse, median **148 ms**, with Merriam-Webster close behind at **156 ms**. MW's spread was the tightest of all (136–220 ms).
- **Most reliable:** **Merriam-Webster**. It answered 10/10 with HTTP 200, and every one of its 8 audio URLs downloaded. Datamuse also answered 10/10, but it has no audio. dictionaryapi.dev failed every request, with a 522 after ~19.6 s, on 2026-09-24 and again on 2026-09-27. It was still down on a manual recheck, so it counts as unusable right now, not as a one-off blip.
- **Audio coverage:** no probed API returned **both** British and American audio. MW is the only live source of audio (AmE only, 8/10 words). WordsAPI gives IPA text and Datamuse gives ARPAbet, with no sound. Cambridge claims both dialects and Oxford/Collins are British-led, but none of them could be tested without registration.
- **Content quirks:** API Ninjas (Webster 1913 text) and WordsAPI returned nothing for the inflected forms `flustered`/`circumstances` (API Ninjas) and `gated` (WordsAPI). WordsAPI took 516 ms on `roller coaster`, the only multi-word lookup that slowed anyone down noticeably.

### The misspelling and the idiom

- **`determinated`** (misspelling of *determined*). **Datamuse** and **Wiktionary** both recognised it and mapped it to *determined* / *determinate*. Datamuse labels it "(nonstandard)". **Merriam-Webster** returned no entry, but its suggestion list includes *determined*. **WordsAPI** and **API Ninjas** returned 200 with no definitions and no hint. dictionaryapi.dev gave 522.
- **`think of one's feet`** (the idiom is *think on one's feet*). **No provider** defined it. **Merriam-Webster** came closest: it offered *find one's feet*, *land on one's feet*, *to one's feet* and similar, but not *think on one's feet* itself. **WordsAPI** and **Wiktionary** returned 404. **Datamuse** and **API Ninjas** returned 200 with nothing. dictionaryapi.dev gave 522.

### Registration help needed

- **Cambridge**: manual approval, and no free access is stated. It has to be applied for in advance.
- **Collins**: manual approval, and it has to be applied for in advance.

All the others are self-serve: Merriam-Webster, Oxford, WordsAPI and API Ninjas issue a key instantly, and Datamuse, Wiktionary and dictionaryapi.dev need no key. The Oxford sandbox is limited to A-words, so it cannot test most of the fixture without a paid plan.

### What this means for D3 (not a decision)

Of the sources that can be tested free today, none returns both British and American pronunciation. Merriam-Webster comes closest to what Reverso's extra word detail would need: a fast definition (~150 ms), several senses, and reliable American audio (~60 ms per file). Its free tier is non-commercial only (1,000 calls/day), and it has no British audio. Datamuse and Wiktionary are as fast and handle misspellings better, but they have no audio at all. Both dialects would mean Cambridge (commercial, manual approval, undisclosed price), Oxford (paid; Enterprise ≈ £5,000/yr) or pulling audio offline from Wiktextract dumps. Whether an English-description dictionary is the right source, and whether AmE-only audio is acceptable, is the owner's call.
