---
status: living
updated_at: "2026-10-07"
---

# Testing — tiers, when to run each, and how to write fast tests

Two test suites: the **app** (`flutter test`, files in `test/`) and the **Worker**
(`vocab-photo-api/`, `node --test` against a local `wrangler dev`, files in
`vocab-photo-api/test/`). Both are split into the same tiers. `tool/test.sh` runs a tier for
both at once.

| Tier | Command | Time* | Who runs it, when |
|---|---|---|---|
| **Smoke** | `tool/test.sh smoke` | ~25 s | the agent, after every meaningful change while developing |
| **Feature** | `tool/test.sh changed` (or `tool/test.sh feature FILE...`) | smoke + the files | the agent, before every commit and before saying a task is done |
| **Full regression** | `tool/test.sh full` | ~2.5 min | **only when the owner asks** (and the owner, before a Worker deploy or a store release) |
| **Soak** | `cd vocab-photo-api && npm run test:long` | ~17 min | only when the owner asks; when the page write limit or its pacing changes |

\* Measured 2026-10-07 on a 4-core Linux container: smoke 23 s (app 11 s, Worker 12 s); full
regression 2 min 15 s (app 75 s for 400 tests, Worker 61 s for 102). Before the changes below the
Worker alone took ~3 min there, with 20 of 100 tests failing at random, and an extra minute
whenever a test waited out a time window. The ~20 min the owner saw is most likely the
15-minute soak test plus those subprocesses, which cost more on a slower machine. The soak
test is 15 minutes by design.

## The tiers

### Smoke — "does it still start and talk?"

- **App:** `test/app_smoke_test.dart` starts the real `App()` (router + providers) on a stored
  session and walks Main → words table → back → drawer → History → a past session's table →
  Settings. Plus the core files tagged `@Tags(['smoke'])`: session store, word input notifier,
  the Worker clients (`session_publish_service`, `dictionary_service`) and the Google Translate
  parser.
- **Worker:** `vocab-photo-api/test/smoke.test.mjs`: the secret gate, then one session through
  publish → photo upload → page + script → cell save, row add, row delete → definition
  autofill → change feed → AnkiDroid file → republish, then the app's `/define` and
  `/subtitles/words`, and the gone page.
- Budget: **app smoke ≤ 15 s, Worker smoke ≤ 20 s** (most of that is starting `wrangler dev`).
  Smoke checks that each route and screen is wired and answers. It does not cover edge cases.
- `cd vocab-photo-api && npm test` is the Worker smoke alone. `flutter test --tags smoke` is the
  app smoke alone, but it compiles every test file to find the tags (~25 s, against ~11 s for
  `tool/test.sh`, which runs the tagged files by path).

### Feature — the tests the agent writes for the work in hand

Every feature or fix ships with tests (acceptance criteria → tests, as the task files already
ask). These are the **feature tests**:

1. the test files the work **adds or changes**, and
2. the existing app test files that **import a `lib/` file the work changes**.

`tool/test.sh changed` finds both by comparing the branch with `master` (uncommitted files
included) and runs them with the smoke tier. For Worker changes it cannot see which test files
cover a `src/` file, so when you change Worker code, name the files:
`tool/test.sh feature vocab-photo-api/test/edit.test.mjs test/words_table_test.dart`.

A task file lists its feature test files under its acceptance criteria, so the next session
and the owner know what to run.

Feature tests are not a separate folder. They live in `test/` and `vocab-photo-api/test/`
like every other test, so once the feature is merged they are part of the full regression.

### Full regression — everything, only on request

`tool/test.sh full` = `flutter test` + `npm --prefix vocab-photo-api run test:full`. The agent
does **not** run it on its own. If a change is broad (a migration, a shared service, the
router, `session_store.dart`, the Worker's routing), the agent says that the full regression
is worth running and the owner decides. The Worker deploy steps in `vocab-photo-api/README.md`
run `npm run test:full`, because a deploy is an owner action.

### Soak — real minutes at a real pace

The two paced two-partner sessions in `vocab-photo-api/test/rows.test.mjs` (65 s and 15 min,
AC-35) run only with `VOCAB_API_LONG_TESTS=1` (`npm run test:long`). The full regression skips
them: the page write limit counts writes per address in a wall-clock minute, and "the page write
limit refuses the 301st write" already shows that 300 writes in one minute all land, which covers
the ~220 these send in their busiest minute.

## Rules for writing tests (keep the suites fast)

1. **No real network.** The app stubs HTTP with `MockClient` and overrides providers. The Worker
   uses the local stubs (`test/mw-stub.mjs`, `test/anthropic-stub.mjs`), never the real APIs.
   Live checks are hand-run scripts under `tool/` (e.g. `tool/smoke_google_translate.dart`).
2. **No real waiting.** In app tests, time passes with `tester.pump(duration)` under the fake
   clock. Use `tester.runAsync` only for work that needs the real zone (Isar, files), never for a
   delay. In Worker tests, do not sleep. If a limit counts per time window, give the test its own
   client address (`appHeaders()` / `pagePost()` already do) instead of waiting for a fresh
   window. If waiting cannot be avoided, wait only for the seconds the test needs.
3. **Read and seed the Worker's state with `d1()`** (`test/helpers.mjs`). It opens the local D1
   SQLite file in-process. Never spawn `wrangler d1 execute` per assertion: each call starts a
   new process (~3 s). `kvPut` / `kvDelete` still spawn wrangler, so use them only for old
   KV-only links.
4. **One Isar store per app test file**, opened in `setUpAll` or on first use, kept open. Closing
   an Isar the screen watched under the fake clock never returns. Isar's `watch` and reads do not
   complete under the fake clock either: read in `tester.runAsync`, or override the stream
   provider (see `test/app_smoke_test.dart`).
5. **Budget per file:** a new app test file should run in under ~10 s and a new Worker test
   file in under ~5 s (`npm test -- test/x.test.mjs` prints each test's `duration_ms`). Anything
   that needs real minutes is a soak test: gate it with
   `skip: !process.env.VOCAB_API_LONG_TESTS && "…"` and say why in a comment.
6. **Every test asserts something.** Probes that only print (debugging experiments) are deleted
   before the commit. If something needs to stay as a record, write it up in the task file.
7. **Smoke stays small.** Tag a new app file `@Tags(['smoke'])`, or add a step to
   `vocab-photo-api/test/smoke.test.mjs`, only for a new screen, a new route or a new external
   service. Edge cases go in the feature's own file. If smoke grows past its budget, move steps
   out.

## What made it slow, and what changed (2026-10-07)

- **Worker: a `wrangler` subprocess per database read.** About 90 `d1()` / `storedRows()` calls,
  ~3 s each. Each call also left a pause after which `fetch` sometimes reused a socket the local
  server had dropped, so 20 of 100 tests failed at random with `fetch failed`. `d1()` now opens the
  local D1 SQLite file in-process (WAL mode, the same sharing `wrangler d1 execute --local`
  relies on), and falls back to wrangler if the file is not where miniflare keeps it.
- **Worker: waiting for a fresh window.** The subtitle allowance tests waited up to 61 s to stay
  clear of a 10-minute window's edge, and need ~1 s. They now wait only when under 10 s are left.
- **Worker: paced soak tests in the main run.** The 65-second two-partner session moved to the
  soak tier with the 15-minute one (see above).
- **App:** the suite was already ~1.5 min, so no test was moved or deleted for speed. Four
  `test/tmp_*` probe files that asserted nothing were deleted. If the app suite grows slow, the
  next step is merging small pure-Dart files: each file is compiled separately, ~1–3 s each.
- **First app run offline:** `Isar.initializeIsarCore(download: true)` downloads `libisar` into
  the project root on the first run. Where `binaries.isar-community.dev` is blocked, copy it
  from the pub cache instead:
  `cp ~/.pub-cache/hosted/pub.dev/isar_community_flutter_libs-3.3.0-dev.1/linux/libisar.so .`
  (`macos/libisar.dylib` on a Mac).
