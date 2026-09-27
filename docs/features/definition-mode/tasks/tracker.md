# Tracker — definition-mode

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Add definition fields and the filled-row helper to WordPair](./t1-word-pair-definition-fields.md) | domain | Maksym | S | — | done |
| T2 | [Add the persisted word detail mode provider](./t2-word-detail-mode-provider.md) | infra | Maksym | S | — | done |
| T3 | [Add the three-way word detail mode to Settings](./t3-settings-word-detail-mode.md) | ui | Maksym | S | T2 | done |
| T4 | [Add the Worker dictionary route with the 30-day cache](./t4-worker-dictionary-route.md) | ports | Maksym | M | — | done |
| T5 | [Accept definitions and the detail mode in published sessions](./t5-worker-session-contract.md) | ports | Maksym | S | — | done |
| T6 | [Render shared-page columns from the detail mode](./t6-shared-page-columns.md) | ui | Maksym | S | T5 | done |
| T7 | [Write the fixed definition column in the Worker AnkiDroid file](./t7-worker-anki-definition-column.md) | ports | Maksym | S | T5 | done |
| T8 | [Add DictionaryService and DefinitionResult in the app](./t8-dictionary-service.md) | app | Maksym | S | — | done |
| T9 | [Store photo descriptions as definitions](./t9-photo-description-to-definition.md) | app | Maksym | S | T1 | done |
| T10 | [Keep per-row definition state in the input screen and notifier](./t10-row-definition-state.md) | app | Maksym | M | T1 | done |
| T11 | [Lay out word rows per word detail mode](./t11-row-layouts-per-mode.md) | ui | Maksym | M | T2, T10 | done |
| T12 | [Fill a definition from the lightning icon](./t12-definition-lightning.md) | ui | Maksym | S | T8, T11 | done |
| T13 | [Pick a sense from the definition dots popup](./t13-definition-senses-popup.md) | ui | Maksym | M | T8, T11 | done |
| T14 | [Show words-table columns per mode with the filled rule](./t14-words-table-columns.md) | ui | Maksym | S | T1, T2 | done |
| T15 | [Write the fixed definition column in the app AnkiDroid export](./t15-app-anki-definition-column.md) | app | Maksym | S | T1, T2, T7 | done |
| T16 | [Publish definitions and the detail mode](./t16-publish-definitions.md) | app | Maksym | S | T1, T2, T5 | todo |
| T17 | [Update architecture docs and the deploy checklist](./t17-docs-and-deploy-checklist.md) | docs | Maksym | S | T4, T5, T6, T7, T16 | todo |

**Total:** 17 tasks, ~10.5 person-days (S ≈ ½ day, M ≈ 1 day).
