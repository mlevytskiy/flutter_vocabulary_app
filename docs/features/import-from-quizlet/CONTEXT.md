---
status: Living
updated_at: "2026-10-06"
---

# Domain Context — import-from-quizlet

## Glossary

- Quizlet set — a named list of cards on Quizlet that the learner opens by its link; each card has a term, a back side and sometimes an example sentence. NOT a session (a session lives in the app; a set lives on Quizlet and is only read, never changed).
- card — one entry of a Quizlet set: a term on the front, a back side (Quizlet calls it the definition) and an optional example sentence; the term becomes the word, the back side and example become the word row's definition. NOT a word row (a card becomes a word row only after the learner keeps it in the results dialog).
- set source — a Quizlet set, kept as its name and link, that at least one word row of the session was imported from. NOT source photo (a photo source shows an image; a set source shows a name and a link), and NOT any set the learner opened (a set none of whose rows remain is not a set source and is not published).
- source — a source photo or a set source; the shared page's source pager shows both kinds. NOT where a translation or definition came from (automatic translation, the dictionary or a card's back side).
- skeleton card — a grey placeholder card in the progress dialog's pager, shown for at least a second before the set's cards fill it. NOT a card of the set (it holds no text and never becomes a word).
- Include photos — the Words-screen switch that decides whether source photos go on the shared page. NOT a switch for set sources (those are always published).

## Invariants

- A word row has at most one source: a source photo, a set source, or none.
- A word row imported from a card keeps its set source through edits on the shared page, like a row keeps its source photo.
- A set source with a remaining word row is published with every shared link; only source photos can be held back.
