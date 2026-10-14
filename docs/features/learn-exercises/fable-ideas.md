---
status: draft
source: "Fable 5.1, prompt by the owner: create 3 more exc (just description idea that can involved people and be useful)"
updated_at: "2026-10-14"
---

# Three new exercise ideas (Fable 5.1)

## 1. Guess my word (Stage 1 — passive vocabulary)
**Stage 1:** the learner only *recognises* the word from a description.
**One round.** The Worker's AI writes three graded clues per word of the current group (vague → closer → near-giveaway; simple English; never the word itself). The learner sees clue 1 and a 3×3 grid of the group's words; a right tap on clue 1 scores 3, clue 2 scores 2, clue 3 scores 1. A wrong tap greys the word out and reveals the next clue. The round ends when every word is found; a summary shows which words needed all three clues.
**Why it helps.** Each clue is another encoding (description, collocation, situation); the "almost got it" moment is retrieval effort. Words that always need clue 3 go to the "repeat" pool.
**People.** On the shared page the clues become a buzzer game: people across the table see clue 1 and shout the word; the learner taps whoever was first. A person can also write their own clue for a word; those replace the AI clues in the learner's next round.
**Needs.** Worker AI (3 clues per word, one call per group, cached with the group); shared page buzzer view + "add a clue" form written back under the row id.

## 2. Chain story (Stage 2 — active vocabulary)
**Stage 2:** the learner must *use* each word in their own sentence, with scaffolding.
**One round.** Opens with the first line of the group's Mnemonic story in English and shows the next unused word. The learner writes or dictates one sentence continuing the story with that word; the Worker's AI checks the word use, fixes grammar in one line, gently flags off-topic. The corrected sentence becomes the next line. After the last word TTS reads the whole chain and offers to save it as the group's "our version".
**Why it helps.** Generating a sentence inside a known plot binds the word to meaningful context; a one-line correction fixes form without demotivating.
**People.** Live on the shared page: each person takes the next word in turn from their own phone; the app shows whose line is whose. Three different sentences per word by the end.
**Needs.** Worker AI (~1 call per sentence); speech-to-text and TTS; shared page write access for turn order and lines; reuse StoryRun/StoryStep for "our version".

## 3. Explain it to a friend (Stage 3 — examination)
**Stage 3:** retrieve and explain each word with no cues; the result decides "known" vs "repeat".
**One round.** The app shows a word (English only) and a 30-second timer; the learner records an explanation for an imaginary friend — definition, example, synonym, anything but a translation. The Worker's AI scores the transcript 0–3 with a one-line reason: 3 = known, 0–1 = repeat, 2 = stays in queue. Whole group, random order, no second chances.
**Why it helps.** Explaining is the strongest retrieval (protégé effect); the timer stops rehearsing in Ukrainian first.
**People.** On the shared page the table-mates *are* the friend: they hear the recording (or read the transcript) and tap "I got it" / "I didn't" before the AI score shows; a human "didn't" overrides an AI 3 down to 2. In-person mode: the learner explains aloud, a table-mate taps when they understand; time taken is the score, no AI.
**Needs.** Speech-to-text + Worker AI scoring (one call per word); shared page audio/transcript playback and a two-button vote written back to the row; lightning-icon rules map the score to known/repeat.
