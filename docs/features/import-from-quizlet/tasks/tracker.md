# Tracker — import-from-quizlet

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| [T1](T1-promote-set-sources-migration.md) | Promote the set-sources migration into the Worker | migration | Maksym | S | — | done |
| [T2](T2-worker-accept-set-sources.md) | Accept, store and load set sources in the Worker publish path | ports | Maksym | M | T1 | done |
| [T3](T3-shared-page-set-source-page.md) | Show a set source as a page of the source pager and the phone sources dialog | ui | Maksym | M | T2 | done |
| [T4](T4-generalise-source-photo-to-session-source.md) | Generalise SourcePhoto into SessionSource with a kind, name and link | domain | Maksym | M | — | done |
| [T5](T5-remove-screenshot.md) | Remove the Screenshot item, its capture code and the screenshot package | wiring | Maksym | S | — | done |
| [T6](T6-quizlet-link-rules.md) | Find a Quizlet set link in pasted text and decide which navigations the web view may follow | domain | Maksym | S | — | done |
| [T7](T7-quizlet-page-reader-and-parser.md) | Write the reader script and parse raw set-page material into a set | domain | Maksym | M | T6 | done |
| [T8](T8-cards-to-proposed-words.md) | Turn cards into proposed words with the text rules, repeats and counts | domain | Maksym | S | — | done |
| [T9](T9-quizlet-link-dialog.md) | Build the Quizlet link dialog that refuses text without a set link | ui | Maksym | S | T6 | done |
| [T10](T10-quizlet-progress-dialog.md) | Build the progress dialog that loads and reads the set in a web view | ui | Maksym | L | T6, T7 | done |
| [T11](T11-results-dialog-set-mode.md) | Show the set name, "Read X of Y", skipped cards and "No new words" in the results dialog | ui | Maksym | S | — | done |
| [T12](T12-quizlet-import-flow.md) | Run a Quizlet import from link to kept words, with translation and the late-result rule | app | Maksym | M | T8, T9, T10, T11 | todo |
| [T13](T13-wire-import-from-quizlet.md) | Add "Import from Quizlet" to the red + menu and keep the set as the words' source | wiring | Maksym | S | T4, T5, T12 | todo |
| [T14](T14-include-sources-switch-and-publish.md) | Publish photos and sets behind one "Include sources (N)" switch | app | Maksym | M | T4, T2 | todo |
| [T15](T15-imported-words-are-ordinary.md) | Prove words from a set behave like typed words in the table, History and export | tests | Maksym | S | T13 | todo |
| [T16](T16-docs-and-worker-deploy.md) | Update the architecture docs and deploy the Worker with the migration | docs | Maksym | S | T3, T14, T15 | todo |
| [T17](T17-device-pass.md) | Run the device pass for the spec §6 targets on real Quizlet sets | tests | Maksym | M | T16 | todo |

**Total:** 17 tasks, ~12.5 person-days (S ≈ ½ day, M and L ≈ 1 day each).
