---
status: Living
updated_at: "2026-10-06"
---

# Domain Context — import-from-quizlet

## Glossary

- Quizlet set — a named list of cards on Quizlet that the learner opens by its link; each card has a term and a back side. NOT a session (a session lives in the app; a set lives on Quizlet and is only read, never changed).
- card — one entry of a Quizlet set: a term on the front and a back side. NOT a word row (a card becomes a word row only after the learner keeps it in the results dialog).
- set source — a Quizlet set, kept as its name and link, that at least one word row of the session was imported from. NOT source photo (a photo source shows an image; a set source shows a name and a link), and NOT any set the learner opened (a set none of whose rows remain is not a set source and is not published).
- source — a source photo or a set source; the shared page's source pager shows both kinds. NOT the place a translation came from (the dictionary or the card's back side).

## Invariants

- A word row has at most one source: a source photo, a set source, or none.
- A word row imported from a card keeps its set source through edits on the shared page, like a row keeps its source photo.
- For a word row imported from a card, the translation is the card's back side as written (one line, cut to the shared page's length); it may not be Ukrainian (owner decision 2026-10-06). This narrows the project glossary's "translation" for these rows only.
