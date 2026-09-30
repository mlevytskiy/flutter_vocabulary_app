---
status: Living
updated_at: "2026-09-30"
---

# Domain Context — words-from-subtitles

## Glossary

- subtitle file — a text file with a film's or episode's spoken lines and their timings, opened by the learner from the phone. NOT a video file (the app never plays or reads the video itself).
- subtitle import — one run of picking words from a subtitle file: the learner chooses the file and the import options in the import dialog, and the app proposes words in the results dialog. NOT a photo import (a photo import takes only the words the learner highlighted on a page).
- import purpose — what the picked words are for: "understand this film" (every word above the learner's level needed to follow this film, rare ones included) or "frequent words for the future" (words above the learner's level that are common in English generally). NOT the word detail mode (that decides what a word row shows, not which words are picked).
- English level — the learner's level on the six-step European scale A1, A2, B1, B2, C1, C2; words at or below it are treated as already known. NOT a word's own level (the level the app estimates for each word).
- word maximum — the most words one subtitle import may propose, from 1 to 100. It is a limit, not a target: an import proposes fewer when fewer words qualify. NOT the photo word cap (that one is fixed at 20 and not chosen by the learner).
- import dialog — the dialog over the main screen, opened from the speed dial, where the learner picks the subtitle file, import purpose, English level and word maximum and starts the import. NOT a screen (there is no separate import screen to go back to).
- remembered choices — the purpose, level and maximum used in the last subtitle import, which the import dialog opens with while the Settings switch "remember my last choices" is on. NOT the Settings defaults (those are used only when the switch is off).
- results dialog — the list of proposed words shown after a photo or subtitle import, where each word can be removed before Done adds the rest to the current session. NOT the words table (that shows a whole session).

## Invariants

- An import never proposes a word at or below the chosen English level, and never proposes more words than the word maximum.
- An import never proposes a word that is already in the current session.
- Names of people and places, sound captions and formatting marks are never proposed as words.
- When more words qualify than the word maximum, the most important for the chosen import purpose are kept and shown first.
