# Tracker — get-words-from-subtitles-improvment

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Add scene-run columns and the published-dialogue tables to D1](./T1-worker-dialogue-tables.md) | migration | Maksym | S | — | done |
| T2 | [Return where each word appears from the word check, and pin the rule with a shared case file](./T2-worker-matching-rule-places.md) | domain | Maksym | S | — | done |
| T3 | [Ask for dialogues in the subtitle prompt and check them in the reply](./T3-worker-subtitle-dialogue-prompt-and-check.md) | domain | Maksym | M | T2 | done |
| T4 | [Accept the dialogues flag on POST /subtitles/words and return the checked dialogues](./T4-worker-subtitle-route-dialogues.md) | ports | Maksym | S | T3 | done |
| T5 | [Run scene pictures as two-step runs of the story run workflow](./T5-worker-scene-runs.md) | app | Maksym | L | T1 | done |
| T6 | [Store dialogues with a published session and carry them in publish and republish](./T6-worker-published-dialogues-store.md) | infra | Maksym | M | T1, T2 | done |
| T7 | [Add the append route and the scene-picture upload route for a published session](./T7-worker-append-and-scene-picture-routes.md) | ports | Maksym | M | T6 | done |
| T8 | [Carry dialogues and scene-picture arrivals in the shared page's change feed](./T8-worker-change-feed-dialogues.md) | ports | Maksym | M | T6, T2 | done |
| T9 | [Render the dialogue pages after the word table on the shared page](./T9-web-dialogue-pages.md) | ui | Maksym | M | T6, T2 | done |
| T10 | [Keep the shared page's dialogue pages in step with the change feed](./T10-web-dialogue-live-updates.md) | ui | Maksym | M | T8, T9 | done |
| T11 | [Add "Dialogs from movie" to the exercise list for the app and the web](./T11-exercise-list-dialogs-from-movie.md) | domain | Maksym | S | — | done |
| T12 | [Add FilmDialogue, Session.dialogues, WordGroup.dialogueId and StoryRun kind to the app](./T12-app-dialogue-models.md) | domain | Maksym | M | — | done |
| T13 | [Port the matching rule to Dart and test it against the Worker's case file](./T13-app-matching-rule.md) | domain | Maksym | S | T2 | done |
| T14 | [Add the Done filter, the edit rule and the card names for dialogues](./T14-app-dialogue-rules.md) | domain | Maksym | M | T12, T13 | done |
| T15 | [Group dialogue words into dialogue groups before the existing grouping rules](./T15-app-dialogue-grouping.md) | domain | Maksym | M | T12 | done |
| T16 | [Add the "Get dialogues from subtitles" switch to Settings](./T16-app-dialogues-setting.md) | ui | Maksym | S | — | done |
| T17 | [Carry dialogues from the subtitle import to Done and save them with the words](./T17-app-import-with-dialogues.md) | app | Maksym | M | T4, T14, T16 | done |
| T18 | [Apply the edit rule to dialogues whenever a word changes or is deleted](./T18-app-dialogues-follow-edits.md) | app | Maksym | S | T14, T17 | done |
| T19 | [Show the main screen as a pager with one read-only dialogue page per dialogue](./T19-app-main-screen-pager.md) | ui | Maksym | M | T17, T13 | done |
| T20 | [Start, follow and collect scene runs in the app, and show them in Story runs](./T20-app-scene-run-tracking.md) | app | Maksym | M | T5, T12 | done |
| T21 | [Offer "Dialogs from movie" on the learn page with dialogue groups](./T21-app-learn-page-dialogue-groups.md) | ui | Maksym | M | T11, T15 | done |
| T22 | [Add the dialogue screen with its scene picture and open it from Start](./T22-app-dialogue-screen.md) | ui | Maksym | M | T20, T21, T13 | done |
| T23 | [Send the session's dialogues and scene-picture declarations when publishing](./T23-app-publish-dialogues.md) | infra | Maksym | S | T6, T12 | done |
| T24 | [Append an import's rows and dialogues, and upload scene pictures, to the shared link automatically](./T24-app-dialogue-push-outbox.md) | app | Maksym | L | T7, T17, T20, T23 | todo |
| T25 | [Update the repo docs this design outdates and run the release checks](./T25-docs-and-release-pass.md) | docs | Maksym | M | T10, T19, T22, T24 | todo |

**Total:** 25 tasks, ~21 person-days (S ≈ ½ day, M ≈ 1 day, L ≈ a full day at the limit).
