# Tracker — good-looking-web

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| [T1](t1-spike-browser-translation.md) | Spike: get a translation from the free endpoint in the partner's browser | tests | Maksym | S | — | done |
| [T2](t2-worker-test-harness.md) | Add a node:test harness that runs against wrangler dev | tests | Maksym | S | — | done |
| [T3](t3-d1-schema.md) | Create the D1 schema for sessions, rows, cell revisions, photo slots and counters | migration | Maksym | M | — | done |
| [T4](t4-d1-store-and-legacy-import.md) | Move session storage to D1, with a lazy import of pre-feature KV links | infra | Maksym | M | T2, T3 | done |
| [T5](t5-publish-contract-photos-and-republish.md) | Accept declared photos, row photo ids and republish tokens in the publish contract | ports | Maksym | M | T4 | done |
| [T6](t6-save-cell-with-revision-check.md) | Save cells with a per-cell revision check and limits | ports | Maksym | M | T4 | done |
| [T7](t7-add-delete-rows-and-write-limit.md) | Add and delete rows, and rate-limit page writes | ports | Maksym | M | T6 | done |
| [T8](t8-change-feed.md) | Serve the change feed since a revision | ports | Maksym | S | T7 | done |
| [T9](t9-metered-definition-autofill.md) | Meter definition autofill with the page allowance and the all-pages share | ports | Maksym | M | T6 | done |
| [T10](t10-download-and-daily-cleanup.md) | Build the AnkiDroid file from D1 and clean up expired sessions daily | infra | Maksym | S | T4 | done |
| [T11](t11-server-rendered-two-layout-page.md) | Render the two-layout table, photo markup and CSP on the server | ui | Maksym | L | T4 | done |
| [T12](t12-client-cell-editing-and-conflicts.md) | Edit cells in place with save-on-leave, saved/not-saved states and conflict choice | ui | Maksym | L | T6, T11 | done |
| [T13](t13-client-add-and-delete-with-undo.md) | Add rows with the plus button and delete rows with a 5-second Undo | ui | Maksym | M | T7, T12 | done |
| [T14](t14-client-polling-with-idle-stop.md) | Poll for other partners' changes, pausing when hidden and stopping after 5 idle minutes | ui | Maksym | M | T8, T13 | todo |
| [T15](t15-client-autofill.md) | Autofill a cell or a whole column, and open a collapsed column | ui | Maksym | L | T1, T9, T13 | todo |
| [T16](t16-client-photo-pager-and-dialog.md) | Show the photo pager with row highlighting and the phone photo dialog | ui | Maksym | M | T5, T13 | todo |
| [T17](t17-app-keep-source-photos.md) | Keep each source photo in the app and link recognised rows to it | domain | Maksym | M | — | todo |
| [T18](t18-app-publish-photos-and-background-upload.md) | Publish rows with photo links and upload declared photos in the background | app | Maksym | M | T5, T17 | todo |
| [T19](t19-app-share-sheet-include-photos.md) | Add the include-photos switch and the republish warning to the share sheet | ui | Maksym | S | T18 | todo |
| [T20](t20-nfr-verification.md) | Run the concurrency, limits and performance checks from sad §10 | tests | Maksym | M | T10, T14, T15, T16 | todo |
| [T21](t21-docs-and-deploy-checklist.md) | Update the docs and run the deploy checklist | docs | Maksym | S | T10, T19, T20 | todo |

**Total:** 21 tasks, ~18 person-days (S = half a day, M/L = one day; L tasks are the fullest days and the first to split if they overrun).
