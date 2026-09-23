# Tasks

One file per step of [`../roadmap.md`](../roadmap.md). Each file holds a **prompt** (paste it at an
agent, or read it yourself) and **acceptance criteria** that say how to check the result. Subtasks
live inside the file they belong to — there is no separate file per subtask.

Task files link to the roadmap and [`../idea-brief.md`](../idea-brief.md); they do not restate them.

## Index

| Task | Step | Size | Wave | Blocked on | Status |
|---|---|:---:|:---:|:---:|---|
| [task-00](completed/task-00-restructure.md) — Restructure: feature folders, go_router, Riverpod, persistence | — | M (5 steps) | 0 | task-01 | done (`9a0deb4`, `5e18846`, `9da9291`) |
| [task-01](completed/task-01-remove-reverso.md) — Reverso is gone from the app and the Worker | 1 | S | 1 | — | code complete (`8a6356f`, `b6e7b16`); AC-7..11 need a running Worker + device pass |
| [task-02](completed/task-02-word-limit-is-a-cap.md) — The word limit is a cap, not a quota | 2 | S | 2 | — (D2 resolved: reading order) | code complete; AC-1/7 + typecheck verified, AC-3/4/5/6/8 need a deployed Worker + device pass |
| [task-03](completed/task-03-words-survive-restart.md) — Sessions: collected words survive an app restart (v2, `isar_community`) | 3 | M | 2 | — (D8 resolved: `isar_community`) | v1 done (`5e18846`); **v2 code complete 2026-09-20** — AC-1..AC-6 green, AC-7..AC-14 need a device pass |
| [task-04](completed/task-04-uk-us-pronunciation.md) — Hear a word in UK and US pronunciation | 4 | S | 3 | — (D1 resolved: on-device TTS) | done; AC-1..4 verified on device, AC-5..10 not explicitly checked |
| [task-05](completed/task-05-publish-session-link.md) — Publish a session to a durable shared link | 5 | M | 3 | — (D4 resolved: 30d TTL; D5 resolved: one photo, list-shaped) | **code complete 2026-09-21** — AC-1..12 verified on `wrangler dev`; AC-13..17 need bindings created + deploy + device pass. Photo upload is Worker-only (app keeps no photo) |
| [task-06](outdated/task-06-partner-corrects-table.md) — The partner corrects the word table | 6 | M | 4 | — (D6 resolved: no names) | not started |
| [task-07](outdated/task-07-download-from-shared-page.md) — Download the AnkiDroid file from the shared page | 7 | S | 5 | — | not started |
| [task-08](outdated/task-08-review-and-mark-memorized.md) — Review words and mark one memorized | 8 | S | 3 | — | not started |
| [task-09](outdated/task-09-word-detail-recon.md) — Extra word detail (recon, not build) | 9 | fog | — | **D3** | not started |
| [task-10](completed/task-10-side-menu-and-history.md) — Side menu and History: reach older sessions | 3 (second half) | S | 3 | task-03 v2 | **code complete 2026-09-22** — AC-1 green; AC-2..AC-8 need a device pass |
| [task-11](active/task-11-dots-popup-loads-translations.md) — The dots popup shows the translations it has, and can fetch them | 11 | S | 6 | — | **code complete 2026-09-23** — AC-1 green; AC-2..AC-10 need a device pass |
| [task-12](active/task-12-hide-keyboard-on-dots-tap.md) — Tapping the dots closes the keyboard | 12 | S | 6 | task-11 (same screen file) | not started |
| [task-13](active/task-13-settings-screen-and-fab.md) — A Settings screen; drag-and-drop moves out of the top bar | 13 | M | 6 | **D9** (entry point); task-11/12 (same screen file) | not started |

D1, D2, D4, D5, D6, D8 are resolved in [`../roadmap.md#decisions-so-far`](../roadmap.md#decisions-so-far);
**D3** (task-09, a recon task that answers its own blocker) and **D9** (task-13, where the settings
entry point lives — the task proceeds on recommendation (c), a bottom-left FAB) are still open.

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
wave 2:  02  ∥  03     (03 v1 is task-00 step 3, done; 03 v2 = Session + isar_community, planned)
wave 3:  04  ∥  05  ∥  08  ∥  10   (10 needs 03 v2)
wave 4:  06
wave 5:  07
wave 6:  11  →  12  →  13   (all three reach into word_input_screen.dart, so they serialize)
```

After task-00 the word list lives in `lib/features/word_input/word_input_notifier.dart` and the
screen is split into widget files under `lib/features/word_input/widgets/`, so the file-conflict
serialization below mostly disappears. Every task from wave 2 on is executed against the new
structure — read `CLAUDE.md` and `../architecture.md` first, and treat the `lib/screens/...` paths
in the older task prompts as pointers to *behaviour*, not to locations.

Only six of those orderings are real dependencies (roadmap → Dependency graph): 1→9, 3→8, 3→10,
5→6, 5→7, 11→13. Wave 6 (tasks 11/12/13) is serialized by **file conflict** — all three reach into
`lib/features/word_input/word_input_screen.dart` — not by dependency; 12 and 13 order after 11 only
because 11 is the task that owns the row's popup behaviour. Everything else is serialized by
**file conflict** too, mostly because
`lib/screens/word_input_screen.dart` is 1282 lines and nearly every step reaches into it.

## How to check a task

This repo has two verification surfaces, and they are not symmetrical:

| | Command | Notes |
|---|---|---|
| Flutter app | `flutter analyze` · `flutter test` | `test/session_store_test.dart` + `test/word_input_launch_rule_test.dart` (task-03 v2; they replaced `test/word_store_test.dart`; `test/session_publish_service_test.dart` from task-05 is plain `MockClient`, no Isar) each call `Isar.initializeIsarCore(download: true)` in `setUpAll` — **the first run needs network**, it fetches the native Isar library (`libisar.dylib` / `libisar.so` / `isar.dll`) into the **project root** — gitignored — and every run after that is offline. `TestWidgetsFlutterBinding` forces every HTTP request to 400, so both files lift `HttpOverrides.global` for the duration of that one download and put it straight back |

`flutter analyze` currently ends on 3 pre-existing `prefer_const_constructors` **infos** in
`lib/features/word_input/widgets/word_row_item.dart` (they arrived with task-04 and are unrelated
to task-03), so it exits 1. Treat "clean" as "no new issues" until someone clears those three.
| Worker | `cd vocab-photo-api && npm run typecheck` | **no test runner is installed**; behaviour is checked with `curl` + `npx wrangler tail` |

So an acceptance criterion here is one of: a command that exits clean, a `curl` whose response body
is quoted, or an observation on a real device. Where a task says "on device", it means a real phone
— several of these behaviours (camera, share sheet, TTS) cannot be checked in a simulator.

## Before starting anything

Resolved — see *Starting-state decision* above: the staged Reverso additions are unstaged, not
committed-then-removed. task-01 starts from a clean tree.

## Resolved gap — the dots popup used to be a hardcoded stub

Confirmed on device during task-00 step 1 (2026-09-15): the translation "dots" popup
(`TranslationDotsButton` in `lib/features/word_input/widgets/translation_dots_button.dart` as of
task-00 step 4; it was `_buildTranslationDotsButton` in `word_input_screen.dart` before that move)
was a **hardcoded stub** on `master` — three fixed placeholder strings, not real translations.
There was no `google_translate_service.dart`, no `googleInfo`, no `_buildGoogleSection` in this
branch. See
[task-01's note](completed/task-01-remove-reverso.md#note--the-google-section-popup-this-task-describes-isnt-on-master)
for the full detail.

**This is closed.** The popup is now a real body:
`lib/core/services/google_translate_service.dart` + `translate_response_parser.dart` ask Google's
`translate_a/single` for the dictionary block in the same request that fills the Translation field,
and `lib/features/word_input/widgets/translation_options_content.dart` renders the chips — see
`../../docs/lightning_icon_rules.md` (the `2026-09-18` changelog entry). The parallel
`translation_repository` / `translate_api` work on branch `chore/architecture-migration` was
therefore never brought over, and does not need to be.

What is **still** open in that area is narrower and is
[task-11](active/task-11-dots-popup-loads-translations.md)'s: the popup can still be opened on a
state where the dots are solid but the cached block is gone (a Word-field edit, or the smart-swap
path), and it answers that with a `Tap the lightning icon…` message instead of chips or a fetch.
