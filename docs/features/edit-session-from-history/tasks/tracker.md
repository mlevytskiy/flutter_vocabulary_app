# Tracker — edit-session-from-history

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Store the pick record beside the current-session pointer](./t1-session-store-pick-record.md) | infra | Maksym | S | — | todo |
| T2 | [Add WordInputNotifier.switchTo](./t2-notifier-switch-to.md) | app | Maksym | S | T1 | todo |
| T3 | [Let the launch rule honour a recent pick](./t3-launch-rule-honours-pick.md) | app | Maksym | S | T1 | todo |
| T4 | [Add the red Edit button and question to the History words screen](./t4-edit-button-and-question.md) | ui | Maksym | S | T2 | todo |
| T5 | [Drop late lookup results and hide the restore snackbar after a switch](./t5-drop-late-results.md) | ui | Maksym | M | T2 | todo |
| T6 | [Verify the whole switch on the device and update the docs](./t6-verify-and-docs.md) | docs | Maksym | S | T3, T4, T5 | todo |

**Total:** 6 tasks, ~1.5 person-days.
