---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-09-27"
feature_size: "M"
---

# Spec — definition-mode

> **Glossary:** [CONTEXT](./CONTEXT.md) · [project CONTEXT](../../../CONTEXT.md)
> **Reference module / docs / channels used:** [`docs/tasks/active/task-19-definition-mode-setting.md`](../../tasks/active/task-19-definition-mode-setting.md) (planned layouts, row state) · [`investigations/dictionary-apis/README.md`](../../../investigations/dictionary-apis/README.md) (dictionary behaviour on senses, misspellings, idioms)

## 1. Context

A learner collecting English words sees only a Ukrainian translation next to each one. The translation can be right and still leave the learner unsure in what context the word is used; an English definition answers that, but on its own it is sometimes hard to understand. The two complement each other, and today the app offers only one of them. This affects the app's single learner and, through the shared link and the AnkiDroid file, the partner they study with.

Now, because the dictionary-source decision (D3) closed on 2026-09-27 after a measured comparison, and because the photo analysis already produces a short context-fitting English description for every photo word — the app requests it and then discards it. The "extra word detail" slot left empty since Reverso was removed (roadmap step 9) can finally be filled.

Committed approach: one learner-chosen **word detail mode** — translation, definition, or both — that decides what every word row shows and what the words table, the AnkiDroid file and the shared page carry. A definition gets its own field placed under the word, filled the same two ways a translation is: automatically for photo words (the context description from the photo analysis) and on demand for typed words (one tap for the dictionary's first sense, or a list of senses to pick from). Grounding: no comparable product offers one persistent translation/definition/both switch that stays consistent from capture through list, export and a shared view (competitive research 2026-09-27) — that consistency is the wedge; the sharpest failure vector found was rows silently disappearing when the "filled" rule depends on the mode, so the rule here is mode-independent.

- Decision: outputs follow the current mode (learner's choice over "always export everything stored"); the AnkiDroid file keeps a fixed column layout so column meaning never changes between exports.
- Decision override: size kept at M despite the shared-page and server-side scope — rationale: single-owner app, one deploy; accepted risk: the shared-page contract gets less explicit design unless the api stage is run.
- Decision override: product names AnkiDroid and Reverso stay in §1–§3 — rationale: AnkiDroid is the product's export destination named in the idea brief's goal, not a technology choice; Reverso is history.

## 2. Goals

- The learner can see, for any collected word, both what it means in Ukrainian and how it is used in English — or just the one they prefer.
- Photo words arrive with a context-fitting definition at no extra effort; typed words get one in a single tap.
- Definitions travel everywhere words travel: the words table, the AnkiDroid cards and the partner's shared page.

## 3. Non-goals

- Changing where translations come from or how they are chosen — the translation path stays exactly as it is.
- Pronunciation audio from the dictionary — on-device speech (D1) stays the pronunciation source.
- A "fill all definitions" action for a whole session — each typed word is filled on demand, to keep the dictionary's daily allowance out of reach.
- Back-filling definitions into sessions collected before this feature — older rows simply start with an empty definition.

## 4. User stories

### US-01: Choose the word detail mode
**As a** learner
**I want** to choose in Settings between translation, definition, or both
**So that** every word row shows the kind of detail I learn best with

### US-02: Read definitions under the word
**As a** learner
**I want** a definition shown under the word across the full width, not squeezed beside it
**So that** a long explanation stays readable

### US-03: Fill a typed word's definition in one tap
**As a** learner
**I want** one tap to fill a typed word's definition from the dictionary
**So that** I don't have to look it up elsewhere

### US-04: Pick a different sense
**As a** learner
**I want** to see the dictionary's other senses and pick the one I meant
**So that** the definition matches how the word was actually used

### US-05: Get definitions for photo words automatically
**As a** learner
**I want** words from a photo to arrive with a definition that fits their context in the photo
**So that** photo capture gives me the full detail without extra taps

### US-06: Keep my details when I switch modes
**As a** learner
**I want** switching the mode to never lose a translation or definition I already have
**So that** I can change my mind freely

### US-07: Take definitions into the table and AnkiDroid
**As a** learner
**I want** the words table and the AnkiDroid file to carry definitions according to my mode
**So that** my cards teach the word in context

### US-08: Show definitions to my partner
**As a** partner
**I want** the shared page to show the definitions the learner collected
**So that** I see the same detail the learner studies with

## 5. Acceptance criteria

### AC-01 (US-01) — happy path
**Given** a learner on a fresh install
**When** they open Settings
**Then** they see three word detail mode choices — translation, definition, both — with translation selected, and the choice they make is still selected after the app is restarted

### AC-02 (US-01) — domain invariant
**Given** a learner in translation mode
**When** they use the word input screen
**Then** every word row looks exactly as it did before this feature — same fields, same positions, same icons

### AC-03 (US-02) — happy path
**Given** a learner who chose definition mode
**When** they look at the word input screen
**Then** every word row shows the word on top and its definition underneath, each across the full row width, and no translation field

### AC-04 (US-02) — happy path
**Given** a learner who chose both
**When** they look at the word input screen
**Then** every word row shows today's word-and-translation line with the definition underneath it across the full row width

### AC-05 (US-03) — happy path
**Given** a learner in definition or both mode has typed "tenacious" in a word row
**When** they tap the definition's lightning icon
**Then** the definition fills with the dictionary's first short sense of "tenacious", and the icon shows progress until it does

### AC-06 (US-03) — error
**Given** a learner has typed a misspelled word such as "determinated"
**When** they tap the definition's lightning icon
**Then** the definition stays empty and the learner is told no definition was found, with the dictionary's spelling suggestions (such as "determined") — nothing is written into the field on their behalf

### AC-07 (US-03) — error
**Given** the dictionary cannot be reached or its daily allowance is used up
**When** the learner taps the definition's lightning icon or opens the definition's senses list
**Then** the definition stays as it was, the learner is told definitions are temporarily unavailable, and translation features keep working

### AC-08 (US-04) — happy path
**Given** a learner has a typed word in a row
**When** they open the definition's senses list and tap one of the senses
**Then** that sense replaces the definition text, and the list offers every short sense the dictionary returned for that word

### AC-09 (US-05) — cross-context
**Given** a learner in any word detail mode takes a photo of highlighted words
**When** the words arrive in the list
**Then** each word's definition holds the short explanation the photo analysis wrote for that word's context — kept even while the mode hides it — and no dictionary lookups were made for them

### AC-10 (US-05) — cross-context
**Given** the photo analysis returned a word with a definition but no translation
**When** the word arrives in the list
**Then** the definition is kept as the definition and the translation stays empty, instead of the English explanation being placed in the translation

### AC-11 (US-06) — domain invariant
**Given** a learner has rows with both a translation and a definition
**When** they switch from both to definition, then to translation, then back to both
**Then** every translation and definition is exactly as before — changing the word detail mode never deletes a stored translation or definition

### AC-12 (US-06) — domain invariant
**Given** a learner has a row with a word and a definition but no translation
**When** they open the words table in any mode
**Then** that row counts as filled and is listed — a row counts as filled when it has a word plus a translation or a definition, whatever the mode

### AC-13 (US-06) — happy path
**Given** a learner has definitions in the current session and in a session from before this feature
**When** they restart the app and open both sessions
**Then** the current session's definitions are still there, and the older session opens normally with empty definitions

### AC-14 (US-07) — happy path
**Given** a learner has rows with translations and definitions
**When** they open the words table
**Then** the table shows word and translation in translation mode, word and definition in definition mode, and all three in both mode

### AC-15 (US-07) — happy path
**Given** a learner exports the AnkiDroid file
**When** they import it into AnkiDroid
**Then** each card carries the word, the translation and the definition in their own fixed places, filled according to the current mode (the one the mode hides left empty), and no part of a definition becomes an Anki tag

### AC-16 (US-08) — cross-context
**Given** a learner publishes a session in definition or both mode
**When** the partner opens the shared link
**Then** the partner sees each word's definition, as the learner's mode showed it at publishing time — in definition mode the page shows no translations, in both mode it shows translations and definitions

### AC-17 (US-08) — cross-context
**Given** a session was published before this feature
**When** the partner opens its shared link or downloads its AnkiDroid file from the page
**Then** the page and the file work as before, simply without definitions

### AC-18 (US-08) — authorization
**Given** a person does not have a session's shared link
**When** they try to reach that session's definitions
**Then** nothing about the session is revealed — the link stays the only credential, and definitions add no new way in

### AC-19 (US-08) — error
**Given** a word's definition is longer than the shared page accepts
**When** the learner publishes the session
**Then** publishing is refused and the learner is told which word's definition is too long, so they can shorten it

### AC-20 (US-08) — cross-context
**Given** a learner published a session after this feature
**When** the partner downloads the AnkiDroid file from the shared page
**Then** the file has the same fixed places for word, translation and definition as the learner's own export, filled according to the mode at publishing time

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Latency p95 — lightning tap until definition filled (typed word, mobile data) | ≤ 1,000 ms | on-device timing log around the lookup, 20 taps over a week |
| Latency p95 — senses list open until senses shown | ≤ 1,500 ms | same on-device timing log |
| Photo analysis duration | no increase vs. before the feature (descriptions are already requested) | existing photo request stopwatch, 10 photos before/after |
| Dictionary lookups | only on a learner tap — 0 per photo, 0 per keystroke; normal use stays far below the provider's 1,000/day quota (no in-app cap) | lookup counter in the debug log |
| Mode switch | all rows re-laid out within one screen refresh, no data change | device check with a 30-row session |
| Definition length on the shared page | accepted up to the same per-field limit as translations (500 characters) | Worker validation test |

## 6.1 Security / privacy

- **Data classification:** internal — word lists and their explanations; a published session becomes readable by anyone holding its link.
- **Personal data touched:** none new. The new per-row field holds dictionary or photo-analysis text.
- **AuthZ/AuthN impact:** no new capability. The shared link remains the only credential; the dictionary's access key is a new secret the app depends on (where it lives is design decision D10).
- **Abuse cases:**
  - Extracted dictionary key used by others to exhaust the daily allowance: the learner's lookups fail gracefully (AC-07); the key can be rotated.
  - Script or markup injected through a definition (typed or photo-derived) onto the shared page: shown as plain text, never interpreted.
  - Oversized definitions used to bloat a published session: refused at publishing (AC-19), same bound as translations.
  - Redistribution of dictionary text on a public link beyond the free licence's terms: tracked as an open question.
- **Security review:** Required — a new third-party secret in the app and new content on a public page.

## 7. Metrics / KPIs

- **Rows with a definition** — baseline: 0% of rows in new sessions; target: ≥ 50% of rows in sessions created in the 30 days after release.
- **First-tap definition success** — baseline: n/a (new); target: ≥ 85% of lightning taps fill a definition, over the first 2 weeks (misspellings and idioms count as misses).
- **Decks with definitions** — baseline: 0 AnkiDroid exports carrying definitions; target: ≥ 1 exported deck with definitions within 14 days of release.

## 8. Open questions

- [ ] May the free dictionary's definitions be shown on a public shared link and in exported files under its non-commercial licence? Default now: yes, with attribution on the shared page. — owner: learner (Maksym), due: before the first Worker deploy (moved from "before sdd:design" on 2026-09-27)
- [x] Where does the dictionary key live and who calls the dictionary (D10)? Resolved 2026-09-27: the app asks our Worker, which holds the key as a secret (sad ADR-0002). — owner: learner (Maksym)
- [x] When the learner edits a word, should its hidden (not shown in the current mode) definition or translation be cleared as stale? Resolved 2026-09-27: kept; only its stored alternatives are dropped, as for translations today. — owner: learner (Maksym)
- [ ] Should a "fill all definitions" action for typed words exist later? Default now: no. — owner: learner (Maksym), due: after 2 weeks of use
