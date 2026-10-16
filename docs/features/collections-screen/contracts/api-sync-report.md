# API sync report — collections-screen — 2026-10-16

**Contract:** [`openapi.yaml`](openapi.yaml), a **delta**. It covers `createSession` (`POST /sessions` gains an optional `title`) and `getSessionPage` (`GET /s/{id}` shows it as its heading). Every other Worker route is unchanged and not restated.

**Inputs:**
- `data-model.md`: present. D1 `sessions.title` (nullable), `WordCollection.name` (1–60 characters, one line), staged `migrations/01_add_session_title`.
- `sad.md`: §6 F12, plus §4 choice 6 and ADR-0008.
- `spec.md`: US-12, AC-02, AC-29–AC-31, §6.1.

`target_surfaces: [mobile-app, backend-service, web-frontend]` → OpenAPI for the Worker. The app consumes it: `collection_publish_service.dart` (renamed `session_publish_service.dart`) adds `title` to the body. The shared page is server-rendered by the same Worker.

**Size / route:** L / full. **Events:** none. Dialogue and picture deliveries are existing async calls whose contract does not change (they never read or write `title`), so there is no `events.md` and no new `Idempotency-Key`.

**Lint:** `npx @redocly/cli@1.34.0 lint` passes ("Your API description is valid") with 2 warnings, both accepted as in learn-part-step-1: no `info.license` (private API), and a localhost server entry.

## Deviations from the SDD defaults

These follow the Worker's own conventions, as the owner decided for words-from-subtitles (api stage, 2026-09-30) and carried into learn-part-step-1.

| SDD default | This contract | Why |
|---|---|---|
| `BearerAuth` global | `x-app-secret` on `POST /sessions`, `security: []` on the page | The Worker's existing app secret (`src/index.ts`); the page is `public: true` and a link is its only credential (spec §6.1) |
| `/api/v1/...` | `/sessions`, `/s/{id}`, unversioned | Existing routes; spec §1 keeps the Worker's addresses and every given link unchanged |
| `{code, message, details?}` | `{error, code?}` with a flat snake_case `code` | The Worker's existing shape (`changes.ts` uses `bad_request`, `gone`); `title_invalid` follows it |
| Every field in the body schema | Only `title` is specified; the rest is `additionalProperties: true`, listed for orientation | A delta contract: the other properties keep their current rules in `handlers.ts` |

## A — Field origins

| schema_path | origin | confidence |
|---|---|---|
| createSession.title (`CollectionTitle`) | data-model.md → WordCollection.name (1–60 characters, not only spaces, one line) → D1 `sessions.title` (staged 01_add_session_title) | high |
| createSession.title absent → NULL | data-model.md D1 `sessions.title` notes; ADR-0008 decision outcome | high |
| createSession 400 `title_invalid` | sad §6 F12 alt "the title breaks the name rule"; spec AC-02 | high |
| createSession other body properties, 200 `PublishResult`, 401, 413 | existing — `src/session/handlers.ts` `handleCreateSession`, `src/index.ts` secret check | high (unchanged) |
| getSessionPage `<title>` / `<h1>` | data-model.md D1 `sessions.title`; spec AC-29; `page.ts:259` today's fixed "Vocabulary" | high |
| getSessionPage escaped name | spec §6.1 abuse case "markup or script typed into a name"; existing `escapeHtml` | high |
| getSessionPage 404 | existing gone page (unchanged) | high |

Derivation notes:
- **Characters, not bytes, and the same count on both sides.** AC-02 says "1 to 60 characters". JavaScript `length` and Dart `String.length` count UTF-16 units, so an emoji counts as 2. The contract counts **Unicode code points** on both sides (JS `[...title].length`, Dart `title.runes.length`). That way the Worker never refuses a name the app accepted. `tasks` must give both checks the same test cases (an emoji, a Cyrillic name, exactly 60 and 61).
- **The title is not echoed** in the 200 response. The app already holds the name, and the response shape stays unchanged for older apps.
- **No trimming on the Worker.** The app validates before sending; the Worker stores what it was sent, so the page shows exactly the learner's name.

## B — Drift checklist

1. **Endpoint ↔ data-model** *(core)*: ✓. `createSession` writes `sessions.title`; `getSessionPage` reads it. Both are in data-model.md.
2. **Error code ↔ repo error definition** *(core)*: ✓ (proposal). The Worker has no central error registry; codes are inline strings in handlers (`bad_request`, `gone`). `title_invalid` is the contract's proposal in the same flat snake_case form. Reconcile if a registry appears.
3. **Validation ↔ constraint** *(core)*: ✓. `minLength: 1`, `maxLength: 60` and the one-line, not-only-spaces `pattern` match data-model.md and AC-02. D1 holds no `CHECK`, following `0001`'s "text limits in code", so the Worker's code is the only server-side check. That is consistent with the model, and stricter than nothing.
4. **OpenAPI ↔ sequence** *(supporting)*: ✓. F12's branches map as follows: title invalid → 400 `title_invalid`; valid → 200 with title stored on the same page and link on a republish; later delivery → dialogue routes untouched (described on `createSession`); partner reads → `getSessionPage` with the title or "Vocabulary".

**Back-feed (coverage):**
- AC-29 → `createSession` (title stored, republish replaces it, absent → NULL) + `getSessionPage` (title or "Vocabulary") ✓
- AC-30 → `getSessionPage` (only the name; no folder, collection or bin data exists on the Worker) ✓
- AC-31 → no contract: the share-sheet warning is app-only (sad §5 `words_table/`) ✓ N/A
- AC-02 → `CollectionTitle` constraints, 400 `title_invalid` ✓
- AC-33 (shared page text) → no contract change. A grep of `src/session/page.ts`, `src/session/client/` and `src/learn/` found no visible "session" text: the page already says "word list" / "Vocabulary". `implement` re-checks this with the full wording pass.
- Every operation maps to US-12 ✓. The 401 and 413 responses come from the existing route; no §6 flow draws them because they don't change. That is not a sequence gap.

**Findings needing a decision:** none (0 core ✗, 0 flags). The run did not pause.
