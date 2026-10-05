---
status: Living
updated_at: "2026-10-06"
---

# Domain Context — photo-from-gallery

> Project-wide terms (learner, partner, session, shared page, word row) live in the repo-root
> [`CONTEXT.md`](../../../CONTEXT.md). "Source photo" is defined in
> [`good-looking-web/CONTEXT.md`](../good-looking-web/CONTEXT.md); this feature widens it from "a photo the learner
> took" to "a photo the learner took or picked from the gallery", with the same rule that at least one word
> row must come from it.

## Glossary

- gallery — the phone's own photo library, opened through the phone's system photo picker, from which the learner picks one existing photo. NOT the app's History (History lists the learner's sessions, not photos).
- photo import — one run of getting words from one photo: the learner chooses Camera or Gallery, the app recognises the highlighted words, and the results dialog lets the learner keep some of them. NOT a subtitle import (a subtitle import proposes words from a film's dialogue, with no photo).
- source choice — the small dialog shown after tapping "Get words from photo" that offers Camera or Gallery. NOT a setting (the choice is made every time and is not remembered).

## Invariants

- One photo import runs at a time on the word-input screen (new with this feature, for Camera and Gallery alike).
- A photo becomes a source photo only when at least one of its words is kept, whether it came from the camera or the gallery.
- The original photo in the gallery is never changed or deleted by the app.
