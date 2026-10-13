# Tracker — mnemonic-story

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in-progress` (T20: docs done, release checks pending owner) · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Add the story allowance, story run and step tables to D1](./T1-worker-story-tables.md) | migration | Maksym | S | — | done |
| T2 | [Add the offered AI list with prices and the step pricing rule to the Worker](./T2-worker-offered-ai-list.md) | domain | Maksym | M | — | done |
| T3 | [Add the word check every story must pass to the Worker](./T3-worker-word-check.md) | domain | Maksym | S | — | done |
| T4 | [Add the Anthropic and OpenCode Zen text adapters with a 90 s limit](./T4-worker-text-providers.md) | infra | Maksym | M | T2 | done |
| T5 | [Add the Grok and Higgsfield picture adapters with a 120 s limit](./T5-worker-picture-providers.md) | infra | Maksym | M | T2, T4 | done |
| T6 | [Add the story allowance take and the run store to the Worker](./T6-worker-allowance-and-run-store.md) | infra | Maksym | M | T1 | done |
| T7 | [Serve the offered AI list and the grouping split from the Worker](./T7-worker-models-and-grouping-routes.md) | ports | Maksym | M | T2, T4 | done |
| T8 | [Run each story run as a Workflow on the Worker](./T8-worker-story-run-workflow.md) | app | Maksym | L | T3, T4, T5, T6 | done |
| T9 | [Add the start, status, redo and picture routes and the 7-day picture clean-up](./T9-worker-story-run-routes.md) | ports | Maksym | M | T7, T8 | done |
| T10 | [Add WordPair.rowId, WordGroup and the StoryRun collection to the app](./T10-app-story-models.md) | domain | Maksym | M | — | done |
| T11 | [Add the pure word-grouping rules to the app](./T11-app-word-grouping-rules.md) | domain | Maksym | M | T10 | done |
| T12 | [Add the app's story service for the Worker's story routes](./T12-app-story-api-service.md) | infra | Maksym | M | T10, T7, T9 | done |
| T13 | [Add the story run store and the picture store to the app](./T13-app-story-run-and-picture-stores.md) | infra | Maksym | M | T10 | done |
| T14 | [Add the word-groups notifier that groups a session and keeps its selection](./T14-app-word-groups-notifier.md) | app | Maksym | M | T11, T12 | done |
| T15 | [Add the story run tracker that starts, follows and collects runs](./T15-app-story-run-tracker.md) | app | Maksym | L | T12, T13 | done |
| T16 | [Show the group line, the group pager and grouping messages on the learn page](./T16-app-learn-page-groups.md) | ui | Maksym | M | T14 | done |
| T17 | [Add the story screen and open it from Start for Mnemonic story](./T17-app-story-screen.md) | ui | Maksym | L | T15, T11 | done |
| T18 | [Add the Words settings button and screen with the three AI choices](./T18-app-words-settings.md) | ui | Maksym | M | T12, T13 | done |
| T19 | [Add the story runs list and a run's details screen](./T19-app-story-runs-screens.md) | ui | Maksym | M | T18 | done |
| T20 | [Update the repo docs this design outdates and run the release checks](./T20-docs-and-release-pass.md) | docs | Maksym | M | T9, T16, T17, T19 | in-progress |

**Total:** 20 tasks, ~19 person-days (S ≈ ½ day, M ≈ 1 day, L ≈ a full day at the limit).
