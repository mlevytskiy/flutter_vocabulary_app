---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-09-30"
feature_size: "S"
ticket: "docs/features/words-from-subtitles/spec.md"
---

# 0003 — Count subtitle imports per address and per day in D1

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Each subtitle import is one paid AI call worth roughly $0.07–0.30 at 100 words depending on the model. Spec §6 allows at most 10 imports per 10 minutes per app address and, by the owner's decision during design, at most 20 per UTC day across all addresses (AC-14). The existing `RATE_LIMITER` binding (20 requests / 60 s per IP, shared by all secret-gated routes) supports only 10 s or 60 s periods and cannot express either rule. The app secret ships in the app, so these counters are the real bound on spend if it leaks (ADR-0002).

## Decision drivers

- spec §6: "≤ 10 subtitle imports per 10 minutes" per address; "≤ 20 subtitle imports per UTC day" across all addresses.
- A precedent already in the Worker: `src/autofill/meter.ts` takes a per-page unit and an all-pages unit from D1 in one atomic batch.
- No new infrastructure type for an S feature; failed AI calls still cost money.

## Considered options

1. **D1 counters** — a table of per-address 10-minute windows and a per-UTC-day total, both taken in one D1 batch before the AI call.
2. **A second rate-limit binding at 1 import per 60 s** — at most 10 in any 10 minutes, no database; but a retry within a minute after a failure (AC-12) or two models compared back to back is refused, the binding is documented as approximate, and it cannot express a daily cap.
3. **A Durable Object per address** — an exact sliding window, but a new binding, class and migration type with no precedent in the repo.

## Decision outcome

**Chosen:** option 1. A new migration adds `subtitle_imports` rows keyed by (SHA-256 of `cf-connecting-ip`, 10-minute window start) and a per-UTC-day total row. After the secret, rate-limit, bounds and model checks, the route runs one batch that raises the day total only while it is below 20 and the address window is below 10, and raises the address window only if the day total was raised — so two requests racing for the last unit cannot both get it. Refusal returns the AC-14 response before any AI call; a taken unit is not given back when the AI call fails. The daily cron deletes address rows older than one day. The exact schema and migration are produced by `data-model`.

## Consequences

**Positive**
- Exactly the spec's two limits, worst-case spend about $26 a day even with a leaked secret used from many addresses (20 imports of a full 1 MB of lines on Opus 5.5, about $1.30 each).
- Reuses D1, the atomic-batch pattern and the daily cleanup already in the Worker.

**Negative**
- Fixed windows: an address can make up to 20 imports across a window boundary (the daily cap still holds).
- A shared daily cap means an abuser can use up the owner's own imports for the day.
- One more D1 write per import and a migration to apply before deploy.

**Neutral**
- The limits are constants in `src/subtitles/allowance.ts`; raising them is a one-line change.

## Links

- Spec: [[../spec.md]] AC-14, §6, §6.1
- SAD: [[../sad.md]] §4, §8, §10 QG-3, §11
- Related ADR: [[0002-strip-subtitles-in-the-app-and-send-dialogue-lines]], [[0004-let-the-learner-pick-the-subtitle-model-from-a-worker-allow-list]]
