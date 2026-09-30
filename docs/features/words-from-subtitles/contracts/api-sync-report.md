# API sync report — words-from-subtitles — 2026-09-30

**Contract:** [`openapi.yaml`](openapi.yaml) — one operation, `POST /subtitles/words` (`pickSubtitleWords`).
**Inputs:** data-model.md ✓ found · sad.md §6 (F1–F4) ✓ found · spec.md §4/§5 ✓ found · ADR-0001…0004 ✓ · `target_surfaces: [mobile-app, backend-service]` → OpenAPI for the Worker; the app consumes it.
**Size / route:** S / quick. **Events:** none. Every flow is synchronous (sad §6 coverage note), so there is no `events.md` and no `Idempotency-Key`.
**Lint:** `npx @redocly/cli lint` passes with 2 warnings, both accepted: no `info.license` (private API) and a localhost server entry (`wrangler dev`).

## Deviations from the SDD defaults (owner decision, api stage 2026-09-30)

The owner chose to follow the Worker's existing wire conventions. No ADR records this; the decision is logged here.

| SDD default | This contract | Where the Worker already does this |
|---|---|---|
| `BearerAuth` | `x-app-secret` apiKey header | `src/index.ts` `fetch`, `CORS_HEADERS` |
| `/api/v1/...` | `/subtitles/words`, unversioned | `/analyze`, `/define`, `/sessions` |
| `{code, message, details?}`, `module.error_name` | `{error, code?}`, bare snake_case `code` | `src/session/changes.ts` (`bad_request`, `gone`), the page write limiter (`rate_limited`) |
| snake_case JSON | camelCase JSON | `publishedId`, `editToken`, `timings.aiMs` |

## A — Field origins

| schema_path | origin | confidence |
|---|---|---|
| pickSubtitleWords.lines | ADR-0002 outcome and sad §8 Abuse bounds (≤ 200 chars each, ≤ 1 MB total); spec §6 "exactly 1 MB" | high |
| pickSubtitleWords.purpose | CONTEXT "import purpose" (2 values), spec AC-07 | high |
| pickSubtitleWords.level | CONTEXT "English level" A1–C2, AC-06 | high |
| pickSubtitleWords.maximum | CONTEXT "word maximum" 1–100, AC-09, sad §8 | high |
| pickSubtitleWords.model | ADR-0004 allow-list, AC-21; Anthropic model ids | high |
| pickSubtitleWords.sessionWords | AC-15, sad §6 F3; bounds from the existing schema — `src/session/types.ts` `MAX_ENTRIES` = 500, `MAX_FIELD_CHARS` = 500; sad §8 "≤ 500 session words" | high |
| 200.words[] | AC-02 (translation, definition, film sentence), AC-06, AC-19 | high |
| 200.words[].word / translation / description / context | existing wire shape of `/analyze` → `lib/core/models/vocab_word.dart` `VocabWord.fromJson` | high |
| 200.model | ADR-0004 "response returns the model id" | high |
| 200.timings.aiMs | ADR-0004 "the AI time"; existing `/analyze` `timings.aiMs` | high |
| 200.usage.inputTokens / outputTokens | ADR-0004 "input and output token counts"; sad §7 log line | high |
| ErrorBody.error / code | existing Worker error body (see Deviations); codes from the sad §6 F3 alt-branches | high |
| (allowance, not on the wire) | data-model.md → `subtitle_imports`, `all_subtitle_imports`; the route writes them and never returns them | high |

Derivation notes:
- **1 MB = 1,048,576 bytes.** The app's AC-11 file check and the Worker's 413 check must use this same constant, since spec §6 says "exactly 1 MB".
- **The `description` key is kept** instead of `definition`, so the app reuses `VocabWord` (CLAUDE.md rule 5). "Definition" is only the UI label (AC-18).
- **`inputTokens` includes cache reads and writes.** The cost line is approximate (ADR-0004), so one input count is enough.

## B — Drift checklist

1. **Endpoint ↔ data-model** *(core)* ✓ `pickSubtitleWords` writes `subtitle_imports` and `all_subtitle_imports` (the ADR-0003 take). Nothing else it touches is stored.
2. **Error code ↔ repo** *(core)* ✓ The repo has no central error registry: each route writes its codes inline (`changes.ts`, `index.ts`). `bad_request` already exists. The new codes are this contract's proposal: `unknown_model`, `too_large`, `no_english_lines`, `too_many_imports`, `words_not_picked`. `implement` defines them in `src/subtitles/routes.ts`.
3. **Validation ↔ constraint** *(core)* ✓ `maximum` 1–100 matches AC-09 and sad §8. The line bounds match ADR-0002 and sad §8. `sessionWords` matches the existing session limits. The allowance limits (10 per window, 20 per day) are constants in the Worker, not on the wire, and they match data-model.md and ADR-0003.
4. **OpenAPI ↔ sequence** *(supporting)* ✓ with one follow-up note:
   - Every F3 alt-branch has a response: secret → 401; out of bounds / unknown model → 400; allowance → 429 `too_many_imports`; AI failure / cut off / not a list → 502; no English lines → 422; complete list → 200; no word qualifies → 200 with an empty list.
   - **Sequence gap (follow-up, owner `sequences`, due before `tasks`):** F3 has no alt-branch for two outcomes the Worker produces. One is the shared `RATE_LIMITER` refusal (429 with no `code`), which F3 only mentions as "checks … the request rate". The other is the 413 size backstop, which F3 folds into "bad request". The app shows the AC-14 message for the first and the AC-12 message for the second, so the user-visible behaviour is already covered and the gap is in the drawing only.

## Back-feed — AC coverage

| AC | Contract surface |
|---|---|
| AC-02 | 200 `words` with translation, description, context |
| AC-06 | `maximum`; `words` ≤ maximum |
| AC-07 | `purpose` |
| AC-08 | `lines` stripped by the app; `context` is the spoken line |
| AC-10 | 422 `no_english_lines` (the file-level part is app-only, F3 first `alt`) |
| AC-12 | 502 `words_not_picked`; complete-or-nothing 200 |
| AC-13 | 401 (security `AppSecret`) |
| AC-14 | 429 `too_many_imports` (plus the rate-limiter 429) |
| AC-15 | `sessionWords` |
| AC-19 | `words` order |
| AC-20 | 200 with `words: []` |
| AC-21 | `model` allow-list, 400 `unknown_model`, 200 `model` / `timings` / `usage` |
| AC-01, 03, 04, 05, 05b, 09, 11, 16, 17, 18 | App-only (dialogs, preferences, session, labels); no contract surface. AC-09's bound is repeated server-side as a 400. |

Every operation maps to a user story (US-01, US-02, US-05, US-06) and to at least one AC. No orphan sequence (F1, F2 and F4 are device-only).

## App error mapping (for `subtitle_words_service.dart`, sad §8 Error handling)

| Outcome | App message |
|---|---|
| 422 | AC-10: "no English subtitles to read in this file" |
| 429 (any) | AC-14: "wait a few minutes and try again" |
| 400, 401, 413, 502, any other status, no connection, no answer within 240 s | AC-12: "the words could not be picked, try again from the speed dial" |

## Open items

- **Spec amendment still pending** (from the sad §6 notes): Settings holds one set of values plus an "Update with each import" switch. data-model.md was updated to this model during this stage; spec §1, US-03, AC-05 and CONTEXT still need `/sdd:clarify`. The contract is not affected.
- **Sequence gap** in B.4 (owner `sequences`), drawing only.
