---
status: Reviewed
owner: "Maksym (learner, app owner); open questions answered by a Fable 5.1 owner proxy, 2026-10-30"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "M"
---

# Spec — word-context

> **Brief:** [learn-welcome owner-brief](../learn-welcome/owner-brief.md) (picks B1–B12, proxy answers Q12–Q14, Q16) ·
> **Decision page:** https://claude.ai/artifact/8CJZbtjwD23XEAibdd7mz8 · **Used by:** [learn-welcome](../learn-welcome/spec.md) AC-12, AC-18.

## 1. Context

A word row keeps the word, translation, definition and the id of its photo, film or Quizlet set (`sourceId`), but
not how it was entered, whether the learner changed what the app filled in, or a sentence that shows the word in
use. Learn's mnemonic stories and cards need all three.

## 2. Goals

- Every word knows its source type and, for a film, the film's name, season, episode and time.
- Every word knows whether its translation and description were changed by the learner.
- Words get a context sentence where one can be had cheaply, marked by where it came from.

## 3. Non-goals

- Editing the context by hand (the popup is read-only, Q16).
- Re-analysing old photos or re-downloading old subtitles to backfill.
- Showing context on the shared page or in exports.

## 4. User stories

- **US-01** As a learner I want each word to remember where it came from, so stories and cards can mention it.
- **US-02** As a learner I want a real sentence with the word, so I see how it is used.

## 5. Acceptance criteria

- **AC-01 (US-01) Origin record.** Each row has `WordOrigin`: `typeOfSource` (manuallyEntered, movie, image, set),
  `movieName`, `season`, `episode`, `time` (movie only; each may be empty), `wasTranslationEditByUser`,
  `wasDescriptionEditByUser`; and `context` (text, may be empty) with `contextKind` (none, source, ai).
- **AC-02 (US-01) New rows.** A typed row is manuallyEntered; a photo row image; a subtitle row movie; a Quizlet row
  set. Both flags start false.
- **AC-03 (US-01) Old rows.** On first load after the update, rows without an origin get the type of their
  `sourceId`'s source kind (photo → image, subtitles → movie, set → set), else manuallyEntered; flags false; movie
  name, season and episode from their film source when it has them.
- **AC-04 (US-01) Edit flags.** Any change of the translation (typing, or picking another option from the ⋯ list)
  by the learner sets `wasTranslationEditByUser`; the same for the definition and `wasDescriptionEditByUser`. A
  value the app fills (lightning, import) does not.
- **AC-05 (US-01) Word changed.** Changing the English word clears `context`, `contextKind` and both flags and keeps
  `typeOfSource` and the movie fields.
- **AC-06 (US-01) Film found by name.** A film picked from the subtitle search keeps the suggestion's title (or
  show), season and episode on each of its rows.
- **AC-07 (US-01) Film from a file.** A subtitle file opened by the learner gives season and episode from its name
  (`S02E05`, `s2e5`, `2x05`); not found → empty. The movie name is the source's name.
- **AC-08 (US-01) Film time.** Each film row's `time` is the start of the first subtitle line that has the word
  (whole-word match); empty when none matches.
- **AC-09 (US-02) Film context.** A film row's context is the parsed subtitle line already sent for the word,
  `contextKind = source`.
- **AC-10 (US-02) Photo context.** The photo recognition request returns the photo's full text and, per word, the
  sentence or phrase around it (`source`); on an exercise sheet or word list with no real sentence, a sentence the AI
  writes (`ai`). The full text is kept on the photo source (`SessionSource.fullText`).
- **AC-11 (US-02) Typed and set context.** A typed or Quizlet row with a definition gets the dictionary example of
  that sense from our define API (`source`); none → empty. A translation-only row stays empty. A Quizlet definition
  is never used as context.
- **AC-12 (US-02) Backfill.** At launch, in the background, rows with an empty context are filled: typed and set rows
  with a definition from the define API; film rows from a stored dialogue line containing the word; photo rows from
  their photo's stored full text. At most 20 words a minute; a row tried once and still empty is not tried again
  until its word or definition changes.
- **AC-13 (US-02) Words popup.** The Words screen's word popup shows the context in italic, read-only, with "from the
  source" (grey) or "written by AI" with the sparkle in `AppDecor.aiAccent`; nothing when empty.
- **AC-14 (US-01) Kept.** The new fields survive edits, moving rows, the recycle bin, sharing a collection's JSON
  copy and the new-user trial's put-aside, like the other row fields.

## 6. Non-functional requirements

- **NFR-01** Photo context costs no extra request (same `/analyze` call).
- **NFR-02** Backfill never blocks the UI and stays under 20 define calls a minute.
- **NFR-03** CLAUDE.md rule 5 records `WordOrigin`, its enum, `WordPair.origin`/`context`/`contextKind`, the enum
  `ContextKind` and `SessionSource.fullText` (owner B2, 2026-10-30); rule 3 records AC-13 (owner B10).

## 7. Open questions

None.
