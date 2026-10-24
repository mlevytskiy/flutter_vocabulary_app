---
status: Reviewed
owner: "Maksym (learner, app owner); decisions delegated to a Fable 5.1 owner proxy, 2026-10-23"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-23"
feature_size: "L"
---

# Spec — learn-redesign

> **Glossary:** [project CONTEXT](../../../CONTEXT.md) (learning session, exercise page, word ladder, Leitner box, due word, learning companion, learn preset, Talk with AI added 2026-10-23 for this feature)
> **Reference module / docs / channels used:** [owner brief](./owner-brief.md) (the owner's words and picks from the options deck), `docs/architecture.md`, `lib/features/learn/exercises.dart`, `lib/features/learn/learn_screen.dart`, `lib/features/learn/exercise_screens.dart`, `lib/features/learn/kit/`, `lib/features/words_table/widgets/learn_share_bar.dart`, `lib/core/story/word_grouping.dart`, `lib/core/models/word_result.dart`, `docs/features/learn-kit/spec.md`.

## 1. Context

Today a learner who taps Learn on the words table lands on a list of thirteen exercises in three steps, has to tick some, pick a word group and tap Start; each ticked exercise then opens as its own screen with its own rounds and summary, one after another. The learner has to know the exercises to choose well, nothing mixes them, and nothing says at the end how well each word is known or when to come back. The owner wants Learn to mean "start learning now".

Why now: the eleven newer of the thirteen exercises and the shared exercise kit shipped on 2026-10-15/16, so there is finally enough variety to mix. The owner reviewed an options deck on 2026-10-23 and picked: a Learn sheet with two modes (A2) plus a split checkbox, a learning-companion drop-down beside Learn, word-ladder sessions inside groups of 7–12 (B2+B3), one card-and-check page frame (C1), Leitner boxes (D2), learn presets in settings (E2), and Talk with AI typed first, then spoken through the phone's own speech recognition (V3).

Committed approach: the Learn button keeps its look and place; a small button beside it drops down the learning companions (alone works; with teacher and with friend show "Soon"). Learn opens a sheet with two cards, Exercises and Talk with AI, the due count, a gear to Learn settings, and — only for 20 or more words — a remembered "Split words into groups of 7–12" checkbox. Exercises starts a learning session at once: the app picks due words first, then new words, takes 2–3 random exercise types per step from the learner's learn preset, cuts them into exercise pages and plays them in word-ladder order in one card-and-check frame. A miss moves the word one rung down and back into the queue. At the end each word's Leitner box moves (up after a clean ladder, to box 1 after any miss), and a results screen shows know well / shaky / new with each word's next review. Talk with AI is a typed conversation that steers toward the session's words; the app ticks words the learner used with the same word check as the exercises, and the end feeds the Leitner boxes the same way. Voice comes last: the phone turns speech into text and reads the AI's replies aloud.

- Decision source: every product decision in this spec was made by a Fable 5.1 owner proxy, because the owner delegated them on 2026-10-23 ("use a Fable 5.1 subagent instead of me"); the owner approved the visible changes, the per-word box record, the speech-recognition package and the talk allowance ("everything else I approved").
- The old Learn page with its exercise list stays, reached only from "Try it" on an exercise in Learn settings, so every exercise can still be opened alone as today.
- Mnemonic story and Dialogs from movie are whole AI screens: they stay out of the session mix and every preset and are reached only through "Try it" (owner proxy, 2026-10-23).
- Which words a learning session or a talk takes, the ladder's rules and the result states are fixed in AC-06, AC-07, AC-09, AC-12 to AC-15 and AC-20 to AC-22 (owner proxy answers, 2026-10-23).
- Talk turns use the cheapest capable AI and a daily allowance like the story limit; raising the allowance above the story limit's level is a money decision for the human owner.

## 2. Goals

- A learner starts learning with two taps (Learn, Exercises) and no exercise choices, and still meets a varied mix of exercises.
- At the end of every learning session the learner knows, per word, whether it is known, shaky or new and when it comes back, and the next session brings back due words first.
- A learner can practise the same words by conversation, typed or spoken, with the app keeping score the same way.

## 3. Non-goals

- Learning with a teacher or a friend: both only show as "Soon" in the drop-down. They need accounts or a link between two phones, which the app does not have.
- Real-time voice calls with an AI (stream both ways, interrupt mid-sentence): too costly; turn-by-turn speech is enough to test the idea.
- Showing Leitner boxes on the shared page, in exported files, on lightning icons or on the Collections screen: the box lives only in the app's learn screens and the results screen for now.
- Changing the content or the AI data of any existing exercise: exercises are cut into pages and restyled, not rewritten.

## 4. User stories

### US-01: Start learning in two taps
**As a** learner
**I want** Learn to offer only Exercises or Talk with AI and then start
**So that** I learn without having to understand thirteen exercise names first

### US-02: Pick who I learn with
**As a** learner
**I want** a drop-down beside Learn with learn alone, with teacher and with friend
**So that** I see the choice now and use alone today

### US-03: Learn a big collection in small groups
**As a** learner with 20 or more words in a collection
**I want** to split the words into groups of 7–12 and learn one group per session
**So that** a session stays short and focused

### US-04: Learn through a mixed session
**As a** learner
**I want** a session that mixes single exercise pages and brings a missed word back soon
**So that** every word is met, practised and used before the session ends

### US-05: See how well I know each word
**As a** learner
**I want** a results screen with each word's state and next review
**So that** I know what to repeat and when

### US-06: Repeat words when they are due
**As a** learner
**I want** due words to come first in the next session and the due count shown before I start
**So that** I review words before I forget them

### US-07: Choose the exercise mix once
**As a** learner
**I want** learn presets and per-exercise switches in Learn settings, and to try any exercise alone
**So that** sessions match the time and effort I want

### US-08: Practise words by talking with an AI
**As a** learner
**I want** a conversation where the AI steers me toward my words and the app ticks the words I used
**So that** I practise using words, not only recognising them

### US-09: Talk by voice
**As a** learner
**I want** to speak my answers and hear the AI's replies
**So that** I practise speaking the words aloud

## 5. Acceptance criteria

### AC-01 (US-01) — happy path
**Given** a learner on the words table of a collection with at least one word to learn
**When** the learner taps Learn
**Then** a sheet opens with two cards, Exercises and Talk with AI, the collection's word count and due count, and a settings gear; the Learn button itself looks and sits exactly as before

### AC-02 (US-01) — happy path
**Given** the Learn sheet is open
**When** the learner taps Exercises
**Then** a learning session starts at once on its first exercise page, with no exercise list and no Start button in between

### AC-03 (US-01) — error
**Given** a collection with no word to learn (no row has both a word and a translation or definition)
**When** the learner taps Learn
**Then** no sheet opens and the app says that words with a translation are needed before learning

### AC-04 (US-02) — happy path
**Given** a learner on the words table
**When** the learner taps the small button beside Learn
**Then** a drop-down shows Learn alone (ticked), With teacher and With friend; the last two are greyed with "Soon" and cannot be picked

### AC-05 (US-03) — happy path
**Given** a collection with 20 or more words to learn
**When** the Learn sheet opens
**Then** it shows "Split words into groups of 7–12", ticked the first time and as last left for this collection afterwards, and the line under it names the next group and its word count

### AC-06 (US-03) — domain invariant
**Given** a collection with fewer than 20 words to learn
**When** the Learn sheet opens and the learner starts Exercises
**Then** there is no split checkbox and the learning session takes all the words; with 20 or more words and split ticked the session takes one group, and every group the split makes holds no fewer than 7 and no more than 12 words; with 20 or more words and split unticked the session takes all words, or at most the "Words per session" setting (10, 20, 30 or All; All by default), due words first, then new words, then the others

### AC-07 (US-03) — happy path
**Given** split is on and the collection has several groups
**When** the learner finishes a learning session
**Then** the session covered only one group, chosen as the first group (in group order) holding due words, else the first holding new words, else the group after the last one learned; the results screen offers "Next group", which applies the same rule skipping the group just played

### AC-08 (US-04) — happy path
**Given** a learning session has started
**When** the learner answers pages
**Then** each step uses min(3, switched-on) randomly drawn exercise types of that step (at least one), pages of different exercises are mixed, each word first meets step 1 pages, then step 2, then step 3, and the top shows three step segments and "page N of M"; Mnemonic story and Dialogs from movie never appear in a session

### AC-09 (US-04) — domain invariant
**Given** a word on the Practise rung
**When** the learner misses its page
**Then** the word moves back to the Meet rung and returns 3 pages later (or at the end of the queue when fewer pages remain), never as the very next page while other words remain; one right page moves a word up one rung, a miss on Meet keeps it on Meet, "I didn't know it" on Remember or not is a miss, and the session ends only when every word has passed a Use page

### AC-10 (US-04) — happy path
**Given** any exercise page
**When** the learner answers and taps Check
**Then** a verdict bar shows right or wrong, the word with its translation, and Continue; the page frame (card, answers, Check, verdict bar) is the same for every exercise in every theme

### AC-11 (US-04) — error
**Given** a learning session whose AI exercise data cannot be loaded
**When** the session starts or reaches a page needing that data
**Then** the learner sees one plain error line with Retry; pages that need no AI data (such as Remember or not) still play, and no page shows half-filled content

### AC-12 (US-05) — happy path
**Given** the learner passes the last page
**When** the results screen opens
**Then** it shows how many words are known well (no miss in the session), shaky (a miss, and the word was not new before the session) and new (a miss, and the word was new before the session), each word with its next review ("in 4 days", "tomorrow"), "Practise N shaky words" when any are shaky (a new learning session on those words), "Next group" when split is on, and Done

### AC-13 (US-05, US-06) — domain invariant
**Given** a word finishes a learning session
**When** its Leitner box is updated
**Then** a word with no miss in the session moves up exactly one box (a new word goes to box 1, box 5 stays 5) and a word with any miss goes to box 1; the next review is 1, 2, 4, 8 or 16 days after the session for box 1 to 5; the box moves once per word per session, and a word moves up at most once per calendar day (it can still drop to box 1 on a miss the same day); "Practise N shaky words" and a talk are sessions too

### AC-14 (US-06) — happy path
**Given** a collection where some words are due
**When** the learner starts Exercises
**Then** the session's words are chosen as in AC-06 and AC-07 (due words first), the Learn sheet showed the due count before starting, and within the session due words get their pages first

### AC-15 (US-06) — cross-context
**Given** a word with a Leitner box
**When** the learner deletes the word, edits its English word, or bins its collection
**Then** a deleted or binned word never appears in a session or count; a word whose English word changed starts again as new; editing only its translation keeps its box; a box belongs to one word row of one collection, so the same English word in another collection has its own box, and restoring a binned collection brings its boxes back; step-3 pages inside a learning session do not write the step-3 exam's known-or-repeat word result, while an exercise opened alone through "Try it" still does

### AC-16 (US-05) — error
**Given** a learning session in progress
**When** the learner leaves it before the last page (close or Back) and confirms "Leave the session? Progress in this session is lost."
**Then** no Leitner box changes for any word of that session and the words table shows as before; a session killed with the app does not resume

### AC-17 (US-07) — happy path
**Given** a learner taps the gear on the Learn sheet
**When** Learn settings open
**Then** they show the learn presets Quick (about 5 min, one-word answers only: Match synonyms, Match word and definition, Pick the right answer; Remember or not, Fill the gaps; Quiz), Balanced (picked by default: Match synonyms, Match word and definition, Guess my word, Pick the right answer; Fill the gaps, Remember or not, Sentence patterns; Quiz, Translate sentences, Make your own sentences), Deep (all eleven page exercises) and Custom, the "Words per session" setting, and the thirteen exercises grouped by step: eleven with switches, Mnemonic story and Dialogs from movie with "Try it" only; picking a preset sets the switches, changing a switch selects Custom

### AC-18 (US-07) — domain invariant
**Given** Learn settings in Custom
**When** the learner turns off the last exercise of a step
**Then** the switch refuses to turn off and the screen says each step needs at least one exercise (Mnemonic story and Dialogs from movie do not count)

### AC-19 (US-07) — happy path
**Given** Learn settings are open
**When** the learner taps "Try it" on an exercise
**Then** the old Learn page opens with that exercise ticked, the group pager and Start working as today

### AC-20 (US-08) — happy path
**Given** the Learn sheet is open
**When** the learner taps Talk with AI and types replies
**Then** the talk takes the same words a learning session would (AC-06, AC-07); the AI sets a scene from text already stored (the group's mnemonic story, else a film dialogue, else the collection's name and description) and asks questions; each of the talk's words the learner uses in a reply is ticked in a word strip; the talk ends by itself after 12 learner replies or when every word is used, and the learner can end it at any time

### AC-21 (US-08) — domain invariant
**Given** a talk in progress
**When** the AI's reply contains a session word or claims the learner used one
**Then** only the learner's own replies tick words, by the same whole-word rule the exercises use; after two of the learner's replies without the AI's targeted word, a Hint offers that word

### AC-22 (US-08) — cross-context
**Given** a talk that ends with Done
**When** its words are scored
**Then** a word used without a hint counts as a clean ladder, a word used after its hint counts as a miss, and a word never used keeps its box and next review; the shared results screen lists the used words and one line "N words not used — unchanged"; a talk left without Done changes no box

### AC-23 (US-08) — authorization
**Given** a partner opening a collection's shared link, or anyone other than the app
**When** they try to start Talk with AI or reach the talk service
**Then** Talk with AI is not offered on the shared page and the talk service refuses anyone but the app, so a shared link never spends AI money

### AC-24 (US-08) — error
**Given** the app-wide daily talk allowance is used up
**When** the learner sends a reply or starts a talk
**Then** starting a talk beyond 20 talks in a day (app-wide) is refused with "Today's talk limit is reached. Try again tomorrow."; a reply inside a talk already started is never refused for the limit

### AC-25 (US-09) — happy path
**Given** a talk in progress on a phone that allows speech recognition
**When** the learner holds the talk button and speaks
**Then** the spoken words appear as the learner's reply and are sent, and the AI's reply is read aloud

### AC-26 (US-09) — authorization
**Given** the learner has refused the phone's microphone or speech permission
**When** the learner holds the talk button
**Then** the app says it needs the permission and how to give it, and typing keeps working

### AC-27 (US-01, US-02) — authorization
**Given** the shared page of a published collection
**When** a partner opens it
**Then** the shared page's Learn and exercises stay as today: no Learn sheet, no companion drop-down, no Leitner box shown

### AC-28 (US-09) — happy path
**Given** Learn settings are open
**When** the learner picks the speech recognition engine — "speech_to_text" (default) or "speech_to_text_pro"
**Then** the choice is remembered, the next hold-to-talk in Talk with AI uses that engine, and an engine that is not available on the phone shows the same permission/unavailable message as AC-26 while typing keeps working (owner, 2026-10-24)

### AC-29 (US-09) — happy path
**Given** a talk in progress with hands-free on (the default; the headset in the Talk bar or Learn settings switches it) and the pause set to N seconds (2, 3, 4 default, or 6, in Learn settings)
**When** the AI's opening or reply arrives
**Then** it is read aloud first, and only once it has finished the app listens without any tap, showing the words in the reply field and "Listening… pause N s to send"; N seconds of silence after the learner's words send them; when the recognizer stops early by itself it listens again and keeps the earlier words; nothing heard for 60 s stops listening with "Didn't hear anything — tap the mic to talk"; it never listens while the AI's line is being spoken or the AI's reply is awaited; the mic pauses and resumes listening; leaving the talk, its end, the day limit or an error stops it; with hands-free off the mic works by tap or hold as in AC-25 (owner, 2026-10-24)

### AC-30 (US-09) — happy path
**Given** Learn settings are open
**When** the learner looks at "AI voice"
**Then** the phone's installed English voices are listed best first with "Premium", "Enhanced" or "Standard", the best one is picked until the learner picks another, the pick is remembered and used for the AI's spoken lines in Talk with AI, "Play sample" says "Hello! Let's practise your words." in the picked voice, and on iOS a line says where to download an Enhanced or Premium voice (owner, 2026-10-24)

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Tap Exercises → first page shown (AI data cached) | ≤ 1 s, worst of 20 taps | stopwatch log in a debug build on iPhone 15, 20 sessions |
| Tap Exercises → first page shown (AI data not cached) | ≤ 6 s, worst of 10 taps | same debug-build log, cache cleared, 10 sessions |
| Talk reply, typed: send → AI text shown | ≤ 4 s, 19 of 20 replies | debug-build log on iPhone 15, 20 replies |
| Talk reply, spoken: release → first spoken word | ≤ 6 s, 9 of 10 replies | manual stopwatch, 10 replies each on iPhone 15 and one Android phone |
| Talk AI cost | 1 cheap-model call per learner reply plus 1 opening; ≤ 20 talks per UTC day app-wide, ≤ 12 learner replies per talk | Worker allowance counter |
| Leitner update | box writes for a whole session commit together or not at all | store test |
| Frame consistency | the page frame renders in all 5 themes with no overflow at 393 pt and text scale 1.3 | widget golden-free layout tests per theme |

## 7. Success metrics (KPIs)

| KPI | Baseline | Target | Window |
|---|---|---|---|
| Sessions started per week by the owner | 0 (sessions do not exist) | ≥ 5 | first 4 weeks after release |
| Sessions finished / started | n/a | ≥ 70 % | first 4 weeks |
| Due words reviewed within 1 day of due date | n/a | ≥ 60 % | weeks 2–6 |
| Talks ended with Done, with ≥ half the words used | n/a | ≥ 50 % of talks | first 4 weeks |

Measured on the owner's own device by reading the session and box records; the app sends no analytics.

## 8. Open questions

- None open. Escalation kept for the human owner: raising the daily talk allowance above the story limit's level (owner, when usage shows it is needed).
