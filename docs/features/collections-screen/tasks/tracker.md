# Tracker — collections-screen

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Record the owner's approvals for collections-screen in CLAUDE.md rules 3 and 5](./T1-docs-claude-md-approvals.md) | docs | Maksym | S | — | done |
| T2 | [Rename Session to WordCollection across the app with every stored name pinned](./T2-domain-rename-session-to-wordcollection.md) | domain | Maksym | L | T1 | done |
| T3 | [Add the pure name rule, the default date name and the creation moment from a collection id](./T3-domain-collection-name-rules.md) | domain | Maksym | S | — | done |
| T4 | [Add the pure filing rules: tree walks, folder into itself, level renumbering, restore target, days left and expiry](./T4-domain-filing-rules.md) | domain | Maksym | M | — | done |
| T5 | [Add the filing fields and CollectionFolder to Isar, and make put() keep filing and never insert](./T5-infra-isar-filing-schema-and-put-contract.md) | infra | Maksym | M | T2, T3 | done |
| T6 | [Backfill names, top-level order and keep for pre-feature collections when the store opens](./T6-infra-filing-backfill.md) | infra | Maksym | M | T3, T5 | todo |
| T7 | [Add CollectionStore.update(id, change) and move every background writer onto it](./T7-infra-atomic-update-for-background-writers.md) | infra | Maksym | M | T5 | todo |
| T8 | [Add rename, new folder, move and reorder transactions and the level, path and History streams](./T8-infra-filing-transactions.md) | infra | Maksym | M | T4, T5 | todo |
| T9 | [Add bin, restore, erase, empty-bin and the 30-day sweep to CollectionStore](./T9-infra-bin-restore-erase-sweep.md) | infra | Maksym | L | T4, T8 | todo |
| T10 | [Run the QG-1 stability suite: 100 interleavings of every background writer with every filing change](./T10-tests-name-and-place-stability-suite.md) | tests | Maksym | M | T7, T9 | todo |
| T11 | [Make launch and resume reopen the current collection, sweep the bin, and drop the RESTORE offer](./T11-app-launch-rule-reopens-current.md) | app | Maksym | M | T9 | todo |
| T12 | [Add open(id) and newCollection(folderId) to the main screen's notifier with the AC-19 leave rule](./T12-app-open-and-new-collection.md) | app | Maksym | M | T8, T11 | todo |
| T13 | [Deliver late translation, photo reading, Quizlet and subtitle results into the collection they started in](./T13-app-late-results-land-in-their-own-collection.md) | app | Maksym | M | T7, T12 | todo |
| T14 | [Show the collection's name as the main screen's title with a white edit button and the shared NameDialog](./T14-ui-name-dialog-and-main-title.md) | ui | Maksym | M | T3, T8 | todo |
| T15 | [Add the Collections route and screen with path, Up and the icon grid, and keep the side menu always on](./T15-ui-collections-screen-browse.md) | ui | Maksym | M | T8 | todo |
| T16 | [Open a collection with a tap, add New folder and New collection, and the item menu with Rename](./T16-ui-collections-actions-menu-new-open.md) | ui | Maksym | M | T12, T14, T15 | todo |
| T17 | [Drag icons into folders, up a level, onto the path and into a new order, with hover-to-open](./T17-ui-collections-drag-and-drop.md) | ui | Maksym | L | T16 | todo |
| T18 | [Delete from the menu or the bin drop zone with the confirmation, the current-collection refusal and the stayed message](./T18-ui-delete-to-bin-flow.md) | ui | Maksym | M | T9, T17 | todo |
| T19 | [Add the recycle bin screen with days left, Restore, Delete forever and Empty recycle bin](./T19-ui-recycle-bin-screen.md) | ui | Maksym | M | T9, T15 | todo |
| T20 | [Show name and word count in History rows, and mark story runs of an erased collection](./T20-ui-history-names-and-story-runs-mark.md) | ui | Maksym | S | T8 | todo |
| T21 | [Promote the staged D1 title migration into the Worker as 0007](./T21-migration-promote-d1-title-migration.md) | migration | Maksym | S | — | done |
| T22 | [Accept, validate and store the optional title on POST /sessions create and republish](./T22-ports-worker-accepts-title.md) | ports | Maksym | S | T21 | done |
| T23 | [Show the stored title as the shared page's heading and document title, escaped, with Vocabulary as the fallback](./T23-ui-shared-page-title.md) | ui | Maksym | S | T22 | done |
| T24 | [Send the name with Share link, warn that it is public, and name shared files after it](./T24-ui-share-with-name.md) | ui | Maksym | M | T5 | todo |
| T25 | [Replace "session" with "collection" in every text the learner reads](./T25-ui-collection-wording-pass.md) | ui | Maksym | S | T2, T20 | todo |
| T26 | [Update architecture.md, CONTEXT.md, the superseded ADRs and the Worker README](./T26-docs-architecture-context-supersedes.md) | docs | Maksym | S | T11, T13, T23 | todo |
| T27 | [Run the device pass: the update over a copy of the owner's data, open time, force-close durability, and deploy the Worker](./T27-tests-device-pass-and-measurements.md) | tests | Maksym | M | T6, T10, T18, T19, T24, T25, T26 | todo |

**Total:** 27 tasks, ~19 person-days (S = 0.5, M = 0.75, L = 1).
