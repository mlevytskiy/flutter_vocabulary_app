# API sync report — learn-part-step-1 — 2026-10-06

**Contract:** [`openapi.yaml`](openapi.yaml). It has three public GET operations: `getLearnPage` (`/s/{id}/learn`), `getComingSoonPage` (`/s/{id}/learn/{exercise}`) and `getLearnScript` (`/assets/learn-{hash}.js`).
**Inputs:** data-model.md is absent. This is a **legal fast-lane skip**: sad §2 and §4 say "no table, column or migration changes", there are no staged `migrations/`, and the spec adds no stored entity. Fields come from the existing schema (`vocab-photo-api/migrations/0001_sessions.sql`, `src/session/types.ts`) and from ADR-0003's `exercises.json`. The other inputs were found: sad.md §6 (two seed flows plus S-01 to S-05), spec.md §4/§5, and ADR-0001 to ADR-0003. `target_surfaces: [mobile-app, backend-service, web-frontend]` → OpenAPI for the Worker. The app consumes nothing new: its learn page reads the device.
**Size / route:** S / quick. **Events:** none. Every flow is a synchronous read, so there is no `events.md` and no `Idempotency-Key`.
**Lint:** `npx @redocly/cli lint` passes with 3 warnings. All three are accepted: there is no `info.license` (private API); there is a placeholder server host (the real one is gitignored); and `ExerciseList` is never referenced, because it pins the shape of `exercises.json` for the parity test (ADR-0003) and is not a wire body.

## Deviations from the SDD defaults

These follow the Worker's own conventions, as the owner decided for words-from-subtitles (api stage, 2026-09-30). No ADR records the decision; it is logged here.

| SDD default | This contract | Why |
|---|---|---|
| `BearerAuth` global | `security: []` on everything | Every route is `public: true`, like `GET /s/{id}`. A link is the only credential (spec §6.1) |
| `/api/v1/...` | `/s/{id}/learn…`, unversioned | These are page addresses that users see and share (ADR-0002) |
| `{code, message, details?}` JSON errors | HTML 404 gone page; the router's `{error}` JSON for 405 and for ids that don't match the pattern | AC-09 requires the answer to match the shared page's dead-link answer exactly |
| JSON bodies | `text/html`, `text/javascript` | Server-rendered pages (ADR-0002, good-looking-web ADR-0002) |

## A — Field origins

| schema_path | origin | confidence |
|---|---|---|
| getLearnPage.id / getComingSoonPage.id | existing schema — `0001_sessions.sql` `sessions.id`; `src/session/types.ts:162` `ID_PATTERN` | high |
| getLearnPage.pick / getComingSoonPage.pick | ADR-0002 decision outcome (`?pick=`, repeated for several ticks, invalid values ignored) | high |
| getComingSoonPage.exercise (`ExerciseId` enum) | ADR-0003: the eleven ids, frozen | high |
| getLearnScript.hash | existing convention — `src/session/assets.ts` `page-[0-9a-f]{12}.js` | high |
| 200 learn page · word count | existing schema — `0001_sessions.sql` `rows.word`, `rows.translation`, `rows.definition`, `rows.deleted_at_rev IS NULL`; rule = CONTEXT "word to learn" = `WordPair.isFilled` | high |
| 200 learn page · exercise list | ADR-0003 `exercises.json` (`Exercise` schema) | high |
| 200 no-words page | spec AC-08b, AC-10; sad §6 S-04 branch | high (the status 200 is a derivation, see note) |
| 200 coming-soon page | spec AC-05; ADR-0002 | high |
| 404 GonePage | existing `renderNotFoundPage` (`src/session/page.ts:222`), AC-09 | high |
| 405 RouterError.error | existing router answer, `src/index.ts` | high |
| Headers NoStore / PageCsp | existing `htmlResponse` (`src/http.ts`), `pageHeaders()` (`src/session/assets.ts:46`) | high |
| Exercise.id / name / stage / available | ADR-0003 decision outcome (`stage: 1 \| 2 \| 3`; names = AC-04 labels) | high |

Derivation notes:
- **The no-words page is a 200, not a 404 or 422.** The session is live and nothing failed. CONTEXT treats "coming soon" the same way ("NOT an error"). A 404 here would also break AC-09's rule that only dead links look dead. No input states a status, so this is the contract's call.
- **An id or exercise that doesn't match the route pattern never reaches the handler.** It gets the router's JSON `{"error":"Not found"}` 404, just as `GET /s/<bad id>` does today. The learn routes therefore match the shared page's behaviour exactly (AC-09). This also covers an empty exercise segment (`/s/{id}/learn/`).
- **The page text is "This word list is gone" (no full stop).** The spec quotes it with a full stop. The contract reuses the page as it is, so nothing changes.

## B — Drift checklist

1. **Endpoint ↔ existing schema** *(core)* ✓ `getLearnPage` and `getComingSoonPage` read `sessions` (whether the session is live, via `expires_at`). `getLearnPage` also reads `rows`. Nothing is written. `getLearnScript` is a static asset with no entity, mapped to US-04 / AC-05 / AC-07 through ADR-0002. No column the contract needs is missing from the live DDL, so the skip is legal.
2. **Error code ↔ repo** *(core)* ✓ No new error codes. The repo has no central registry; each route writes its codes inline. The only JSON body is the router's existing `{error}` (405, pattern-miss 404). The 404 here is the existing HTML gone page.
3. **Validation ↔ constraint** *(core)* ✓ `id` uses the same pattern as `ID_PATTERN` (`[A-Za-z0-9-]{1,64}`). `exercise` is limited to the eleven ADR-0003 ids, and only the available one answers 200. `pick` is never validated into an error, by design (ADR-0002, AC-06).
4. **OpenAPI ↔ sequence** *(supporting)* ✓ with one sequence gap:
   - S-04 learn link: an expired or unknown session → 404 GonePage. A live session with no word to learn → 200 no-words page. A live session with words → 200 learn page. The "learn page with the pick" → 200 with ticks. A pick of a coming-soon or unknown exercise → ignored. The `opt` for an unknown or unavailable exercise → 404 GonePage.
   - S-04 Start → `getComingSoonPage` 200. "Back to exercises" → `getLearnPage?pick=`.
   - S-03: the shared page's Learn reuses the **existing, unchanged** `GET /s/{id}/changes`, and its failure branch is client-only. The added `<a href="/s/{id}/learn">` in the shared page's HTML changes no operation. Neither is in this contract.
   - S-01, S-02 and S-05 are app-only, with no contract surface.
   - **Sequence gap → OQ-1** (below): S-04 loads the session for the coming-soon page but draws no branch for a live session whose saved rows no longer hold a word to learn.

## Back-feed — AC coverage

| AC | Contract surface |
|---|---|
| AC-04 | `getLearnPage` 200 learn page (count, stages, eleven exercises, nothing ticked without `pick`) |
| AC-05 | `getComingSoonPage` 200; `pick` round trip; `getLearnScript` (`replaceState`, Back) |
| AC-05b | `getLearnPage` without `pick` (the Learn link carries none) |
| AC-06 | `pick` of a coming-soon/unknown id ignored; `getComingSoonPage` 404 for an unavailable exercise |
| AC-07 | `getLearnScript` (Start / hint), learn page's initial unavailable Start + hint |
| AC-08 | `getLearnPage` 200 at its own link; 320 px note |
| AC-08b | `getLearnPage` 200 learn page or 200 no-words page |
| AC-09 | `GonePage` 404 on both page routes, identical to `GET /s/{unknown}` |
| AC-10 | `getLearnPage` 200 no-words page (the Worker re-checks saved rows); the toast is client-side on the existing `/changes` |
| AC-01, 02, 03, 11, 11b, 12, 13 | App-only (top bar, SnackBar, History session); no contract surface |

Every operation maps to US-04 (and through the shared plan to US-02/US-03) and to at least one AC. There is no orphan sequence: S-01, S-02 and S-05 run only on the device.

## Open items

- **OQ-1: coming-soon page for a session with no word to learn.** Owner: `sequences` (Maksym). Due: before the contract is finalized (before `tasks`). Someone can delete the last word rows on the shared page after the learn page has loaded and before Start is pressed, or can open a coming-soon link directly. Neither S-04 nor ADR-0002 says what then happens. The contract **provisionally renders the coming-soon page (200)**, because the coming-soon page shows no word count and ADR-0002 names only the 404 cases. The alternative is the no-words page, which follows the CONTEXT invariant "a session with no word to learn offers no way into the learn page" more strictly. To resolve: add the branch to S-04 and update `getComingSoonPage` to match.
- **Glossary:** sad §12 already flags "exercise list" and "pick" for `/sdd:glossary`. The contract uses both as named there.
