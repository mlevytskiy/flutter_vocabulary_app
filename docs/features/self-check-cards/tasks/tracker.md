# Tracker — self-check-cards

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Record the self-check-cards approvals in CLAUDE.md rule 3](./t1-record-the-self-check-cards-approvals-in-claude-md-rule-3.md) | docs | implementer agent | S | — | done |
| T3 | [Move boxes from ratings in applySession: flagged words wait for their card, unrated flagged words keep their box](./t3-move-boxes-from-ratings-in-applysession-flagged-words-wait-f.md) | domain | implementer agent | M | T1 | done |
| T4 | [Let exercise pages report a hint: right after a hint is its own result, not a clean right](./t4-let-exercise-pages-report-a-hint-right-after-a-hint-is-its-o.md) | domain | implementer agent | M | T1 | done |
| T5 | [Schedule self-check cards in the session queue: 3 pages after a flag, no limit, re-flag gets a new card](./t5-schedule-self-check-cards-in-the-session-queue-3-pages-after.md) | domain | implementer agent | M | T4 | todo |
| T6 | [Show the shared self-check card as an exercise-session page](./t6-show-the-shared-self-check-card-as-an-exercise-session-page.md) | ui | implementer agent | S | T5 | todo |
| T7 | [Show the rating on the session results screen](./t7-show-the-rating-on-the-session-results-screen.md) | ui | implementer agent | S | T3, T6 | todo |
| T8 | [Talk with AI: a self-check step in the quick check for missed and hinted words; talk scoring through the ratings](./t8-talk-with-ai-a-self-check-step-in-the-quick-check-for-missed.md) | ui | implementer agent | M | T3, T6 | todo |
| T9 | [Finish: build_runner, analyze, changed tests, grep check, device check list for the owner](./t9-finish-build-runner-analyze-changed-tests-grep-check-device.md) | docs | implementer agent | S | T7, T8 | todo |

**Total:** 8 tasks, ~6 person-days.
