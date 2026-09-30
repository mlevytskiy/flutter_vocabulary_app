---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-09-30"
feature_size: "S"
---

# Spec — words-from-subtitles

> **Glossary:** [project CONTEXT](../../../CONTEXT.md) · [feature CONTEXT](./CONTEXT.md)
> **Reference module / docs / channels used:** `docs/architecture.md` · `docs/roadmap.md` · `docs/idea-brief.md` §7 (subtitles named as the next capture source) · `lib/features/word_input/widgets/vocab_result_dialog.dart` (the results dialog this feature reuses) · `lib/features/word_input/word_input_screen.dart` (the photo import flow and its word cap) · `vocab-photo-api/src/index.ts` (the photo word-picking route and its limits)

## 1. Context

A learner who watches films and series in English has no quick way to turn one into a word list. Today words come into a session either typed one by one or from a photo of a page marked with a highlighter. A film has no highlighter: a feature-length subtitle file holds one to two thousand different words, and picking the few worth learning by hand takes longer than the film.

Why now: the idea brief names subtitles as the next capture source after the photo (§7), and the pieces it needs are in place. The photo import already has the AI pick words and show them in a results dialog with translation, definition and context, where the learner removes what they don't want before adding the rest. The app also has a Settings screen for lasting preferences. Searching subtitles by film name is wanted too, but it comes after this feature.

Committed approach: everything happens in dialogs over the main screen. A new item in the speed dial, next to "take photo", opens the import dialog. There the learner picks a subtitle file, the import purpose, their English level (A1–C2) and a word maximum (1–100). The dialog opens with the learner's last choices, or with the Settings defaults if they turned remembering off. Starting closes it and shows a loading dialog until the words arrive. The AI picks words above that level which fit the purpose, and the maximum is a limit, never a target. The words open in the same results dialog as a photo import, and Done appends the kept words to the current session. This follows the research finding that the tools compared (Lexpresso, CaptionCatch, Language Reactor, Anki Miner) each pick words by one fixed rule; none lets the learner switch between "every word I need for this film" and "common words for later", and none takes a subtitle file on the phone. The main risk, from the failure-mode review, is the maximum being treated as a quota, which is the photo import's old bug (roadmap step 2). AC-06 is there to prevent it.

- Decision (owner, 2026-09-30): searching subtitles by film name is a separate, later feature; this one takes a file only.
- Decision (owner, 2026-09-30): no KPIs are kept for this feature (§7).
- Decision (owner, assumptions accepted 2026-09-30): the word maximum goes up to 100 with a default of 20; words already in the current session are never proposed; names, sound captions and formatting marks are never proposed, but slang and swearing may be; the dialog's "Description" label is renamed "Definition" for photo and subtitle imports alike.
- Decision (owner, critic resolution 2026-09-30): when more words qualify than the maximum, "understand this film" keeps the words most needed to follow this film first, and "frequent words for the future" keeps the words most common in English first; the dialog lists them in that order (AC-19).
- Decision (owner, critic resolution 2026-09-30): for a subtitle import the dialog drops the photo-only timing line and says "No new words above your level in these subtitles." when nothing qualifies; the photo dialog is unchanged apart from the "Definition" label (AC-20).
- Decision (owner, ux-flows 2026-09-30): no import screen — an import dialog, a loading dialog and the results dialog, all over the main screen. To try again, the learner opens the import dialog from the speed dial again.
- Decision (owner, ux-flows 2026-09-30): Settings keeps the default purpose, level and maximum plus a "remember my last choices" switch, on by default. With it on, the import dialog opens with the purpose, level and maximum used last time; with it off, it always opens with the defaults. The file itself is never remembered.
- Decision (owner, critic resolution 2026-09-30): one new app package for opening files from the phone is approved (CLAUDE.md rule 5); which one is chosen in `design`.
- Decision (owner, design 2026-09-30): Settings lets the learner choose which AI model picks the subtitle words — Sonnet 5 (the default, the same model as the photo import), Sonnet 5.5, Haiku 4.5 or Opus 5.5 — so the owner can compare them after release. The choice applies to subtitle imports only (AC-21).
- Decision (owner, design 2026-09-30): the subtitle results dialog shows one small line with the model, the time taken and the approximate cost of the import, so models can be compared; this replaces the "drops the photo-only timing line" part of the AC-20 decision (AC-20, AC-21).
- Decision (owner, design 2026-09-30): an import may take longer than a minute; the 100-word time target is removed from §6 and only measured per model. The 20-word target stays.
- Decision (owner, design 2026-09-30): besides the per-address allowance, all subtitle imports together are capped at 20 per UTC day, so a leaked app secret used from many addresses still has a daily ceiling (§6, AC-14).
- Decision (owner, design 2026-09-30): the app reads the subtitle file and sends only its dialogue lines to the service, so the service's shape check covers a bounded list of short lines, not the subtitle format itself (§6.1).

## 2. Goals

- A learner turns a subtitle file into a reviewed word list in the current session, without typing any word.
- The proposed words match what the learner asked for: above their level, fitting the purpose, never over the maximum.
- Subtitle words behave exactly like photo words afterwards: same session, History, shared page and export, with no new steps.

## 3. Non-goals

- Searching or downloading subtitles by film name — wanted, but a separate feature, because it brings in an outside subtitle source with its own limits.
- Playing the video or linking a word to its moment in the film — the app works from the subtitle text only, and a word row has no place for a time.
- Keeping the subtitle sentence or film name on the word row — the row stays as it is today, so storage, the shared page and export don't change.
- Remembering which words the learner already knows across all sessions — only the current session is checked, because an unlearned word from an old list may still be worth proposing.

## 4. User stories

### US-01: Import words from a subtitle file
**As a** learner
**I want** to open a subtitle file from the main screen and get a list of words from it
**So that** I can study a film's vocabulary without writing it out

### US-02: Say what I need from this film
**As a** learner
**I want** to choose the purpose, my English level and the word maximum for this import
**So that** the list fits both me and why I'm watching

### US-03: Keep my usual choices
**As a** learner
**I want** the import dialog to open with the purpose, level and maximum I used last time, or with defaults I set in Settings
**So that** most imports need only the file

### US-04: Review before adding
**As a** learner
**I want** to see the proposed words with translation, definition and context, and remove the ones I don't want
**So that** only words I chose enter my session

### US-05: Only useful words
**As a** learner
**I want** the list to leave out words I already know or already have, and names and captions that aren't vocabulary
**So that** I spend my time on words I actually need to learn

### US-06: Understand what went wrong
**As a** learner
**I want** a plain message when the file can't be used or the words can't be picked
**So that** I know whether to pick another file or just try again

### US-07: Share subtitle words as usual
**As a** learner
**I want** words from subtitles to be ordinary words in my session
**So that** my partner sees them on the shared page and I export them to AnkiDroid as always

## 5. Acceptance criteria

### AC-01 (US-01, US-03) — happy
**Given** a learner on the main screen, with Settings set to purpose "understand this film", level B2 and maximum 20
**When** the learner chooses the subtitle import from the speed dial
**Then** the import dialog opens over the main screen with purpose "understand this film", level B2 and maximum 20 already chosen, and asks for a subtitle file

### AC-02 (US-01, US-04) — happy
**Given** a learner in the import dialog with an English subtitle file chosen
**When** the learner starts the import
**Then** the import dialog closes, a loading dialog shows that the app is working, and then the app opens the results dialog listing the proposed words, each with its translation, its definition and the sentence from the film it came from

### AC-03 (US-04) — happy
**Given** the results dialog shows 12 proposed words
**When** the learner removes 3 of them and taps Done
**Then** the 9 kept words are added at the end of the current session on the main screen, in the order shown, and the 3 removed words are not added

### AC-04 (US-04) — happy
**Given** the results dialog is open
**When** the learner removes every word and taps Done, or closes the dialog without Done
**Then** the current session is unchanged

### AC-05 (US-03) — happy
**Given** a learner with the default level C1 in Settings and "remember my last choices" on
**When** the learner changes the level to B1 in the import dialog and runs the import
**Then** the import uses B1, Settings still shows the default C1, and the next import dialog opens with B1

### AC-05b (US-03) — happy
**Given** a learner with the default level C1 in Settings and "remember my last choices" off
**When** the learner changes the level to B1 in the import dialog and runs the import
**Then** the import uses B1, and the next import dialog opens with C1 again

### AC-06 (US-02, US-05) — domain invariant
**Given** a learner imports a subtitle file with level B2 and maximum 30
**When** fewer than 30 words in the file are above B2 and fit the purpose
**Then** the dialog proposes only those words, fewer than 30, and never fills the list with words at or below B2 to reach the maximum ("the maximum is a limit, not a target")

### AC-07 (US-02) — domain invariant
**Given** the same subtitle file and level
**When** the learner imports it once with purpose "understand this film" and once with purpose "frequent words for the future"
**Then** the "frequent words" list holds only words common in English generally, while the "understand this film" list may also hold rare words that matter in this film

### AC-08 (US-05) — domain invariant
**Given** a subtitle file with character names, place names, sound captions such as "[door slams]" and formatting marks
**When** the learner imports it
**Then** no name, sound caption or formatting mark is proposed as a word, and the context sentences show the spoken line without captions or marks ("only real vocabulary is proposed")

### AC-09 (US-02) — error
**Given** a learner in the import dialog or in Settings
**When** the learner tries to set the word maximum below 1 or above 100
**Then** the app doesn't accept the value and shows that the maximum must be from 1 to 100

### AC-10 (US-06) — error
**Given** a learner in the import dialog
**When** the learner starts an import with a file that is empty, is not a subtitle file, or holds no English lines
**Then** no words are picked, the learner is back on the main screen with the current session unchanged, and the app says the file has no English subtitles to read; opening the import dialog again shows the same purpose, level and maximum

### AC-11 (US-06) — error
**Given** a learner in the import dialog
**When** the learner chooses a subtitle file larger than the size the app accepts
**Then** the file is not taken, the import cannot start, and the app says the file is too large and names the largest size it accepts

### AC-12 (US-06) — error
**Given** an import is running
**When** there is no connection, the picking takes too long, or the list comes back incomplete
**Then** no partial list is shown, the learner is back on the main screen with the current session unchanged, and the app says the words couldn't be picked and they can try again from the speed dial

### AC-13 (US-01) — authorization
**Given** someone who is not using the learner's app, such as a partner with a shared link or a stranger who found the service
**When** they try to have words picked from a text
**Then** the service refuses and picks nothing, so only the learner's app can spend the learner's word-picking allowance; the shared page offers no subtitle import

### AC-14 (US-06) — authorization
**Given** a learner's app has already run many subtitle imports within a few minutes
**When** it starts one more over the allowed number
**Then** that import is refused, the learner is back on the main screen, and the app says to wait a few minutes and try again

### AC-15 (US-05) — cross-context
**Given** the current session already holds the word "reluctant"
**When** the learner imports a subtitle file in which "reluctant" qualifies
**Then** "reluctant" is not proposed, and its place within the maximum can go to another word

### AC-16 (US-04) — cross-context
**Given** a subtitle import is running
**When** the current session is no longer the one the import started in by the time the words come back
**Then** the words are dropped and neither session changes (the edit-session-from-history rule for late results); while the loading dialog is showing, the learner cannot switch sessions

### AC-17 (US-07) — cross-context
**Given** words from a subtitle import were added to the current session
**When** the learner opens the words table, shares the session as a link or as a file, or opens it from History
**Then** those words appear exactly like words typed by hand — with no source photo — in every one of these places

### AC-18 (US-04) — happy
**Given** the results dialog is open after a photo import or a subtitle import
**When** a proposed word has a definition
**Then** it is labelled "Definition", the same term the rest of the app uses, not "Description"

### AC-19 (US-02, US-05) — domain invariant
**Given** a subtitle file in which far more words qualify than the word maximum of 20
**When** the learner imports it with purpose "understand this film", and again with purpose "frequent words for the future"
**Then** the first list keeps the 20 words most needed to follow this film and the second keeps the 20 most common in English generally, each shown most important first; raising the maximum to 30 keeps those same 20 at the top ("the most important words come first")

### AC-20 (US-04, US-06) — happy
**Given** a valid English subtitle file in which no word qualifies, because every word is at or below the chosen level or already in the current session
**When** the learner imports it
**Then** the results dialog opens without the photo timing line (showing only the model, time and cost line of AC-21) and says "No new words above your level in these subtitles.", and Done leaves the current session unchanged

### AC-21 (US-02) — happy
**Given** a learner who chose Haiku 4.5 as the subtitle model in Settings
**When** the learner runs a subtitle import and later a photo import
**Then** the subtitle words are picked by Haiku 4.5 and the results dialog shows a line naming Haiku 4.5 with the time taken and the approximate cost of the import; the photo import still uses its usual model; a model that is not on the offered list is refused by the service

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Time to results dialog, feature-length film (≤ 2 h of subtitles), maximum 20 | p95 ≤ 30 s with the default model (Sonnet 5) | on the phone, from tapping start in the import dialog to the dialog opening, over 5 test films |
| Time to results dialog, feature-length film, maximum 100 | no hard target (owner decision 2026-09-30); measured per model and shown in the results dialog (AC-21) | same 5 test films, once per offered model |
| Largest subtitle file accepted | exactly 1 MB (a 2-hour film is typically 50–150 KB) | a 1 MB test file imports; a 1 MB + 1 byte file gets the AC-11 message naming 1 MB |
| Complete-or-nothing results | 0 partial lists shown | device pass: 5 test films at maximum 100, each dialog shows the full list or the AC-12 message |
| Import allowance per app address | ≤ 10 subtitle imports per 10 minutes | the 11th import in 10 minutes gets the AC-14 message |
| Import allowance across all addresses | ≤ 20 subtitle imports per UTC day (owner decision 2026-09-30) | the 21st import of a UTC day, from any address, gets the AC-14 message |
| Word maximum respected | 100% of imports propose ≤ the maximum | automated check on the proposed list before the dialog opens |

## 6.1 Security / privacy

- **Data classification:** internal. Subtitle text is published film dialogue, not personal data, but it is sent to the server and on to the AI provider.
- **Personal data touched:** none new. The default and last-used import purpose, English level and word maximum, and the remember switch, are stored on the device as preferences only.
- **AuthZ/AuthN impact:** the word picking from subtitles accepts only requests from the learner's app, checked the same way as the photo word picking. Nothing on the shared page can reach it.
- **Abuse cases:**
  - Free AI through a leaked app secret (the sharpest vector — the secret ships inside the app): the service accepts only a bounded list of short dialogue lines (the app strips the file first), only the models on the offered list, applies the per-address import allowance and the daily cap across all addresses (AC-14), and returns only picked words, so it cannot be used as a general AI.
  - Instructions hidden in the subtitle text ("ignore the above…"): the text is treated only as film dialogue; the reply is a word list and nothing else.
  - Very large or repeated uploads to run up cost: refused above the size limit (AC-11) and over the allowance (AC-14).
  - Swearing on a shared page the partner opens: slang and swearing may be proposed (owner decision), but the learner removes them in the results dialog before anything reaches the session.
- **Security review:** Required — a new AI-backed service entry point with a paid model behind an app-embedded secret.

## 7. Metrics / KPIs

<!-- N/A: owner decision 2026-09-30 — no KPIs are tracked for this feature; the §6 targets and the device pass are the check. -->

## 8. Open questions

None.
