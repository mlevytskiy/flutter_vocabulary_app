# Warm-up v2 — improvement tasks (2026-10-31)

Source: the owner's two AI conversations (24 Oct "feeling that your words change something", 31 Oct
"Personalised English conversation topics") and the owner's picks on the decision page
https://claude.ai/artifact/XwqcVzbPfNoMzHnjsNVBAS (31 Oct). This is spec input for
`/sdd:specify learn-warm-up-v2`, not a spec. The warm-up's new look needs approval in that spec
(CLAUDE.md rule 3).

## Owner decisions (2026-10-31)

| # | Question | Owner's pick |
|---|---|---|
| D1 | Speaking task must need the target word? | **Keep**: the task needs the word (24 Oct rule stays) |
| D2 | Mic on a speaking turn | **Keep**: starts at once |
| D3 | Words per mission | **Keep**: Easy ≤ 6, Hard ≤ 12 |
| D4 | Warm-up | **New approach** (owner's note): a normal dialog with AI, progress bar on top, three parts: **intro** (first time only: ask the English level), **main part** (one of the 3 questions, at random), **special question** (sometimes, e.g. every 5th warm-up) |
| D5 | Remember answers? | **Yes, as a learner profile** (owner's note): English level, where they work, why they learn English, etc. Used only to propose more accurate topics; the app does not continue earlier dialogs |
| D6 | Topic catalog | **Use the revised 50** |
| D7 | Measuring | **Counts + an occasional 👍/👎** |

Dropped by the owner (not built): A0 golden mission, A1 role/goal agree, A2 information gap,
A3 react to your line, A4 two endings, A5 purpose-not-word, A6 3–4 words, B1 "your turn" + Done,
B2 help in steps, B3 intent hints. The talk mission stays as `talk-mixed` builds it today.

## Tasks

### W1. Learner profile (app, S)
- A small profile saved on the phone (`shared_preferences`, approved; no new domain model), filled
  only from the warm-up answers: English level, work / daily context, why they learn English, plus
  the fields the special questions add.
- Each field can be empty. Learn settings shows the profile; each field can be changed or cleared.
- The profile goes with the `/learn/topics` request only. It is never added to the talk's history.
- AC: an answer is saved to its field; clearing a field removes it from the next topics request.

### W2. Warm-up as a dialog in three parts (app + Worker, M, look change)
- The warm-up uses the Talk with AI dialog look with a progress bar on top. The number of steps
  equals the parts in this warm-up (2 or 3).
- **Intro**, only while the profile has no English level: "What's your English level?" with tap
  answers (Beginner · Elementary · Intermediate · Upper-intermediate · Advanced · Not sure), plus
  typing or speech.
- **Main part**, every time: one of the 3 questions, chosen at random. A question isn't repeated
  until all 3 have been asked (bag rotation):
  - "What sounds good today: something useful, a little mystery, or a friendly argument?" (today
    only, not saved)
  - "What would you love to be able to do comfortably in English?" → profile: goal
  - "What do you spend most of your day doing: working, studying, or something else?" → profile:
    daily context
- **Special question: grammar focus** (owner, 2026-10-31), every 5th warm-up (a counter in
  prefs): "Would you like to focus on a grammar rule in this talk?" The tap answers are 4 rules
  that fit the profile's level, from a fixed list of about 15 (e.g. Intermediate: Present Perfect,
  Past Continuous, First conditional, Comparatives), plus "No, just talk". The picked rule goes
  with the talk start (W6) and holds for this talk only.
- Lines: the questions are fixed (written in the app). After each answer, the AI adds one short
  friendly reaction (a cheap model call). If that call fails or is slow, a fixed line is used, so
  the warm-up never waits.
- Then the topic step (3 topics + own topic, ranked with the profile, W3) and the existing
  Hard/Easy step. Both stay.
- AC: notifier tests for intro only on the first run, the bag rotation, and the special question
  on the 5th run; a widget test that each part can be answered by a tap.

### W3. Topics from words + profile (Worker `/learn/topics`, S)
- The request adds the profile and today's answer. The model ranks the revised topics by word fit
  first, then the profile. The profile never forces the words into the learner's job. The level
  sets how simple the topic description is.
- Still 3 topics + "Propose my own topic". The 4 s timeout and the bundled fallback stay.
- AC: Worker tests: the profile is accepted and optional; the fallback is unchanged.

### W4. Revised catalog (Worker `topics.ts`, S)
- 38 kept, 6 merged pairs (at-the-doctor + pharmacy, nature + camping, money + budgeting,
  gadgets + computer problems, sport + watching a match, school + university), 6 new
  (meeting-new-people, meetings-and-ideas, customer-service, online-shopping, making-plans,
  favours-and-boundaries), the inclusive titles, and a `group` and a `hook` on `LearnTopic`.
- The old ids of the merged topics map to the merged id through aliases. The first three ids stay
  first (the app's bundled fallback).
- Safety notes: healthcare = describing and clarifying; emergency = clearly fictional; news =
  fictional.
- AC: 50 unique ids, aliases resolve, every topic has a group and a hook.

### W5. Counters + 👍/👎 (Worker log + results page, S, look change)
- Counts without content: warm-up part shown / answered / skipped, topic chosen vs own topic,
  talk finished vs ended early, "Talk with AI" tapped again on results.
- After every 3rd finished talk: "Was this talk interesting? 👍 / 👎" on the results page.
- AC: the counters appear in `logEvent` with no words or messages.

### W6. Grammar focus in the talk (Worker talk prompt + app results, M)
- When the talk start carries a grammar rule, the mission plan and the AI's lines steer toward it.
  Some speaking tasks need the rule; the target-word rule (D1) stays.
- Gentle fix: when the learner uses the rule wrongly, the AI's next line repeats their idea in
  the correct form, with no interruption and no correction note.
- The Worker returns, per learner line, whether the rule was used and whether it was right. The
  results page shows "Present Perfect: used 4 times, 3 right".
- The fixed list of ~15 rules, each with a CEFR level, lives in the Worker, next to the topics.
  The app keeps a bundled copy for the warm-up question.
- AC: Worker tests for the rule in the start request and the per-line grammar field; a notifier
  test for the count on the results page.

## Order

```
W4 → W3
W1 → W2 → (W3 uses the profile)
W2 → W6
W5 any time
```

## Owner answers (2026-10-31)

- Warm-up lines: fixed questions; the AI only adds a short reaction to each answer.
- Special question = grammar focus: 4 rules by level + "No, just talk", every 5th warm-up.
- In the talk: the AI steers toward the rule + gentle fix; the results page counts right uses.
- After the warm-up: the topic pick (3 + own) and Hard/Easy both stay.
