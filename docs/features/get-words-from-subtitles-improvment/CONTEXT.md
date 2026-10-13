---
status: Living
updated_at: "2026-10-07"
---

# Domain Context — get-words-from-subtitles-improvment

> Project-wide terms (learner, partner, session, current session, shared page, word row, translation) live in the
> repo-root [`CONTEXT.md`](../../../CONTEXT.md). Subtitle terms (subtitle file, subtitle import, import purpose,
> English level, word maximum, import dialog, results dialog) live in
> [`words-from-subtitles/CONTEXT.md`](../words-from-subtitles/CONTEXT.md). Learn-page terms (learn page, exercise,
> stage, word to learn, coming soon) live in [`learn-part-step-1/CONTEXT.md`](../learn-part-step-1/CONTEXT.md);
> story terms (word group, mnemonic story, story run, picture prompt writer, picture maker, AI choice, story
> allowance, outdated story) live in [`mnemonic-story/CONTEXT.md`](../mnemonic-story/CONTEXT.md).

## Glossary

- film dialogue — a short exchange from the subtitle file (a joke or another memorable moment), up to 8 lines, picked by the AI during a subtitle import together with the proposed words it contains. The AI may lightly edit it (for example, shorten it or add speaker marks such as "A:"), but it is taken from this file. NOT a context sentence (that is the one spoken line on a word row) and NOT a mnemonic story (a story is written by the AI; a dialogue comes from the film).
- dialogue words — the word rows linked to one film dialogue at Done: words the import proposed, the learner kept, and that appear in the dialogue's text (whole word, any letter case, phrase words next to each other, endings -s/-es/-ed/-ing allowed, as in mnemonic-story). Each is bold wherever it appears and listed under the dialogue with its translation and definition. The link is fixed at Done and only shrinks: a row deleted, or edited so it no longer appears, leaves; a row added later never joins. NOT every hard word in the dialogue, and NOT the same as words to learn (a dialogue word with no translation and no definition is shown but in no group).
- dialogue page — one page of the main screen's pager after the first: one film dialogue with its dialogue words in bold, the list of those words (word, translation, definition), and its scene picture once drawn. The shared page shows the same pages: a publish carries them, and an import's dialogues and later scene pictures reach an existing link on their own (ADR-0005). NOT the words table (that is the pager's first page, unchanged).
- dialogue group — a word group made from one film dialogue: its dialogue words that are in no other word group yet (not an earlier dialogue's, not an existing topic group). A dialogue left with no such words has a dialogue page but no group. It may have any number of words; the 7-to-19 size of mnemonic-story does not apply to it. NOT a topic group (a word group put together by the grouping AI by topic or meaning).
- other words — the session's words to learn that are in no word group at all (no dialogue group and no existing topic group). When there are 19 of them or fewer they form one word group named "Other words"; when there are more, they are grouped by topic as in mnemonic-story (7 to 19 each). Afterwards "Other words" is an ordinary word group under mnemonic-story's rules (it takes in new words up to 19 while it has no story; the rest are grouped by topic or wait). NOT words removed in the results dialog (those never enter the session).
- scene picture — one picture drawn from a film dialogue by the picture prompt writer and the picture maker, showing the scene with invented characters (never a real actor's face) and the dialogue's lines in speech bubbles, exactly as written. It is drawn only when the learner presses Start on the "Dialogs from movie" exercise; each drawing is a story run of two steps (no story step) that takes one from the story allowance when its picture prompt step starts. NOT a mnemonic story's picture (that one is drawn from a story the AI wrote).
- scene run — a story run of kind `scene` that draws one scene picture: picture prompt writer, then picture maker, with no story step. It takes one from the story allowance when it starts, and one per "Draw again"; "Try again" of its picture prompt takes none. Listed in story runs beside mnemonic stories, with the dialogue in place of a story. NOT a mnemonic story run (three steps, starting with the story writer).
- import id — the id the app makes for one subtitle import with dialogues into a session that has a shared link. The append to the link carries it, so a repeated delivery adds nothing twice. NOT the session id, and NOT a dialogue id.
- pending delivery — a dialogue or scene picture of a shared session that the Worker has not received yet. It is marked on the film dialogue and retried with growing pauses while the app runs and on every app start. A pending dialogue whose words are all removed stays hidden (no page, no group, not published) until its import is delivered, then is removed. NOT a failed import (that adds nothing to the session at all).
- dialogues setting — the switch "Get dialogues from subtitles" in the main screen's Settings, off by default. It decides only whether a new subtitle import also picks film dialogues; turning it off later keeps the dialogues already in sessions. NOT the "remember my last choices" switch.

## Invariants

- A film dialogue never adds a word: its dialogue words are always among the words the import proposed, and the word maximum still caps the words, never the dialogues.
- A subtitle import picks at most 10 film dialogues; 7 to 10 is a goal, not a quota. Every kept film dialogue has at least one dialogue word.
- Every dialogue word appears in its dialogue's text and is shown there in bold.
- A word may be a dialogue word of several film dialogues, but it belongs to one word group only: the group of the first of those dialogues in pager order.
- A film dialogue whose dialogue words are all removed (in the results dialog or later) is not kept and has no page or group.
- Nothing reachable from a shared link draws a scene picture or spends money on AI.
- No story run starts on its own for a dialogue group; scene pictures and its mnemonic story start only on Start.
- Word groups a session already has keep their words when dialogues arrive; dialogues only group words that are in no group yet.
