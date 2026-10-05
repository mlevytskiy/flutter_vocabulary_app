---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "XS"
ticket: "docs/features/photo-from-gallery/spec.md"
---

# 0002 — Send very tall images through the normal photo path

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Spec §8 left open what to do with very tall scrolling screenshots, for example 1080×20000. `PhotoScaler` scales by the shorter side to 640 px, so the `/analyze` copy of such an image is about 640×11852. The Anthropic API refuses images with a side over 8000 px (its documented limit), and the Worker turns that into 502 "Failed to analyze photo, please try again". If a long side does fit, the API itself shrinks the long side to about 1568 px, which leaves text too small to read and returns no words. AC-08 requires only that the app shows the results dialog or a plain message, never freezes or closes, and keeps no photo when no words are kept.

## Decision drivers

- AC-08 and spec §6 robustness: 10 of 10 test images end in the results dialog or a plain message within 60 s, with 0 crashes and 0 freezes.
- Spec §2 / §1: after the pick, a gallery photo behaves exactly like a camera photo, through one shared photo chain.
- Size XS: no splitting one image into several requests (spec §8, §3).

## Considered options

1. **Treat it like any image.** Send it down the normal path and show whatever comes back: the results dialog, or the Worker's failure message.
2. **Refuse before the request.** Read only the image header (Flutter's built-in `ImageDescriptor`). If the 640 px copy's long side would exceed 8000 px, say "This image is too tall to read. Crop it and try again." and send nothing.
3. **Shrink by the longer side.** Scale such images so the long side fits the API's limit, so the request is accepted.

## Decision outcome

**Chosen:** Option 1. It needs no code, keeps the camera and gallery paths identical, and still meets AC-08: the outcome is a plain message or an empty or short results dialog, never a freeze, and the existing `finally` deletes the kept copy. Option 2 gives a more honest message but adds a check and a threshold tied to another service's limit, and images just under that threshold still return no words. Option 3 always reaches the API, but the API's own downscale leaves a strip about 85 px wide, so it practically never returns words.

## Consequences

**Positive**
- Zero code. There is one photo chain for both sources.
- AC-08 holds with no special case.

**Negative**
- The "please try again" message misleads for a tall screenshot, because a retry gives the same result (sad §11, Low).
- One AI request is spent on an image that cannot give words.

**Neutral**
- Option 2 can be added later in the gallery path alone, if the device pass or real use shows tall screenshots often. The change is local to `_processPickedPhoto`.

## Links

- Spec: [[../spec.md]] §8 (open question resolved), AC-08, §6 robustness
- SAD: [[../sad.md]] §4 (choice 4), §10 QG-2, §11
- Related ADR: [[0001-turn-on-the-android-photo-picker-for-gallery-picks]]
