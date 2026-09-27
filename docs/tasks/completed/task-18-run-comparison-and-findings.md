# Task 18 — Run the comparison, populate the page, write findings

|  |  |
|---|---|
| **Roadmap step** | [#9](../../roadmap.md#steps) |
| **Size** | M |
| **Wave** | 8 |
| **Depends on** | **task-16**, **task-17** |
| **Blocked on** | **D3** — the source decision this investigation feeds; and owner registration for Cambridge/Collins if those are to be included |
| **Unlocks** | task-19+ (the app-side "extra word detail" step, once D3 resolves) |
| **Files** | `investigations/dictionary-apis/out/results.json` (regenerated) · `investigations/dictionary-apis/index.html` (regenerated) · `investigations/dictionary-apis/README.md` (findings) |
| **Status** | **done 2026-09-27** — AC-1..AC-5 verified |

## The report

> how fast was response from them ... table with info about 10 words that we try to get from them ... Try also understand on which api you need me to help with registration.

Execute the probe for real, rebuild the page from measured data, and record the conclusions — including a clear answer to which APIs need the owner's registration help.

## What is already there

The harness (task-16) and page (task-17) are built. The three keyless providers are fully runnable now: `dictionaryapi.dev`, `datamuse`, `Wiktionary REST`. The keyed providers run only if the owner has put keys into `.env`; otherwise they are recorded as `skipped: "no key"` and the page says so.

Known from the earlier probe (2026-09-24), to be re-measured and laid alongside: `datamuse` ~0.33 s; Wiktionary ~1.9 s; `dictionaryapi.dev` returning **522** on all ten words.

## What it should do instead

Run `npm run probe --warm`, then `npm run build`. Then write a short **Findings** section into the folder `README.md`: which API is fastest/reliable, which actually returns both BrE and AmE audio, which returned the misspelling and the idiom, and — the owner's ask — a "you need to register" list (Cambridge, Collins via manual approval; everyone else self-serve). If the owner wants a keyed provider tested and has a key, add it to `.env` and rerun before concluding.

## Prompt

Read `CLAUDE.md`, `docs/tasks/completed/task-16-*.md`, `docs/tasks/completed/task-17-*.md`. One commit.

1. **Run the probe:** `npm run probe --warm` from `investigations/dictionary-apis/`. Confirm `out/results.json` covers all ten words for the keyless providers.
2. **If the owner supplied keys** (Merriam-Webster, Oxford sandbox, WordsAPI, API Ninjas) in `.env`, rerun so their rows are populated; otherwise leave them `skipped` and say so in the findings.
3. **Rebuild:** `npm run build`; open `index.html` and sanity-check the three sections and the compact headers.
4. **Write findings** into `README.md`: a short prose summary (fastest, most reliable, audio coverage, idioms/misspellings), the measured times, and a **"Registration help needed"** list naming Cambridge and Collins with the one-line reason each, plus a note that all others are self-serve.
5. **Record the D3 implication:** one paragraph stating what the measured data suggests about whether a dictionary API is a workable replacement for Reverso's extra word detail (does anything free return both pronunciations reliably? at what latency?). Do not make the decision — hand it back to the owner.
6. **Commit** results + regenerated `index.html` (both are build outputs, but committed here so the owner can view the page without running Node).

## Acceptance criteria

- [x] **AC-1** `out/results.json` contains measured rows for every keyless provider × ten words; each keyed-but-unkeyed provider is visibly `skipped: "no key"`.
- [x] **AC-2** The committed `index.html` renders measured numbers (not placeholders) for at least the three keyless providers.
- [x] **AC-3** `README.md` has a **Registration help needed** list naming exactly Cambridge and Collins, and states the others are self-serve.
- [x] **AC-4** A findings paragraph explicitly reports how each provider handled `determinated` and `think of one's feet` (the misspelling and the idiom).
- [x] **AC-5** The findings state the fastest provider and the most reliable one, with the measured milliseconds quoted.

## Open points

- Measuring "response time" from one machine on one day is indicative, not a benchmark; the findings must say so and note that `--warm` excludes cold DNS/TLS.
- Whether to obtain Oxford/Collins/Cambridge keys to complete the paid half of the table is a cost decision for the owner — the investigation stands on the free tier regardless.
- dictionaryapi.dev's 522s may be transient; re-run before concluding it is unusable, and if it recovers, note both the failure and the recovery.

## Implementation notes (2026-09-27)

- The owner supplied keys for **Merriam-Webster, WordsAPI and API Ninjas**. They are in the gitignored `.env` only, and `grep` confirms none appear in `out/results.json` or `index.html`. Oxford, Cambridge and Collins stayed `skipped: "no key"`.
- The keyed adapters were checked against real responses before the run. Two fixes: **Merriam-Webster** now keeps only headword-matching entries, because `direct` was pulling in `direct current` and similar compounds. **API Ninjas** splits its numbered one-string definition into senses (`tenacious` went from 1 to 6). The `api-ninjas` note in `providers.json` was corrected to match.
- `npm run probe -- --warm` took 3 min 57 s, and 1 min 38 s of that was dictionaryapi.dev's ten 522s. **dictionaryapi.dev was still 522** on a manual recheck (`claim` and `hello`, both ~19.5 s), the same as on 2026-09-24. It has not recovered.
- `out/results.json` is committed with `git add -f` so the page's data travels with it. `out/` stays gitignored for normal runs.
- The findings, the registration list and the D3 paragraph are in `investigations/dictionary-apis/README.md#findings-probe-run-2026-09-27---warm`. Headline: Datamuse is fastest (148 ms median), Merriam-Webster is most reliable (10/10, 156 ms median) and is the only source that returned audio (AmE 8/10, ~60 ms per file). No testable source returns both BrE and AmE.
