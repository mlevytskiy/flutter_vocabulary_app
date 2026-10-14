---
status: draft
stage: 2
updated_at: "2026-10-14"
source: "lib/features/learn/exercises.dart (plan: Step 2, guess the word in context)"
---

# Fill the gaps

## Goal
Stage 2 (active). The learner writes the missing word in a sentence. They must produce the word, not just recognise it.

## One round
- The app shows a sentence with one gap and the translation of the word as a hint.
- The learner types the word.
- The app checks it (ignores case; a close spelling is "almost").
- On a miss, the first letter is shown and the learner may try once more.
- The round runs over all words of the group. A summary lists the words missed.

## What it uses
- Sentences: from the dialogues of the session if present; otherwise AI on the Worker writes one simple sentence per word (cached).
- Words, translations. Shared page: no.

## Result
Per word: right on 1st try, right on 2nd try (after hint), or missed.

## People
App only in v1.

## Acceptance criteria
- Given a word and a sentence, when the question shows, then the word is hidden and the translation is shown.
- Given the right word in any case, when sent, then it counts as right.
- Given a wrong word, when sent, then the first letter shows and one more try is allowed.
- Given the sentence still contains the word elsewhere, when it is made, then it is rejected.
- Given the last word, when answered, then the summary lists the missed words.

## Open questions
- Is a typo like "recieve" accepted? Which distance?
- Word forms (past tense) — accept them?
