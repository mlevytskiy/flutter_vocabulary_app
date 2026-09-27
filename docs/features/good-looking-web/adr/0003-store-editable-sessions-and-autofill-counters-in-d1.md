---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0003 — Store editable sessions and autofill counters in D1

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

A published session is one JSON document in Workers KV today. KV is eventually consistent (a write can take up to ~60 s to appear at other locations), has no compare-and-swap and allows about one write per second per key, so two partners saving at once can silently overwrite each other — which the spec's "0 lost edits" NFR forbids. The per-page definition allowance and the all-pages share of the dictionary quota also need counters that cannot be over-spent by concurrent requests.

## Decision drivers

- spec §6: 0 lost edits under concurrent editing; cell save p95 ≤ 1.0 s; 50 definition lookups per page per day; all shared pages together stop at 500 of the 1,000 daily calls.
- AC-11, AC-12, AC-15b (conflicts), AC-18, AC-18b, AC-20, AC-29 (allowance and reserved share).
- D4: a session and its photos live 30 days, with no delete.
- sad §1 quality goals 1 and 2.

## Considered options

1. **A Durable Object per session** — one single-threaded object per session with its own strongly consistent SQLite storage; alarms expire it after 30 days; a separate object for the global counter.
2. **D1** — one SQLite database for all sessions, rows, photo slots and counters, with conditional updates for version checks and counters and a scheduled clean-up for expiry.

## Decision outcome

**Chosen:** option 2, D1 (owner's choice). Every session, row, cell revision and counter lives in one queryable database: conflicts are conditional updates in one batch, the per-page allowance and the all-pages quota are conditional increments ("add one only while below the limit") in the same store, and spec §7's KPIs (share of sessions edited, autofill hit rate) are plain queries.

How the pieces fit:
- New publishes write to D1 only. `SESSIONS` KV becomes read-only: a link published before this feature is imported into D1 the first time its page opens, then served from D1; a link in neither store is "gone" (AC-32).
- Expiry: every session row carries `expires_at`; a daily cron trigger deletes expired sessions with their rows, photo slots and counters. Reads treat an expired row as gone even before the clean-up runs. Photo bytes stay in the `SOURCES` R2 bucket, aged out by the bucket lifecycle rule (sad §11).
- Counters: one row per (session, UTC day) for the page allowance and one row per UTC day for all pages; the app's own `/define` calls are not counted — pages simply can never pass 500.

## Consequences

**Positive**
- Strong consistency and conditional writes make the "0 lost edits" guarantee and the quota caps enforceable in SQL.
- One store for data, counters and KPI queries; available on the free plan.

**Negative**
- D1 has a single primary location: a partner far from it pays more round-trip time per save, a risk to the 1.0 s save target (sad §11).
- SQL migrations and a cron trigger are new moving parts; D1 has no TTL, so expiry is our code.
- Two stores during the 30-day transition (D1 for everything new, KV for not-yet-opened old links).

**Neutral**
- Moving one hot session into a Durable Object later stays possible behind the same API.

## Links

- Spec: [[../spec.md]] §6, AC-11, AC-12, AC-15b, AC-18, AC-18b, AC-20, AC-29, AC-32
- SAD: [[../sad.md]] §4, §5, §7
- Related ADR: [[0004-detect-edit-conflicts-with-a-revision-per-cell]]
