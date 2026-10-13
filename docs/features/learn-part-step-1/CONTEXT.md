---
status: Living
updated_at: "2026-10-07"
---

# Domain Context — learn-part-step-1

> Project-wide terms (learner, partner, session, shared page, word row, translation) live in the
> repo-root [`CONTEXT.md`](../../../CONTEXT.md). "Definition" is used as in
> [`definition-mode/CONTEXT.md`](../definition-mode/CONTEXT.md).

## Glossary

- exercise — one kind of activity for practising a session's words (for example "Mnemonic story" or "Match synonyms"). It is listed on the learn page and is either available or coming soon. NOT a word row (an exercise works on many word rows at once) and NOT a stage.
- learn page — the screen in the app, and the matching page on the web, where the learner or the partner ticks exercises and presses Start. It is opened with the Learn button: from the Words screen in the app, or from the shared page on the web, where it also has its own link. NOT the shared page (the shared page is the word table itself).
- stage — one of the three groups the learn page sorts exercises into, shown on screen as "Step 1", "Step 2" and "Step 3", from recognising words to producing them. NOT a roadmap step (roadmap steps are units of delivery, not groups of exercises).
- available exercise — an exercise that can be ticked and started. In this feature only "Mnemonic story" is available. NOT a finished exercise (Mnemonic story is available, but starting it shows the coming-soon screen until its own feature ships).
- coming soon — the state of an exercise that is listed but cannot be ticked yet; it is greyed out and labelled "Coming soon". Also the name of the screen Start opens while the picked exercise is not built yet. NOT an error (nothing failed; the exercise does not exist yet).
- word to learn — a word row with an English word plus a translation or a definition (the same rule Share uses). On the web, only the session's saved rows count, as they stand when Learn is pressed or the learn page's link is opened. It decides the word count on the learn page and whether the learn page opens at all. NOT a word typed into a shared-page cell that is not saved yet, and NOT a row with only an English word.
- exercise list — the eleven exercises with their id, name, stage and available flag, in plan order: `exercises.json` in the Worker is the source of truth and the app keeps a Dart copy that a test compares with it. NOT the learn page (the page shows the list; the list is data).
- pick — one ticked exercise carried in the web learn page's address (`?pick=<exercise id>`), so the browser's Back button returns with the ticks kept. NOT saved progress (it lives only in the address of one visit).
- mnemonic story — an exercise that turns a session's words into one short connected story, one frame per word, each frame a Ukrainian sentence carrying the English word plus its English sentence. Built by the mnemonic-story feature (its own entry there replaces this one). NOT a definition (a definition explains one word; the story links all words of the session).

## Invariants

- The app's learn page and the web learn page list the same exercises, in the same stages and order, with the same available / coming-soon state.
- A coming-soon exercise can never be ticked or started.
- Start is possible only while at least one exercise is ticked.
- A session with no word to learn offers no way into the learn page.
- The learn page saves no progress and no ticks, on the device or on the web. Ticks last only for one visit of the learn page (including a return from the coming-soon screen) and are cleared when it is opened again from Learn. Since mnemonic-story, the app's learn page (not the web one) does remember two things about the session, kept on the session itself: its word groups and the selected group. The web learn page still saves nothing. (See [`mnemonic-story/CONTEXT.md`](../mnemonic-story/CONTEXT.md).)
