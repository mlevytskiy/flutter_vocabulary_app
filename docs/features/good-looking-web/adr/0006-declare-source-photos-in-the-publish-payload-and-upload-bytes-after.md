---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0006 — Declare source photos in the publish payload and upload their bytes after

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

The shared page must show which rows came from which photo (US-03, AC-25). Publishing must open the link dialog as soon as the word list is stored, with photos uploading in the background, retried, never blocking the app; a photo that never arrives shows as an empty placeholder in its place and its rows stay linked to it (AC-37). Today the Worker generates a photo's id only when its bytes are uploaded (`POST /sessions/<id>/sources`), a route the app has never called.

## Decision drivers

- AC-37 and spec §6: link dialog p95 ≤ 3 s after tap whatever the photos do; all 3 photos on the page p95 ≤ 30 s in the background.
- AC-24: with "include photos" off, no photo of the session can be reached, even by guessing.
- AC-26: sessions from before this feature, and older app builds, publish unchanged.
- spec OQ-3 default: at most 10 photos per session — the first 10 taken; the app names the rest.

## Considered options

1. **Declare photos up front** — the app gives each photo its own id when it is taken; the publish request lists the photos and each row's photo id; the bytes follow under those ids.
2. **Photos first, then words** — the app uploads photos, collects the Worker's ids, then publishes the words with them (or re-links rows after a later upload).

## Decision outcome

**Chosen:** option 1. The publish request carries `sources` (id and order of up to 10 photos) and a `sourceId` on each recognised row; the Worker stores each declared photo as a slot marked "pending". The app then uploads each photo's bytes to its declared id through a secret-gated route that accepts only declared ids and treats a repeat as a no-op, retrying with back-off while the app runs. The page shows a pending slot as a placeholder in its place in the pager, and polling (ADR-0005) replaces it when the bytes arrive. With "include photos" off, the app sends no `sources` and no `sourceId`, so there is nothing to guess.

## Consequences

**Positive**
- The page knows every photo and link from the first render; a failed upload degrades to a placeholder exactly as AC-37 describes.
- Row–photo links travel with the rows in D1, so edits keep them (AC-34) and a republish re-links them the same way (ADR-0008).

**Negative**
- The upload route changes shape (declared id instead of server-generated) and the app must generate and keep photo ids.
- An upload that never finishes (app closed, no network) leaves a permanent placeholder for that link.

**Neutral**
- Old app builds send neither field and publish exactly as today (AC-26).

## Links

- Spec: [[../spec.md]] US-11, US-12, AC-23 – AC-26, AC-34, AC-37, §8 OQ-3
- SAD: [[../sad.md]] §4, §5, §6
- Related ADR: [[0008-overwrite-the-same-link-when-a-session-is-republished]]
