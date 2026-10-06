# Tracker — learn-part-step-1

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Add the exercise list and the word-to-learn rule to the Worker](./T1-worker-exercise-list.md) | domain | Maksym | S | — | done |
| T2 | [Add the Exercise type and its const list to the app, pinned to the Worker's JSON](./T2-app-exercise-list-parity.md) | domain | Maksym | S | T1 | done |
| T3 | [Serve the web learn page, the no-words page and the coming-soon page from the Worker](./T3-worker-learn-routes.md) | ports | Maksym | M | T1 | done |
| T4 | [Add learn.js: Start, the hint, the pick in the address and Back to exercises](./T4-worker-learn-script.md) | ui | Maksym | M | T3 | done |
| T5 | [Add Learn to the shared page with a fresh check before opening](./T5-shared-page-learn-button.md) | ui | Maksym | M | T3 | todo |
| T6 | [Add the app's learn page and LearnRoute](./T6-app-learn-screen.md) | ui | Maksym | M | T2 | todo |
| T7 | [Add the app's coming-soon screen and make Start open it](./T7-app-coming-soon-screen.md) | ui | Maksym | S | T6 | todo |
| T8 | [Add LearnShareBar that fits Learn and Share by measuring the space](./T8-learn-share-bar.md) | ui | Maksym | M | — | todo |
| T9 | [Put Learn on the Words screen: SnackBar when empty, otherwise open the learn page](./T9-wire-learn-on-words-screen.md) | wiring | Maksym | S | T6, T8 | todo |
| T10 | [Update the repo docs this design outdates](./T10-docs-and-glossary.md) | docs | Maksym | S | T4, T5, T7, T9 | todo |
| T11 | [Deploy the Worker and run the release checks on device and in the browser](./T11-release-pass.md) | tests | Maksym | S | T10 | todo |

**Total:** 11 tasks, ~8 person-days (S ≈ ½ day, M ≈ 1 day).
