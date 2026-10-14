---
status: draft
stage: 2
updated_at: "2026-10-14"
source: "Fable ideas (fable-ideas.md §2)"
---

# Chain story

## Goal
Stage 2 (active). The learner uses each word in their own sentence inside a known story. The plot gives help; the sentence is the learner's.

## One round
- The app opens with the first line of the group's Mnemonic story in English.
- It shows the next unused word.
- The learner writes or dictates one sentence that continues the story with that word.
- The Worker's AI checks the word use, fixes grammar in one line, and flags off-topic gently.
- The fixed sentence becomes the next line. After the last word, TTS reads the whole chain.

## What it uses
- Group words, the group's mnemonic story (built). AI on the Worker: about 1 call per sentence.
- Speech-to-text, TTS. Shared page: see People.

## Result
Per word: sentence used the word right, with small fix, or with big fix.

## People
Up to 3 people on the shared link take turns by word from their phones; each line shows its author. Needs write access on the shared page.

## Acceptance criteria
- Given a group with a story, when the exercise starts, then the first story line and the first word show.
- Given a sentence without the target word, when sent, then it is not accepted and the learner is asked again.
- Given a sentence with a grammar error, when checked, then one corrected line shows.
- Given the last word, when done, then TTS can read the whole chain.
- Given a group with no story, when started, then it says the story is needed first.

## Open questions
- Does the chain need the mnemonic story, or can AI start a fresh plot?
- Save the chain as "our version" (reuses StoryRun)? Needs owner OK for a new record.
