# Tracker — words-from-subtitles

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| [T1](T1-promote-allowance-migration.md) | Promote the subtitle allowance migration into the Worker | migration | Maksym | S | — | done |
| [T2](T2-worker-allowance.md) | Take one subtitle import from the address window and the daily cap, and clean up old windows | infra | Maksym | M | T1 | done |
| [T3](T3-worker-prompt-and-ai-stub.md) | Build the pick-words prompt, the per-model request and the reply check, with a local AI stub for tests | app | Maksym | M | — | done |
| [T4](T4-worker-subtitles-route.md) | Serve POST /subtitles/words per the contract and register it behind the app secret | ports | Maksym | M | T2, T3 | done |
| [T5](T5-subtitle-parser.md) | Strip SRT and VTT files to dialogue lines in pure Dart | domain | Maksym | M | — | done |
| [T6](T6-import-options-and-prefs.md) | Add the import option types, the price table and the import preferences notifier | domain | Maksym | M | — | done |
| [T7](T7-subtitle-words-service.md) | Call POST /subtitles/words from the app and map every answer to its message | infra | Maksym | M | T6 | done |
| [T8](T8-settings-subtitle-controls.md) | Add the subtitle import controls and the model picker to Settings | ui | Maksym | M | T6 | done |
| [T9](T9-result-dialog-subtitle-mode.md) | Rename Description to Definition and add the info line and empty message to the results dialog | ui | Maksym | S | T6 | todo |
| [T10](T10-import-and-loading-dialogs.md) | Add file_selector and build the import dialog and the loading dialog | ui | Maksym | M | T6 | todo |
| [T11](T11-wire-subtitle-import-flow.md) | Wire the From subtitles speed-dial item through parse, request, results and Done | wiring | Maksym | M | T5, T7, T9, T10 | todo |
| [T12](T12-worker-readme-and-deploy.md) | Document the subtitle route, its migration and the AI stub in the Worker README | docs | Maksym | S | T4 | done |
| [T13](T13-device-pass.md) | Run the device pass for the spec §6 targets on 5 films and every model | tests | Maksym | M | T11, T12 | todo |

**Total:** 13 tasks, about 11.5 person-days (S = half a day, M = one day).
