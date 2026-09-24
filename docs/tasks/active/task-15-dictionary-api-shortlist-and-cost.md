# Task 15 — Candidate shortlist: descriptions, cost table, registration needs

|  |  |
|---|---|
| **Roadmap step** | [#9](../../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 7 |
| **Depends on** | **task-14** |
| **Blocked on** | — |
| **Unlocks** | task-16, task-17 |
| **Files** | `investigations/dictionary-apis/data/providers.json` (new) · `investigations/dictionary-apis/README.md` |
| **Status** | **done 2026-09-24** — AC-1..AC-4 verified |

## The report

> Check free and cheap english vocabulary api. ... Web-page where I can see small description about each dictionary, table with info about how much cost to use them ... Try also understand on which api you need me to help with registration. In this case I can do my job for all apis from the begining.

Turn the provider research into a single machine-readable shortlist (`providers.json`) that both the probe harness and the page read. It carries, per provider: a short description, what it returns for a word, whether it returns BrE and/or AmE pronunciation, cost, limits, whether a key is needed, and — the owner's explicit ask — which ones need the owner's help to register.

## What is already there

Research is complete. The picture, by registration effort:

| Provider | Definitions | Senses | BrE audio | AmE audio | Free tier | Paid | Key | Registration |
|---|---|---|---|---|---|---|---|---|
| dictionaryapi.dev | yes | multiple | partial (`_gb_`) | partial (`_us_`) | unlimited, no cap stated | — | no | none |
| Merriam-Webster | yes | multiple | no | yes | 1,000/day, non-commercial | contact for commercial | yes | self-serve instant |
| Oxford Dictionaries | yes | multiple | yes (BrE-led) | limited | sandbox: 500 calls *lifetime*, A-words only | Lite/Growing/Enterprise, not public; Enterprise ≈ £5,000/yr/lang | yes | self-serve |
| Cambridge | yes | multiple | yes | yes | **none — no free access stated** | commercial, undisclosed | yes | **manual approval** |
| Collins | yes | multiple | yes (BrE-led) | unclear | 5,000 calls/month | £50–£375/mo tiers | yes | **manual approval** |
| WordsAPI (RapidAPI) | yes | multiple/POS | no (IPA text) | no | 2,500/day | ~$10–15/mo | yes | self-serve instant |
| API Ninjas | minimal | 1 | no | no | 3,000/month | $59–$299/mo | yes | self-serve instant |
| Datamuse | yes (`md=d`) | 1–few | no (Arpabet) | no | 100,000/day | free; key required from 2027 | no (until 2027) | will be self-serve |
| Wiktionary REST | yes | multiple | sometimes | sometimes | ~500/hr unauthenticated | free | no | none |
| Wiktextract / kaikki.org | yes | multiple | yes (Commons) | yes | free bulk download | free | no | none (not a live API) |
| ECDICT | yes | several | no | no | free offline SQLite/CSV | free | no | download only |
| Google Dictionary | deprecated (~2011) | — | — | — | — | — | — | exclude |
| Linguee / dict.cc | no public API (scraping prohibited) | — | — | — | — | — | — | exclude |

Live probe of the two keyless dictionary candidates already done (2026-09-24): `datamuse` returned 200 in ~0.33 s (`defs` + Arpabet `pron`, no audio); Wiktionary REST returned 200 in ~1.9 s (HTML-wrapped defs, **404 on the idiom**); **`dictionaryapi.dev` returned HTTP 522 on every one of the ten words across two attempts** — the volunteer host was timing out at probe time. That is a first-class finding for the comparison, not a probe bug.

## What it should do instead

`providers.json`: an array, one object per provider, with the fields the page and harness both need — `id`, `name`, `docsUrl`, `description` (one sentence), `returns` (definitions/senses/audio booleans), `audio: { "brE", "amE" }` each `yes | partial | no | n/a`, `freeTier`, `paid`, `keyRequired` (bool), `registration: "none" | "self-serve" | "manual-approval"`, `probeable` (bool — false for bulk-download-only like Wiktextract/ECDICT), and `excluded` (bool + reason for Google/Linguee/dict.cc). The page renders the description and cost columns straight from this file; the harness iterates only `probeable && !excluded`.

A top-level `registrationHelp` array names the providers needing the owner up front — currently **Cambridge** and **Collins** (manual approval). This is the artifact that answers "on which api you need me to help with registration".

## Prompt

Read `CLAUDE.md`, `docs/tasks/active/task-14-*.md`, and the research already gathered in this task's report. One commit.

1. **Write `providers.json`** under `investigations/dictionary-apis/data/`, one object per provider, all fields above. Use the research table verbatim for values; do not invent prices — where a price is not public (Oxford, Cambridge) set the string to `"not public"` and add a `note`.
2. **Mark exclusions explicitly** (Google Dictionary, Linguee, dict.cc, ECDICT-as-API) with `excluded: true` and a `reason`, so the page can list them in a short "considered and rejected" block rather than dropping them silently.
3. **Add the `registrationHelp` array** listing Cambridge and Collins with a one-line reason each ("manual approval — apply in advance").
4. **Update the folder `README.md`** with a "Providers considered (N)" line and a pointer to `registrationHelp`.
5. **No probing here** — this task is data + docs only. Do not hit any network endpoint.

## Acceptance criteria

- [x] **AC-1** `providers.json` parses; every entry has `id`, `name`, `description`, `registration`, and `probeable`.
- [x] **AC-2** `registrationHelp` contains exactly the manual-approval providers (Cambridge, Collins) — no self-serve one is listed there.
- [x] **AC-3** No invented prices: every `paid` value is either a figure traceable to the research table or the literal `"not public"`.
- [x] **AC-4** The three excluded providers appear with `excluded: true` and a `reason`.

## Open points

- Oxford's Lite/Growing prices are behind a login; only Enterprise (≈£5,000/yr/lang) is public. Whether to chase the others is the owner's call.
- Collins' AmE audio is unclear from public docs; the harness (task-16) will settle it empirically if a key is obtained.
- **Shape:** the prompt says both "an array" and "a top-level `registrationHelp` array", so the file is an object `{ asOf, source, registrationHelp, providers[] }`. Task-16/17 read `providers`.
- **Four exclusions, not three:** AC-4 names three, but step 2 also lists ECDICT-as-API. All four are `excluded: true` with a `reason`. Wiktextract is `probeable: false` but not excluded, because it is a usable bulk source.
- **Audio enum:** Collins AmE is `"unknown"` (the research says "unclear"), which is outside `yes | partial | no | n/a`. The page (task-17) must render it. Oxford AmE "limited" → `partial`; Datamuse Arpabet and WordsAPI IPA → `no`.
- **`paid` strings:** research "—" → `"none (free only)"` for dictionaryapi.dev and `"n/a"` for the excluded ones. Merriam-Webster keeps the verbatim `"contact for commercial"`.
- **`docsUrl`s** were written from memory and not fetched, because this task forbids network calls. Task-16 should check them. Google Dictionary has none.
