# Tasks

One file per step of [`../roadmap.md`](../roadmap.md). Each file holds a **prompt** (paste it at an
agent, or read it yourself) and **acceptance criteria** that say how to check the result. Subtasks
live inside the file they belong to — there is no separate file per subtask.

Task files link to the roadmap and [`../idea-brief.md`](../idea-brief.md); they do not restate them.

## Index

| Task | Step | Size | Wave | Blocked on | Status |
|---|---|:---:|:---:|:---:|---|
| [task-00](./task-00-restructure.md) — Restructure: feature folders, go_router, Riverpod, persistence | — | M (5 steps) | 0 | task-01 | done (`9a0deb4`, `5e18846`, `9da9291`) |
| [task-01](./task-01-remove-reverso.md) — Reverso is gone from the app and the Worker | 1 | S | 1 | — | code complete (`8a6356f`, `b6e7b16`); AC-7..11 need a running Worker + device pass |
| [task-02](./task-02-word-limit-is-a-cap.md) — The word limit is a cap, not a quota | 2 | S | 2 | — (D2 resolved: reading order) | code complete; AC-1/7 + typecheck verified, AC-3/4/5/6/8 need a deployed Worker + device pass |
| [task-03](./task-03-words-survive-restart.md) — Collected words survive an app restart | 3 | M | 2 | — | covered by task-00 step 3 (`5e18846`); AC-1..8 verified, AC-9..11 open |
| [task-04](./task-04-uk-us-pronunciation.md) — Hear a word in UK and US pronunciation | 4 | S | 3 | — (D1 resolved: on-device TTS) | not started |
| [task-05](./task-05-publish-session-link.md) — Publish a session to a durable shared link | 5 | M | 3 | — (D4 resolved: 30d TTL; D5 resolved: one photo, list-shaped) | not started |
| [task-06](./task-06-partner-corrects-table.md) — The partner corrects the word table | 6 | M | 4 | — (D6 resolved: no names) | not started |
| [task-07](./task-07-download-from-shared-page.md) — Download the AnkiDroid file from the shared page | 7 | S | 5 | — | not started |
| [task-08](./task-08-review-and-mark-memorized.md) — Review words and mark one memorized | 8 | S | 3 | — | not started |
| [task-09](./task-09-word-detail-recon.md) — Extra word detail (recon, not build) | 9 | fog | — | **D3** | not started |

D1, D2, D4, D5, D6 are resolved in [`../roadmap.md#decisions-so-far`](../roadmap.md#decisions-so-far);
only **D3** (task-09, a recon task that answers its own blocker) is still open.

## Starting-state decision (task-01)

Chosen: **(b) unstage** — the staged Reverso additions
(`lib/services/reverso_service.dart`, `lib/models/reverso_info.dart`,
`lib/widgets/reverso_info_popup.dart`, `vocab-photo-api/src/reverso.ts`) are dropped from the index
and never committed. The 403-from-Cloudflare investigation lives in
[`vocab-photo-api/README.md`](../../vocab-photo-api/README.md) only.

## Order

Waves come from the roadmap's execution path. Within a wave the tasks touch disjoint files, so they
can run in parallel (separate worktrees, separate sessions).

```
wave 1:  01
wave 0:  00   (the restructure — runs right after 01, one step per session)
wave 2:  02  ∥  03     (03 is task-00 step 3, done; only AC-9..11 remain open)
wave 3:  04  ∥  05  ∥  08
wave 4:  06
wave 5:  07
```

After task-00 the word list lives in `lib/features/word_input/word_input_notifier.dart` and the
screen is split into widget files under `lib/features/word_input/widgets/`, so the file-conflict
serialization below mostly disappears. Every task from wave 2 on is executed against the new
structure — read `CLAUDE.md` and `../architecture.md` first, and treat the `lib/screens/...` paths
in the older task prompts as pointers to *behaviour*, not to locations.

Only four of those orderings are real dependencies (roadmap → Dependency graph): 1→9, 3→8, 5→6,
5→7. Everything else is serialized by **file conflict**, mostly because
`lib/screens/word_input_screen.dart` is 1282 lines and nearly every step reaches into it.

## How to check a task

This repo has two verification surfaces, and they are not symmetrical:

| | Command | Notes |
|---|---|---|
| Flutter app | `flutter analyze` · `flutter test` | `test/word_store_test.dart` (added in task-00 step 3) is CI-safe, no network — 4 tests, all local `SharedPreferences` mocks |
| Worker | `cd vocab-photo-api && npm run typecheck` | **no test runner is installed**; behaviour is checked with `curl` + `npx wrangler tail` |

So an acceptance criterion here is one of: a command that exits clean, a `curl` whose response body
is quoted, or an observation on a real device. Where a task says "on device", it means a real phone
— several of these behaviours (camera, share sheet, TTS) cannot be checked in a simulator.

## Before starting anything

Resolved — see *Starting-state decision* above: the staged Reverso additions are unstaged, not
committed-then-removed. task-01 starts from a clean tree.

## Known gap — the dots popup has no real Google Translate results on `master`

Confirmed on device during task-00 step 1 (2026-09-15): the translation "dots" popup
(`TranslationDotsButton` in `lib/features/word_input/widgets/translation_dots_button.dart` as of
task-00 step 4; it was `_buildTranslationDotsButton` in `word_input_screen.dart` before that move)
is a **hardcoded stub** on `master` — three fixed placeholder strings, not real translations. There
is no `google_translate_service.dart`, no `googleInfo`, no `_buildGoogleSection` in this branch. See
[task-01's note](./task-01-remove-reverso.md#note--the-google-section-popup-this-task-describes-isnt-on-master)
for the full detail.

The real thing — `translation_repository` / `remote_translation_repository` / `translate_api` and
the popup content itself (`translation_options_content.dart` / `translation_options_menu.dart`
under `packages/feature_word_list/`) — already exists on branch `chore/architecture-migration` and
should be brought over (or reimplemented against the simplified architecture) as its own task; it
is not covered by task-00 or task-01.
