# CONTEXT — learn-remember-or-not

> Project-wide terms (learner, partner, session, shared page) live in the repo-root
> [CONTEXT](../../../CONTEXT.md); word group, selected group in
> [mnemonic-story](../mnemonic-story/CONTEXT.md); exercise, stage, word to learn in
> [learn-part-step-1](../learn-part-step-1/CONTEXT.md); film dialogue in get-words-from-subtitles-improvment.

## Glossary

- card — one word of a round shown as a flashcard: a front (the meaning) and a back (the word, its translation, an example line if there is one, the speaker). NOT a word row (the card is a view of a row for one round; it changes nothing in the row).
- front — the side of a card shown first: the word's meaning (stored definition, else translation) with the word itself masked as "___". NOT a prompt with options (the front has nothing to pick).
- showing — one time a card is put in front of the learner in a round; a card has one showing, or two if the learner tapped "Not yet" on the first. NOT a round (a round holds several cards).
- rating — the learner's own verdict after flipping: "Remembered" / "Not yet" on the first showing, "Got it" / "Still not" on the second. A hint for the summary only, never a word result. NOT a word result (`WordResult` is written only by Step 3 exams).
- example line — one line of a film dialogue of the same session that is linked to the word and holds the word exactly once, shown on the back with the word in bold. NOT an AI sentence (this exercise makes no AI call).
- usable word — here: a word to learn of the selected group whose front has at least one letter besides the "___" blank. NOT the pick-the-answer usable word (no options are needed here).
