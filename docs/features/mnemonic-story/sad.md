---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)", "Security Lead"]
updated_at: "2026-10-07"
feature_size: "M"
target_surfaces: [mobile-app, backend-service]  # decided in §4 (ADR-0001) — subset of: backend-service | web-frontend | mobile-app | desktop-app | cli | worker | library-sdk. Read (never re-derived) by api/sequences/tasks/plan-tests/review → _shared/surfaces.md
---

# Software Architecture Document — mnemonic-story

## 1. Introduction and goals

**Intent.** Ship the first real exercise behind the learn page's Start: a **mnemonic story** with one picture, written by AI from one **word group** of the session's words to learn (spec §1, §2). A session with more than 19 words to learn is first split by a fixed AI on the Worker into topical groups of 7 to 19 words. The learner selects one group on a pager at the top of the learn page. Each group gets one story made by three AIs in turn, the **story writer**, the **picture prompt writer** and the **picture maker**, chosen by the learner on a new Words settings screen. The story is kept on the phone and made again only when the learner asks. Every **story run** is kept as a record with each AI's result, price and time, so the owner can pick the best AIs for the money. Everything happens in the app. The web learn page does not change, and a daily **story allowance** caps what the whole app can spend.

**Top-3 quality goals (1-liners; full scenarios in §10):**

1. **Spending is bounded and never doubled.** ≤ 20 story runs start per UTC day across the whole app. A finished step is never paid again, even when the app is closed mid-run, and nothing reachable from a shared link can start a run (spec §6 "Story allowance", AC-10, AC-18, AC-19).
2. **A story run finishes on its own.** ≤ 3 min from start to the picture shown with the default AI choice, and the run carries on while the learner is away (spec §6 "Story run time", AC-10).
3. **A saved story opens at once.** ≤ 500 ms from Start to the picture and text shown, from the phone's own storage, with no network (spec §6 "Saved story open time", AC-07).

**Stakeholders.**

| Role | Interest | Sign-off owner? |
|---|---|---|
| learner | Selects a word group, reads its mnemonic story, chooses the AI choice, compares story runs, makes a story again | No |
| partner | Unchanged: the web learn page still leads to coming soon, and nothing on the web can start a run (AC-18) | No |
| Tech Lead (Maksym) | SAD approval | Yes |
| Security Lead | Required by spec §6.1: a new paid server capability reached with a secret that ships in the app | Yes |

**Decision overrides.**
- Decision override: story run results are held on the Worker for up to 7 days — rationale: spec §6.1 says stories, pictures and run records stay on the learner's device. To meet AC-10 (a step in progress when the app closes is collected later, not paid again), the Worker must hold each step's result until the app collects it. The device keeps the only lasting copy. The Worker's copy is deleted by the daily clean-up after 7 days ([ADR-0002](adr/0002-run-each-story-run-as-a-cloudflare-workflow.md), §11). Owner, 2026-10-07.

## 2. Constraints

**Technical.**
- App: Flutter 3.35.1, Dart SDK `>=3.0.0 <4.0.0`, phone only. Typed routes in `lib/router/routes.dart` (`go_router` 17 + `go_router_builder`). Under `/` the tree is `table` → `learn` → `soon`, plus `history` and `settings`. State uses `flutter_riverpod` / `riverpod_annotation` 2.6.x.
- App storage: `isar_community` pinned to `3.3.0-dev.1` (architecture.md §2 rule 6). One collection today, `Session`, opened in `lib/core/services/session_store.dart` (`Isar.open([SessionSchema], …, name: 'vocab')`). `WordPair` and `SessionSource` are `@embedded`. `WordPair` has no stable id. Preferences use `shared_preferences`, and files live under the documents directory from `path_provider` (as in `source_photo_store.dart`).
- App packages already present that this feature reuses: `http` (Worker calls with the `x-app-secret` header, as `vocab_photo_service.dart` does), `flutter_image_compress` (picture size), `shared_preferences` and `path_provider`. `InteractiveViewer` (Flutter SDK) is already used for zoom in `lib/features/words_table/photo_viewer.dart`. The project has no background-execution package, so the app does nothing while it is closed.
- Worker (`vocab-photo-api/`): TypeScript 5.6, `wrangler` 4, `@cloudflare/workers-types`, no runtime npm dependencies, `compatibility_date` `2025-01-01`. Routes are a table of `RouteDefinition`s, each declaring `public` (`src/routing.ts`, `src/index.ts`). Every non-public route needs `x-app-secret` = `APP_SHARED_SECRET` and passes `RATE_LIMITER`: 20 requests per 60 s per `cf-connecting-ip`.
- Worker storage: D1 `DB` (`vocab-sessions`, migrations `migrations/000N_*.sql` with hand-applied `migrations/down/`), KV `SESSIONS` and `DEFINITIONS`, and R2 `SOURCES` (optional binding: when it is absent, the photo routes answer 503). One cron, `0 3 * * *`, runs the daily clean-up.
- Worker AI today: Anthropic only (`ANTHROPIC_API_KEY`), with an allow-listed model set in `src/subtitles/prompt.ts`. Subtitle imports cap the AI call at 225 s and let tests point `ANTHROPIC_API_URL` at a local stub.
- The daily allowance pattern exists: `src/subtitles/allowance.ts` `takeSubtitleImport` takes one unit from `all_subtitle_imports(utc_day, used)` (≤ 20 per UTC day) in one D1 batch before the AI call. A unit is not given back when the call fails.
- Verification: `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`, the CLAUDE.md greps. In `vocab-photo-api/`: `npm test` (`scripts/test.mjs` runs `wrangler dev` with a SQLite D1 stand-in and stub providers) and `npm run typecheck`.

**Organisational.**
- One owner (Maksym) builds, reviews and deploys. There is no deadline. The Worker is deployed by hand (`wrangler deploy`, D1 migrations with `wrangler d1 migrations apply`), and the app ships through the usual store build.
- Size M (`.size`), route standard (`.route`): two surfaces, a new Worker module, a D1 migration, an Isar schema change and five new app screens or parts of screens.
- Provider accounts and keys for OpenCode Zen, xAI and Higgsfield must exist before the Worker can offer their models. Until then, `models.json` lists only Anthropic models (ADR-0004).

**Conventions.**
- [`CLAUDE.md`](../../../CLAUDE.md) rules 1–6 and [`docs/architecture.md`](../../architecture.md) §2. Navigation goes only through typed routes, and dialogs/SnackBars are not routes. Services come from providers in `lib/core/providers.dart`. Screen data lives in a `@riverpod` notifier, and transient UI state stays in widget `State`. A feature is a folder, features don't import each other's screens, and one file ≈ one thing.
- Spec-approved overrides, which this feature carries out:
  - CLAUDE.md rule 3 / architecture.md rule 4 ("do not change how anything looks") gives way for the visible parts spec §1 lists: the Words screen's settings button, Words settings, Story runs and a run's details, the group pager on the learn page, the story screen in place of coming soon for Mnemonic story in the app, and the "Make a new story" confirmation.
  - CLAUDE.md rule 5 ("no new domain models — ask first"): `WordGroup` (embedded in `Session`), `StoryRun` with its `StoryStep`s (a new collection) and `WordPair.rowId`. Approved by the owner on 2026-10-07 in this design ([ADR-0003](adr/0003-keep-word-groups-in-the-session-and-story-runs-in-their-own-collection.md)). The text update is tracked in §11.
  - learn-part-step-1's invariant "the learn page saves nothing" is narrowed (spec §1). Ticks still last one visit, but word groups, the selected group, mnemonic stories and story runs are kept.
- The precedent for one shape shared by the app and the Worker is learn-part-step-1 ADR-0003: JSON in the Worker as the source of truth, read by the app. Here the app fetches it instead of copying it (ADR-0004).

**Regulatory / external.**
- Data classification: internal (spec §6.1). The words of a word group go to the chosen AI providers, as photo words go to Anthropic today. No personal data is added.
- Security review: required (spec §6.1). The Security Lead signs off §8 "Spending control" and ADR-0002 before release (§11).
- Provider terms: each provider is used only through its paid API with a key held as a Worker secret. Pictures that a provider refuses are a failed picture (AC-09), never retried with altered words.
