---
status: Reviewed
owner: "Maksym (learner, app owner); open questions answered by a Fable 5.1 owner proxy, 2026-10-30"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
---

# Spec — learn-welcome

> **Brief:** [owner-brief.md](./owner-brief.md) (the owner's words, picks A1–A20 and the proxy answers Q1–Q17) ·
> **Decision page:** https://claude.ai/artifact/8CJZbtjwD23XEAibdd7mz8 · **Builds on:** [learn-redesign](../learn-redesign/spec.md),
> [talk-mixed](../talk-mixed/spec.md), [mnemonic-story](../mnemonic-story/), [self-check-cards](../self-check-cards/spec.md) (merged, A15) ·
> **Needs:** [word-context](../word-context/spec.md) for AC-12 and AC-18.

## 1. Context

Today Learn opens a sheet (Exercises, Talk with AI, a split checkbox) and a session plays one group of 7–12 words.
The owner wants Learn to start a guided session instead: a two-question warm-up on the Talk screen that prepares the
main AI dialog, then flip cards the learner rates, with mnemonic story pictures between the cards, then the main
dialog on the chosen topic, then results. Self-check Cards (planned 2026-10-27) is merged: one card widget and one
set of rating rules for the whole app.

## 2. Goals

- Learn starts with two taps of answers and no settings to understand.
- Every learned word gets a rating that moves its Leitner box; up to 3 story pictures help remember the words.
- The main dialog is about a topic the learner chose and as long as they chose.

## 3. Non-goals

- Changing exercises or their sessions (they open from the results screen as today).
- An AI word grouping: the split is on the phone (ADR-0002).
- Editing a story from the flow (Story runs keeps its own screens).

## 4. User stories

- **US-01** As a learner I want Learn to ask me what to talk about and how hard to work, so the talk fits me.
- **US-02** As a learner I want to rate how well I know each word on a flip card, so my boxes follow what I know.
- **US-03** As a learner I want story pictures between the cards, so the words stick.
- **US-04** As a learner I want a talk on my topic and length after the cards, and a summary at the end.

## 5. Acceptance criteria

- **AC-01 (US-01) Entry.** Learn on the Words screen opens the warm-up at once; the Learn sheet is gone. A
  collection with fewer than 4 words shows the snackbar "Add at least 4 words to learn" and opens nothing.
- **AC-02 (US-01) Warm-up.** The Talk screen in warm-up mode: a 2-step bar on top, two AI questions answered with
  the talk's tap choices, no Skip. Q1 "What would you like to talk about?" with 3 topics and "My own topic…";
  Q2 "Ready to work hard, or easy mode today?" with Hard / Easy. Both are asked fresh every time. The top bar keeps
  a gear to Learn settings.
- **AC-03 (US-01) Topics.** The Worker keeps 50 topics (`{id, title ≤ 4 words, description, keywords 5–10}`);
  `POST /learn/topics` with the card words returns the 3 topic ids that fit best. A failure or no answer within 4 s
  shows the 3 bundled topics Daily routine, Food and cooking, Travel. Neither call counts toward the daily talks.
- **AC-04 (US-01) Own topic.** "My own topic…" takes typed or spoken text up to 80 characters; Send is disabled
  while it is empty; the text is used as it is.
- **AC-05 (US-02) Card words.** Up to 36 words, from the first due-or-new word of the list on, in list order. When
  no word is due or new, the 36 words due soonest (list order among equal dates).
- **AC-06 (US-03) Split.** The card words are cut in order into groups of up to 12. When the last words of a full
  group (up to 4) come from another source than the word before them, they start the next group. A source is the
  row's photo, film or Quizlet set (`sourceId`), or typing. Only the first 3 groups get a story; 4–7 words make one
  group.
- **AC-07 (US-02) Card.** Front: the Ukrainian translation (recall the English word) or the English word (recall the
  meaning), switched per word across sessions by `WordBox.lastCheckSide` (none → Ukrainian). Flip shows the word,
  its sound, the translation and the context. The four buttons I don't remember / Hard / Medium / Easy are disabled
  until the flip; under each is the box it leads to. A counter "Card N of M" replaces the bar.
- **AC-08 (US-02) Rating.** From the box before (new = 0): I don't remember → 1; Hard → max(1, box − 1); Medium →
  stays (new → 1); Easy → min(5, box + 1); up at most once a calendar day (`lastUpDay`); next review = start of today
  + 1/2/4/8/16 days. The move and the shown side are saved when the card is rated.
- **AC-09 (US-03) Story start.** When the cards open, each of the first 3 groups gets its story: a finished saved
  story whose set of row ids equals the group's is reused; otherwise a new story run starts in the background.
- **AC-10 (US-03) Story slot.** A group's story page comes right after its last card when the picture is ready;
  otherwise after up to 5 more cards as soon as it is ready; otherwise a "Writing your story…" page with a progress
  bar waits, and opens the story by itself when ready. Its "Skip, show it later" moves the story to the next story
  slot, else just before the main dialog; a story still not ready then stays only in Story runs and the results say
  "Story saved to Story runs". A last group with no cards after it goes straight to the wait page.
- **AC-11 (US-03) Landscape.** The story page is the picture alone (its captions are in the picture), full screen in
  landscape; the screen turns by itself on it and back to portrait on the next page. Every other screen of the app,
  on phones and tablets, is portrait only.
- **AC-12 (US-03) Story prompt.** A story run started by this flow sends each word's context, source (film name,
  photo) and the learner's edited translation to the story writer (word-context B11).
- **AC-13 (US-04) Main dialog.** After the cards and stories, the Talk screen runs a mission on the chosen topic:
  Easy ends after 6 learner replies with min(6, ceil(N/2)) practice words (at least 4), Hard after 12 with
  min(12, N); words rated "I don't remember" today come first, then Hard, then list order. The mission picture is
  made during the cards. The dialog counts as one daily talk; when the limit is reached it is skipped and the
  results say "Daily talk limit reached".
- **AC-14 (US-04) Dialog and boxes.** Dialog results are recorded per word (used / after hint / missed / unused) and
  never move a box; missed and hinted words get the quick check's self-check card (self-check-cards AC-11).
- **AC-15 (US-04) Results.** Three parts: Cards (count per rating, words moved up or down), Stories (a thumbnail per
  story shown or reused), Talk (used / after hint / missed / unused); then "N words due tomorrow"; then Exercises ·
  Talk with AI · Done.
- **AC-16 (US-02) Leave.** Back asks with the existing leave dialog. Ratings already saved stay; running stories
  finish into Story runs; warm-up answers and dialog progress are dropped.
- **AC-17 (US-01) Removed.** The Learn sheet, the "Split words into groups of 7–12" checkbox and the group line are
  removed; Learn settings stays (gear in the warm-up's top bar).
- **AC-18 (US-02) Context on the card.** The card back shows the word's context in italic with "from the source"
  (grey) or "written by AI" with the sparkle in `AppDecor.aiAccent`; nothing when the context is empty.

## 6. Non-functional requirements

- **NFR-01** The warm-up never blocks: topics within 4 s or the fallback.
- **NFR-02** No AI call for the split; the split of 36 words takes under 5 ms (pure Dart).
- **NFR-03** Cost: one cheap topic pick per Learn, at most 3 new story runs (each a reuse when possible), one talk.
- **NFR-04** CLAUDE.md rules 1–7; visible changes recorded in rule 3, `WordBox.lastCheckSide` in rule 5.

## 7. Open questions

None (answered in the brief).
