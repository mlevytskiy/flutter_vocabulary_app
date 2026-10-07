---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-07"
feature_size: "M"
---

# Spec — get-words-from-subtitles-improvment

> **Glossary:** [feature CONTEXT](./CONTEXT.md) · [words-from-subtitles CONTEXT](../words-from-subtitles/CONTEXT.md) · [mnemonic-story CONTEXT](../mnemonic-story/CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · repo-root [CONTEXT](../../../CONTEXT.md)
> **Reference module / docs / channels used:** [`words-from-subtitles/spec.md`](../words-from-subtitles/spec.md) · [`mnemonic-story/spec.md`](../mnemonic-story/spec.md) · `vocab-photo-api/src/subtitles/prompt.ts` (what the word-picking AI receives today) · `vocab-photo-api/src/learn/exercises.json` (the exercise list) · `CLAUDE.md` rules 3 and 5

## 1. Context

A subtitle import gives the learner a list of words, each with the single line it came from. Then the film is gone. The words land in the session as a flat list, and the learn page splits them into topic groups that have nothing to do with the film. What made the words memorable (a joke, a quarrel, a funny exchange) is lost. In the owner's words: "After getting words from subtitles also get 7-10 dialogs (maybe jokes or other interesting dialogs) that help us to split words in groups for learnings."

Why now: subtitle import (words-from-subtitles) and the learn page with mnemonic stories, pictures and story runs (mnemonic-story) are both built. What's missing is the link between them. The owner wants the film's own scenes to be the groups words are learned in. The owner had first floated a film-name hint for the word-picking AI, then put it aside for this feature (decision below).

Committed approach: a new switch in the main screen's Settings, "Get dialogues from subtitles", off by default. With it off, nothing changes. With it on, a subtitle import also picks up to 10 film dialogues, each holding some of the proposed words. After Done, the main screen gets a pager. Its first page is the main screen as it is today. Each following page is one film dialogue, with its dialogue words in bold and listed under it with translation and definition, and its scene picture once one is drawn. The shared page shows the same dialogue pages. On the learn page, a new Step 1 exercise, "Dialogs from movie", uses the dialogues as the word groups: one dialogue group per dialogue that still has words of its own, plus "Other words" for the words in no group. Its Start shows the dialogue with a scene picture, drawn by the picture prompt writer and the picture maker of the learner's AI choice. This rests on three findings. First, research (2026-10-07) found no product that takes the learner's own subtitle file, picks words above their level, groups them by the dialogue they came from with the words in bold, and draws a picture per scene. Migaku comes closest, with a sentence and a screenshot per single card. Second, the sharpest failure found is the AI stitching lines from different scenes, or reworking a joke into a dialogue the film never had. The owner accepts light edits by the AI (decision below), so the guard that remains is that every bold word must really appear in its dialogue (AC-05). Third, learning research supports words met in natural context with a picture, but does not prove dialogue groups beat topic groups. So the plain words table stays the first page, and "Mnemonic story" stays available.

- Decision (owner, 2026-10-07): a film-name hint for the word-picking AI is not part of this feature; it may come later as a separate request to the AI. The word-picking request receives only the dialogue lines, as today.
- Decision (owner, 2026-10-07): dialogues are kept on the session on the device and appear on the shared page, together with their scene pictures (§3, §6.1).
- Decision (owner, 2026-10-07): a word can be a dialogue word of several dialogues and is bold in each, but it belongs to one word group only, that of the first such dialogue in pager order (AC-06).
- Decision (owner, 2026-10-07): "Dialogs from movie" on a dialogue group shows the dialogue and a scene picture, with no AI-written story. On the "Other words" group it shows that group's mnemonic story as today (AC-13).
- Decision (owner, 2026-10-07): the AI may lightly edit a dialogue (for example, shorten it or add speaker marks such as "A:"). The service does not check dialogue lines word for word against the file (owner chose this over "only consecutive lines from the file").
- Decision (owner, 2026-10-07): complete or nothing still holds with dialogues on. A reply that is cut off or incomplete gives neither words nor dialogues, as in words-from-subtitles AC-12 (AC-08).
- Decision (owner, critic resolution 2026-10-07): word groups the session already has, with or without a story, keep their words, name and selection when dialogues arrive; dialogue groups are made only from dialogue words in no group yet, so a dialogue may have a page but no group (AC-17).
- Decision (owner, critic resolution 2026-10-07): no story run starts on its own for a dialogue group; mnemonic-story AC-06 (a run starts when the learn page opens or a group is selected) is narrowed to topic groups and "Other words" (AC-24).
- Decision (owner, critic resolution 2026-10-07): a scene picture is a story run of two steps, picture prompt writer then picture maker, with no story step; it takes one from the story allowance when its picture prompt step starts (AC-14, AC-19).
- Decision (owner, critic resolution 2026-10-07): "Dialogs from movie" joins the exercise list in Step 1 for the app and the web alike, making twelve exercises. In the app it can be ticked only in a session with dialogues and is greyed otherwise; on the web it leads to the coming-soon screen. This narrows the learn-part-step-1 invariant that the app and the web show the same available state (AC-16, AC-22).
- Decision (owner, 2026-10-07): other words form one group when there are 19 or fewer, and are grouped by topic, 7 to 19 each, when there are more. Dialogue groups may be any size. This narrows the mnemonic-story invariant "a word group holds 7 to 19 words" for dialogue groups only.
- Decision (owner, assumptions accepted 2026-10-07): up to 10 dialogues, 7–10 being a goal, not a quota; a dialogue whose words are all removed is not kept; dialogues of later imports are added after earlier ones; editing or deleting a word follows into its dialogues; turning the switch off affects only new imports; a scene picture is drawn only on Start, uses the AI choice, takes one from the story allowance and appears in story runs; "Dialogs from movie" can be ticked only in a session with dialogues; no KPIs.
- New visible parts approved under CLAUDE.md rule 3 by this spec: the Settings switch, the main screen pager with its dialogue pages, the dialogue pages and scene pictures on the shared page, the "Dialogs from movie" exercise and its dialogue screen. A new kind of session data (film dialogues and their scene pictures) is approved under CLAUDE.md rule 5. Both are to be recorded in CLAUDE.md at `design`.
- Decision (owner, clarify 2026-10-07): no hard time target for an import with dialogues on; the time is measured per model and shown in the results dialog's model, time and cost line (§6).
- Decision (owner, clarify 2026-10-07): "Mnemonic story" and "Dialogs from movie" share the session's word groups (dialogue groups, "Other words", and any topic groups). On a dialogue group, "Mnemonic story" makes a story from that group's words, only on Start (AC-24).
- Decision (owner, clarify 2026-10-07): a scene picture is one scene with invented characters and the dialogue's lines in speech bubbles, given to the picture maker exactly as written, as mnemonic-story does with its captions.
- Decision (owner, clarify 2026-10-07): "Other words" is an ordinary word group under mnemonic-story's rules: without a story it takes in new words up to 19; words that don't fit are grouped by topic (7 to 19) or wait when fewer than 7. A session with any dialogue group always shows the group pager, whatever its size (AC-25).
- Decision (owner, clarify 2026-10-07): which rows are a dialogue's words is fixed at Done and can only shrink. A word deleted and typed again, or a row the partner adds on the shared page, never becomes a dialogue word (AC-11).
- Decision (owner, clarify 2026-10-07): new dialogues and scene pictures reach a session's existing shared link the same way word changes do, without sharing again (AC-20).

## 2. Goals

- A learner who imports from subtitles keeps the film's best moments next to the words: every kept dialogue can be reread, with its words in bold, on the phone and on the shared page.
- A learner learns film words in the groups the film gave them: one group per dialogue that has words of its own, with a picture of the scene, and no extra splitting.
- With the switch off, or for sessions without dialogues, the app behaves exactly as before, apart from one greyed exercise on the learn page.

## 3. Non-goals

- **A film-name hint for the word-picking AI:** set aside by the owner (§1); a later, separate request.
- **Checking dialogues word for word against the subtitle file:** the owner accepts light edits; only the bold words are checked (AC-05).
- **Dialogues in the AnkiDroid export or the shared-file export:** exports keep their current form, because a card has no place for a multi-line dialogue.
- **Drawing scene pictures or starting any AI work from the shared page or the web learn page:** a link is the only credential there, so the web learn page keeps its coming-soon screen for this exercise, as for Mnemonic story.
- **Editing a dialogue's text:** neither the learner nor the partner can change a dialogue's lines. They change its words through the words table as usual.

## 4. User stories

### US-01: Turn dialogues on or off
**As a** learner
**I want** a switch in Settings that decides whether subtitle imports also pick dialogues
**So that** I get dialogues only when I want them

### US-02: Get dialogues with the words
**As a** learner
**I want** a subtitle import to also pick a few jokes or memorable dialogues that hold the proposed words
**So that** I meet the words in the scenes they come from

### US-03: Read the dialogues on the main screen
**As a** learner
**I want** to swipe from the words table to one page per dialogue, with its words in bold and listed with translation and definition
**So that** I can reread each scene with its new words

### US-04: Learn words dialogue by dialogue
**As a** learner
**I want** a "Dialogs from movie" exercise that uses each dialogue as a word group and shows it with a picture of the scene
**So that** I remember the words through the film's own moments, without extra splitting

### US-05: Share dialogues with my partner
**As a** partner
**I want** to see the session's dialogues and their scene pictures on the shared page
**So that** I can follow the same scenes as the learner

### US-06: Keep the app as it was when dialogues are off
**As a** learner
**I want** the app to look and work as before when the switch is off or a session has no dialogues
**So that** the new feature never gets in my way

## 5. Acceptance criteria

### AC-01 (US-01, US-06) — happy
**Given** a learner who has never changed the switch "Get dialogues from subtitles" in the main screen's Settings
**When** the learner opens Settings and then runs a subtitle import
**Then** the switch is shown off, the import works exactly as before, and after Done the main screen has no pager and looks as it does today

### AC-02 (US-01, US-02, US-03) — happy
**Given** a learner has turned the switch on, and the current session has no dialogues
**When** the learner runs a subtitle import, keeps some words in the results dialog and taps Done
**Then** the kept words are added to the current session as before, and the main screen now has a pager: its first page is the main screen as today, and each next page is one film dialogue in the order the import gave them, with its dialogue words in bold in the text and listed under it, each with its translation and definition; once a dialogue's scene picture is drawn, its page shows it too

### AC-03 (US-03) — happy
**Given** the results dialog listed 15 words and the import picked 8 dialogues, and the learner removes 4 words, among them every dialogue word of one dialogue
**When** the learner taps Done
**Then** the main screen shows 7 dialogue pages: the dialogue left without words is not kept, and the removed words are neither bold nor listed in any dialogue

### AC-04 (US-02) — domain invariant
**Given** a learner imports with the switch on, word maximum 5, from a file in which many dialogues would qualify
**When** the results dialog opens
**Then** it lists at most 5 words, the import keeps at most 10 dialogues and only those holding at least one of these words, and no word is added to the list to fill a dialogue ("a dialogue never adds a word; the maximum caps words, not dialogues")

### AC-05 (US-02, US-03) — domain invariant
**Given** the AI returns a dialogue linked to a word that does not appear in the dialogue's text
**When** the import's words and dialogues are checked before the results dialog opens
**Then** that word is not linked to that dialogue (it stays a proposed word), and if the dialogue is left with no word that appears in it, the dialogue is not kept ("every dialogue word appears in its dialogue, in bold"). A word appears when it is there as a whole word in any letter case, a phrase when its words are there in order and next to each other, each English word allowing the ending -s, -es, -ed or -ing, as in mnemonic-story AC-08; every place it appears is bold. Likewise, a link to a word the import did not propose is ignored, a dialogue longer than 8 lines is not kept, and when more than 10 dialogues come back only the first 10 are kept; none of these makes the import fail

### AC-06 (US-03, US-04) — domain invariant
**Given** the kept word "reluctant" appears in the second and the fifth dialogue
**When** the learner looks at the dialogue pages and later opens the learn page
**Then** "reluctant" is bold and listed on both pages, but on the learn page it is in the second dialogue's group only ("no word is in two word groups")

### AC-07 (US-02) — happy
**Given** the switch is on, and the subtitle file is valid English but no dialogue holding a proposed word qualifies
**When** the import finishes and the learner taps Done
**Then** the results dialog lists the words as before, the words are added, and no dialogue page is added

### AC-08 (US-02) — error
**Given** the switch is on and an import is running
**When** there is no connection, the picking takes too long, or the reply comes back incomplete, including when the words are complete but the dialogues are cut off
**Then** neither words nor dialogues are shown, the learner is back on the main screen with the current session and its pager unchanged, and the app says the words couldn't be picked and they can try again from the speed dial, as in words-from-subtitles AC-12

### AC-09 (US-01) — error
**Given** the switch is on
**When** the learner starts an import from a file that is empty, is not a subtitle file or has no English lines
**Then** the app shows the same message as words-from-subtitles AC-10, and no dialogue is picked or kept

### AC-10 (US-03) — cross-context
**Given** the current session already has 6 dialogue pages from an earlier import
**When** the learner runs another subtitle import with the switch on and taps Done
**Then** the new dialogues are added after the existing 6, and the existing pages are unchanged; after the app restarts, or when the session is opened from History and made current again, all its dialogue pages are still there

### AC-11 (US-03) — cross-context
**Given** a session with dialogue pages
**When** the learner deletes a dialogue word, edits its English word, or edits its translation or definition in the words table
**Then** a deleted word is no longer bold or listed; an edited English word stays a dialogue word only where its new form still appears in the text (AC-05 rule), and otherwise is no longer bold or listed there; an edited translation or definition shows its new text; a dialogue with no dialogue words left disappears from the pager. Which rows are a dialogue's words is fixed at Done and only shrinks: a word deleted and typed in again, or a row added later, never becomes a dialogue word

### AC-12 (US-03) — cross-context
**Given** a subtitle import with the switch on is running
**When** the current session is no longer the one the import started in by the time the reply comes back
**Then** both the words and the dialogues are dropped and neither session changes, as in words-from-subtitles AC-16

### AC-13 (US-04) — happy
**Given** a session with 7 dialogues and 6 words to learn outside every dialogue
**When** the learner opens the learn page
**Then** "Dialogs from movie" is listed in Step 1 and can be ticked; the group pager shows one card per dialogue group, named after the dialogue's first line without speaker marks, cut to 40 characters with "…" and given "(2)", "(3)" when two names are the same, followed by one "Other words" card; a dialogue with no group of its own (AC-06, AC-17) has no card; ticking "Dialogs from movie" and pressing Start on a dialogue group shows the dialogue with all its dialogue words in bold, as on its page, and starts drawing its scene picture; on "Other words" it shows that group's mnemonic story as today. When both "Mnemonic story" and "Dialogs from movie" are ticked, Start opens them one after the other, in list order. A dialogue word that is not a word to learn (no translation and no definition) is bold and listed on the page but is in no group, and a dialogue group with no word to learn has no card

### AC-14 (US-04) — happy
**Given** a dialogue group whose scene picture has been drawn
**When** the learner opens it again, in this visit or after restarting the app
**Then** the same picture is shown and nothing is drawn or paid again; the drawing appears in story runs as a run of two steps, with the dialogue in place of a story, and with its picture prompt writer, picture maker, price and time

### AC-15 (US-04) — domain invariant
**Given** a session with 3 dialogue groups of 1, 2 and 4 words and 25 other words
**When** the learner opens the learn page
**Then** the three dialogue groups are shown as they are, with no "7 to 19" error and nothing waiting; the 25 other words are grouped by topic into groups of 7 to 19 words; with 19 other words or fewer they would be one "Other words" group ("dialogue groups may be any size; other words follow mnemonic-story grouping")

### AC-16 (US-04) — domain invariant
**Given** a session that has no dialogues
**When** the learner opens the learn page
**Then** "Dialogs from movie" is shown in Step 1, right after "Mnemonic story", greyed out with "Needs dialogues from subtitles" and cannot be ticked, and the groups and Mnemonic story work exactly as before. On the web learn page it can always be ticked and leads to the coming-soon screen, whatever the session holds

### AC-17 (US-04) — cross-context
**Given** a session whose words are already in topic groups, some with mnemonic stories and some without, and the learner then runs a subtitle import with dialogues into it
**When** the learner opens the learn page
**Then** every existing group keeps its words, name, story and selection, as mnemonic-story requires; dialogue groups are made only from the new dialogue words that are in no group yet; a dialogue whose words all already belong to groups has a page on the main screen but no group

### AC-18 (US-04) — error
**Given** the learner pressed Start on a dialogue group
**When** the picture prompt writer or the picture maker fails, refuses or does not answer in time
**Then** the dialogue is still shown. If the picture prompt writer failed, it says "Could not write the picture prompt" and "Try again" redoes only that step in the same run, taking nothing from the allowance, as in mnemonic-story AC-08b. If the picture maker failed, it says "The picture could not be drawn" and "Draw again" redraws only the picture from the same prompt with the picture maker chosen now, as in mnemonic-story AC-09. The failed attempt stays in story runs

### AC-19 (US-04) — domain invariant
**Given** the day's story allowance (20 story runs for the whole app, per UTC day) is used up
**When** the learner presses Start on a dialogue group without a scene picture, or "Draw again" (a "Try again" of the picture prompt step takes none)
**Then** nothing is drawn or paid, and the app says "Today's story limit is reached. Try again tomorrow."; a scene picture takes one from the allowance when its picture prompt step starts, and each "Draw again" takes one

### AC-20 (US-05) — happy
**Given** a learner shares a session that has dialogues, one of which has a scene picture
**When** the partner opens the shared page
**Then** the partner can swipe from the word table to one page per dialogue, in the same order as on the phone, each with its words in bold and listed with translation and definition, and the dialogue that has a scene picture shows it. Dialogues added by a later import and pictures drawn later reach the same link the way word changes do, without sharing again

### AC-21 (US-05) — cross-context
**Given** a partner on the shared page edits a dialogue word's translation, or deletes that word's row
**When** the partner or the learner next looks at that dialogue's page
**Then** the page shows the new translation, or the word is no longer bold or listed, following the same rules as AC-11 on both the shared page and the phone

### AC-22 (US-05) — authorization
**Given** a partner or anyone else holding a session's shared link
**When** they open the web learn page and tick "Dialogs from movie", or try to change a dialogue's text or draw a scene picture any other way
**Then** the web learn page leads to the coming-soon screen, the dialogue text cannot be changed, and no picture is drawn, because only the learner's app may spend money on AI and dialogue text comes only from the import

### AC-23 (US-06) — happy
**Given** a learner has sessions with dialogues and turns the switch off
**When** the learner opens those sessions and runs a new subtitle import
**Then** the existing dialogue pages, groups and scene pictures stay as they are; the new import picks no dialogues and adds no dialogue pages

### AC-24 (US-04) — domain invariant
**Given** a session with dialogue groups, none with a scene picture or a mnemonic story, and a topic group without a story
**When** the learner opens the learn page and selects one dialogue group after another
**Then** no story run starts and nothing is paid for any dialogue group; a scene picture is drawn only on Start of "Dialogs from movie", and a mnemonic story of a dialogue group only on Start of "Mnemonic story"; the topic group and "Other words" still start their mnemonic story on their own, as in mnemonic-story AC-06

### AC-25 (US-04) — domain invariant
**Given** a session with dialogue groups and an "Other words" group of 12 words without a story
**When** the learner adds 15 more words by hand or with an import that brings no dialogues
**Then** "Other words" takes in 7 of them, up to 19, and the other 8 form a topic group of their own (with fewer than 7 left over they would wait, showing "N more words are waiting for a group"), as mnemonic-story's grouping rules say; the group pager is shown even when the session has 19 words to learn or fewer, with the line "Your words are grouped by the dialogues from the film. Please select one group to learn."

### AC-26 (US-04) — cross-context
**Given** a dialogue group whose scene picture has been drawn
**When** every dialogue word of that dialogue is deleted or edited so it no longer appears in the dialogue
**Then** the dialogue's page and its group card disappear, its scene picture stays only in story runs, and a word that is still a word to learn moves to "Other words"; while at least one of its words remains, an edited word stays in the group and the card shows its current form

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Time to results dialog with the switch on | no hard target (owner decision 2026-10-07); measured per model and shown in the results dialog's model, time and cost line | on the phone, same 5 test films as words-from-subtitles, at maximum 20 and 100, once per offered model |
| Extra failed imports caused by dialogues | 0 imports at maximum 20 fail with the switch on where the same film succeeds with it off | device pass: 10 runs (5 films × 2), each with the switch on and off |
| Dialogues per import | ≤ 10 kept, each ≤ 8 lines (extra or longer ones dropped, AC-05) | automated check on every reply before the results dialog opens |
| Bold words really in the dialogue | 100% of bold words appear in their dialogue's text | automated check (AC-05) |
| Time to scene picture | picture prompt writer ≤ 90 s, picture maker ≤ 120 s, as in mnemonic-story | story runs record per step |
| Story allowance shared | scene pictures and mnemonic stories together ≤ 20 story runs per UTC day | the 21st Start or "Draw again" of a UTC day gets the AC-19 message |
| Switch off is unchanged | 0 differences in what the import sends and what it shows, with the switch off | automated comparison against the words-from-subtitles behaviour |

## 6.1 Security / privacy

- **Data classification:** internal on the device; public on the shared page. Film dialogues are short quotes from published films, not personal data. Once on the shared page, anyone holding the link can read them and their scene pictures.
- **Personal data touched:** the switch's value is stored on the device as a preference. Film dialogues and scene pictures are stored with the session. The sessions a learner shares now show which films they watched; this is the learner's choice when sharing.
- **AuthZ/AuthN impact:** dialogues are picked only inside the learner's subtitle import, which already accepts only the learner's app. Scene pictures are drawn only by the learner's app and count against the story allowance. The shared page can only show dialogues and pictures. It cannot change a dialogue's text or draw a picture.
- **Abuse cases:**
  - Instructions hidden in a subtitle line, carried into a dialogue and on to the picture prompt writer (the sharpest new path, since dialogue text now feeds a second AI): dialogue text is passed to the picture prompt writer as scene content only, never as instructions, as the mnemonic-story prompt treats a story.
  - Pictures of real actors or adult scenes: the scene picture shows invented characters, never a real person's likeness; a picture maker refusal is handled by AC-18 and costs one allowance unit per "Draw again".
  - Swearing or crude jokes reaching the partner: dialogues may hold slang and swearing, as words may (words-from-subtitles decision). The learner removes a dialogue only by removing its words (AC-03, AC-11).
  - Film quotes published on a link anyone can open: kept short (≤ 8 lines, ≤ 10 per import). Showing them on the shared page is the owner's decision (§1).
  - Running up AI cost through scene pictures: drawn only on Start in the app, never on opening a page, and capped by the story allowance (AC-19, AC-22).
- **Security review:** Required — dialogue text from the film now reaches a second AI (the picture prompt writer), and film content is published on the shared page.

## 7. Metrics / KPIs

<!-- N/A: owner decision 2026-10-07 — no KPIs are tracked for this feature, as for words-from-subtitles; the §6 targets and a device pass are the check. -->

## 8. Open questions

None — the three questions left by specify were resolved in clarify (2026-10-07, §1 decisions).
