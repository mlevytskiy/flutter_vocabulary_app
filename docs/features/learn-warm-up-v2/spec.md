---
status: Reviewed
owner: "Maksym (learner, app owner); questions answered by a Fable 5.1 owner proxy, 2026-10-31"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-31"
feature_size: "M"
---

# Spec — learn-warm-up-v2

> **Glossary:** [CONTEXT](../../../CONTEXT.md) (warm-up, learner profile, grammar focus added 2026-10-31) ·
> **Brief:** [improvements.md](./improvements.md) (the owner's two AI conversations, decisions D1–D7, answers) ·
> **Decision page:** https://claude.ai/artifact/XwqcVzbPfNoMzHnjsNVBAS · **Changes:** [learn-welcome](../learn-welcome/spec.md)
> AC-02, AC-03, AC-04 (label), AC-13, AC-15, AC-16 (profile answers stay on leave), NFR-03 (reaction calls added) and
> owner pick A20 "always ask both fresh" · **Keeps:** [talk-mixed](../talk-mixed/spec.md) as it is,
> apart from the grammar focus.

## 1. Context

Today the Learn flow's warm-up asks the same two things every time: which of three topics to talk about, and Hard or
Easy. The topics are matched to the words only, so the learner is offered "Grocery shopping" whatever they do or want
from English. The topic titles also say little about what will happen. The owner wants the warm-up to feel like a
short, friendly conversation that gets to know the learner over time, and topics that fit both the words and the
person.

Why now: the owner reviewed the talk in two AI design conversations (24 and 31 October 2026) and the decision page
above. He kept the talk mission as it is (speaking tasks need the target word, the mic starts at once, Easy ≤ 6 and
Hard ≤ 12 words) and chose to change the warm-up, collect a small learner profile, revise the 50 topics, offer a
grammar focus from time to time, and start measuring.

Committed approach: the warm-up becomes a dialog in up to three parts. An **intro** asks the English level the first
time. A **main question** comes every time, one of three in rotation. A **grammar question** comes on every 5th
finished warm-up. The questions are fixed, and the AI adds one short reaction to each answer. The answers fill a
**learner profile** kept on the phone and used only for picking topics. Topics come from a revised catalog of 50,
ranked by the words first. A chosen grammar focus steers that one main dialog and gets its own line on the results
page. Plain counts and an occasional 👍/👎 show whether it works.

Inputs: the owner's research note "Personalised English conversation topics" (31 Oct, British Council / Cambridge /
CEFR sources) stands in for the competitive research. A failure-mode review (devil's advocate, 31 Oct) produced
guards G1–G9, which the owner proxy accepted. They are in §5, §6.1 and §8.

Approved visible changes (owner D4, D5, D7 and W6 on 31 Oct 2026; details by the owner proxy): the warm-up as a
dialog with a step bar, the learner profile section in Learn settings, the grammar line on the results page, and the
👍/👎 question on the results page. They are recorded in `docs/approved-changes.md` when built.

Decision (orchestrator, 31 Oct, from D1 + G6): the grammar focus is *invited*, never *required*. The AI's questions
and speaking prompts are phrased so the rule fits the answer naturally. A speaking task still needs only its target
word (D1), so the rule never makes a task harder to pass. This replaces the brief's W6 line "some speaking tasks need
the rule"; do not restore it (owner proxy O3).

## 2. Goals

- The warm-up feels like a short conversation with someone who remembers the learner, not a form asked fresh every
  time.
- The offered topics fit the learner as well as the words, without turning every talk into a work talk.
- A learner who wants grammar practice can get it inside the talk they already do.
- The owner can see whether learners finish the warm-up and like the talks.

## 3. Non-goals

- Changing the talk mission's turns, words or microphone. The owner kept D1–D3.
- Continuing earlier conversations or keeping a talk history. The profile only picks topics (owner, D5).
- Grammar lessons or exercises outside the talk. The grammar focus lives only in the main dialog.
- Dashboards. The counts are read from the server log for now.

## 4. User stories

### US-01: Tell the app my level once
**As a** learner
**I want** the first warm-up to ask my English level
**So that** topics and grammar choices fit me from then on

### US-02: Answer one friendly question each time
**As a** learner
**I want** one short question per warm-up that changes from time to time, with a reaction to my answer
**So that** starting Learn feels like a conversation, not a form

### US-03: Practise a grammar rule in the talk
**As a** learner
**I want** to be offered a grammar rule to focus on now and then, and to see how I used it
**So that** I practise grammar inside the talk I already do

### US-04: See and change what the app knows
**As a** learner
**I want** to see, change and clear my learner profile
**So that** I stay in control of what is kept about me

### US-05: Get topics that fit my words and me
**As a** learner
**I want** the three offered topics to fit my words and, a little, my profile and mood
**So that** the talk is useful and interesting

### US-06: Choose from clearer, wider topics
**As a** learner
**I want** topics in clear groups that also include practical situations (meeting people, customers, deliveries, plans)
**So that** I can be different people in the talks, not always a customer

### US-07: Say whether a talk was interesting
**As a** learner
**I want** to say now and then whether the talk was interesting
**So that** future talks get better

## 5. Acceptance criteria

### AC-01 (US-01) — happy
**Given** a learner whose learner profile has no English level
**When** they open Learn on a collection with enough words
**Then** the warm-up starts with "What's your English level?" and the taps Beginner · Elementary · Intermediate ·
Upper-intermediate · Advanced · Not sure. A tap saves the level, the AI reacts in one short line, and the main
question follows.

### AC-02 (US-01) — domain invariant
**Given** a learner whose learner profile has a level (including "Not sure")
**When** they open Learn again
**Then** the intro is not asked. Only Learn settings can change the level. The intro and the grammar question never
come in the same warm-up: when both are due, the grammar question waits for the next warm-up.

### AC-03 (US-02) — happy
**Given** a learner in a warm-up
**When** the main question comes
**Then** it is one of: "What sounds good today: something useful, a little mystery, or a friendly argument?",
"What would you love to be able to do comfortably in English?", "What do you spend most of your day doing: working,
studying, or something else?". Their taps: Something useful · A little mystery · A friendly argument · Surprise
me; Speak at work · Travel confidently · Make friends · Enjoy films and series · Study in English · Everyday
conversations · Something else; Working · Studying · Working and studying · Family or home · Something else. "Something
else" opens the learner's own words; it is the only way to answer in own words (the intro and the grammar question are
taps only). The three come in a random order inside each round of three, and none comes again until all three have
been answered. Clearing the profile doesn't restart the round. A
question counts as asked only when it was answered; one the learner left stays first for next time.

### AC-04 (US-02) — error
**Given** a learner answering the goal or daily-context question in their own words ("Something else"), typed or
spoken
**When** the text, trimmed, is empty or longer than 80 characters
**Then** Send stays disabled, and over 80 characters the field says "Keep it under 80 characters" (spoken text the
same as typed). A 1–2 character answer gets a reaction but is saved only into an empty profile field; it never replaces
an answer already there.

### AC-05 (US-02) — happy
**Given** a learner who just answered the intro, the main question or the grammar question
**When** the answer is sent
**Then** the AI adds one friendly line of at most 15 words. If it hasn't arrived within 2 seconds, a fixed line shows
instead. The fixed line also shows when the call fails or the reply fails the check (one sentence, at most 15 words,
no link, and not repeating the learner's answer), and a later reply is dropped. The next step shows right after the
reaction or the fixed line. The fixed lines, picked at random: "Got it, thanks!", "Nice, good to know.", "Great,
let's go on.", "Thanks, that helps!", "Sounds good!", "Cool, thanks for sharing." The topic and Hard/Easy steps get no reaction. Reactions never count toward
the daily talks.

### AC-06 (US-02) — domain invariant
**Given** a learner in any warm-up
**When** it shows
**Then** one bar on top counts every step shown this time (3 or 4). The gear to Learn settings stays. There is no
Skip. The mood answer is used only
for this warm-up's topics and is never saved. The goal and daily-context answers (tap or own text) are saved to the
learner profile when given, and stay there if the learner leaves later. Back uses the existing leave dialog. A
warm-up counts as finished only when the cards open.

### AC-07 (US-03) — happy
**Given** a learner with a level whose grammar counter is 4 or more (the counter goes up by one each time a warm-up
finishes and goes back to 0 only when the grammar question is answered; leaving at the grammar step keeps it due)
**When** the warm-up reaches its special part
**Then** it asks "Would you like to focus on a grammar rule in this talk?" with 4 rules of the level's list, picked at random (Beginner uses the Elementary rules; "Not sure" uses the
Elementary and Intermediate rules) and "No, just talk". The chosen rule holds for this flow's main
dialog only.

### AC-08 (US-03) — cross-context
**Given** a learner whose daily talk limit is already reached
**When** the grammar question would be due
**Then** it is not asked (the main dialog will be skipped anyway) and comes on the next warm-up instead.

### AC-09 (US-03) — happy
**Given** a main dialog with a grammar focus
**When** the talk runs
**Then** the AI's questions and speaking prompts are phrased so the rule fits the learner's answer. A speaking task
still needs only its target word; the rule is invited, never required. When the learner uses the rule wrongly, the AI's next line repeats their idea in the correct form
without stopping the talk. When the line was right, no such repeat happens.

### AC-10 (US-03) — cross-context
**Given** a finished or ended main dialog with a grammar focus
**When** the results page shows
**Then** the Talk part has a line like "Present Perfect: used 4 times, 3 right". Each AI reply judges the learner's
line it answers as right, wrong or unsure, with no extra AI call; only right and wrong are counted. The line is hidden when no line was judged. The grammar line never changes a Leitner box or a word's
dialog result.

### AC-11 (US-04) — happy
**Given** a learner in Learn settings
**When** they open the learner profile
**Then** they see the level, goal and daily context (or "Not set"). They can change or clear each one, under the note
"Used only to pick talk topics". A cleared level brings the intro back on the next warm-up.

### AC-12 (US-04) — authorization
**Given** a learner with a learner profile
**When** they share a collection, a partner opens its shared page, or the server records counts
**Then** the profile never appears. The saved profile and this warm-up's answers leave the phone only in the topic
pick and, for each answer, its one reaction call (no retries); nowhere else. The chosen grammar rule's name, a value
from the app's fixed list, goes with the main dialog (amended in design, 2026-10-31). No answer or profile text is ever
written to logs.

### AC-13 (US-05) — happy
**Given** a learner at the topic step
**When** the topics arrive
**Then** they see 3 topics and "My own topic…". The words decide the ranking. At most 1 of the 3 is there
because of the profile, and that one can only take the third place. Each topic shows its title and a one-line
situation of at most 20 words, written for this learner in the mood they chose ("Surprise me": any mood) and in
English as simple as their level; when no line comes, the topic's example situation from the catalog shows. The topic
pick starts when the main question is answered, and the 4 seconds count from reaching the topic step. On a failure or
no answer in time, the 3 bundled topics show as today. The own-topic button keeps today's
label "My own topic…".

### AC-14 (US-06) — happy
**Given** the revised catalog
**When** topics are offered
**Then** they come from 50 topics in groups (Everyday life, People, Work and study, Travel and transport, Places and
nature, Leisure and ideas, Technology and services, Health and getting help). Each topic has an example situation,
including the six new ones (Meeting new people, Meetings and presenting ideas, Helping customers, Online shopping
and deliveries, Invitations and making plans, Favours and polite boundaries).

### AC-15 (US-06) — cross-context
**Given** a learner on an older app version that still knows a merged-away topic (At the pharmacy, Camping trip,
Saving and budgeting, Computer problems, Watching a match, University life)
**When** their talk starts on that topic
**Then** the talk runs on the merged topic, and nothing breaks for that learner. The old topics are accepted with no
end date.

### AC-16 (US-07) — happy
**Given** a learner reaching the results page after a main dialog, finished or ended early
**When** it is their 3rd, 6th, 9th… such talk
**Then** the page asks "Was this talk interesting?" with 👍 and 👎. One tap records the answer, and the question
goes away.

### AC-17 (US-07) — domain invariant
**Given** any warm-up or talk
**When** the server records counts (warm-up part shown / answered / left, with the grammar answer as "rule" or "none", topic picked or own topic, talk finished
or ended early, another talk started from the results, 👍/👎)
**Then** each count carries only fixed values and numbers, never words, answers, topic text or messages.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| AI reaction wait | ≤ 2 s, then the fixed line | widget test with a slow fake; server log latency p95 |
| Topic pick wait | ≤ 4 s, then the bundled 3 (unchanged) | existing test; server log |
| Extra AI calls per Learn | ≤ 2 cheap reaction calls + 1 topic pick | server log count per Learn |
| Warm-up steps | 3 or 4 | widget tests per case |
| Content in counts | 0 free-text fields | server test that rejects free strings in count events |

## 6.1 Security / privacy

- **Data classification:** confidential. The learner profile can hold the learner's own words about their job and
  goals.
- **Personal data touched:** new on the device: English level (fixed list), goal (fixed list or text ≤ 80), daily
  context (fixed list or text ≤ 80), counters (numbers). Sent to the AI provider: the profile with the topic pick;
  each answer once for its reaction; the chosen grammar rule's name (fixed list) with the main dialog.
- **AuthZ/AuthN impact:** none new. The app has no accounts. The existing app secret guards the server calls.
- **Abuse cases:**
  - Profile leak through sharing: the profile is never part of a collection or a shared page (AC-12).
  - Leak through logs: no request body, answer or profile text is logged; count events carry fixed values only
    (AC-17).
  - Prompt injection in an own answer ("ignore your instructions…"): the reaction prompt treats answers as data, and
    the reaction is at most 15 words. A reaction that fails the check falls back to the fixed line.
  - Spam: reactions and the topic pick don't count toward the daily talks but are bounded by the number of warm-up
    steps (≤ 2 reactions per Learn).
- **Visible changes:** the four listed in §1, recorded in `docs/approved-changes.md` when built.
- **Security review:** Required. New personal data goes to an AI provider.

## 7. Metrics / KPIs

- **Warm-ups that reach the cards** — baseline: not measured, target: ≥ 80% within 30 days of release.
- **👍 share of 👍/👎 answers** — baseline: none, target: ≥ 60% within 30 days.
- **Grammar offer accepted** (a rule, not "No, just talk") — baseline: none, target: ≥ 30% within 30 days.
- **Own-topic and leave-at-topic rates** — baseline: none. Counted with no target until a baseline exists.

## 8. Open questions

- [x] The grammar list — resolved by the owner proxy (O1): accepted as below. Elementary: Present Simple, Present
  Continuous, Past Simple, Comparatives, There is/are; Intermediate: Present Perfect, Past Continuous,
  Going to / will, First conditional, Modal verbs for advice; Upper-intermediate/Advanced: Second conditional,
  Passive voice, Reported speech, Present Perfect Continuous, Third conditional. Beginner uses Elementary.
- [x] The fixed reaction lines — resolved by the owner proxy (O2): the six lines in AC-05.
- [ ] Where the owner reads the counts? Default now: the server log via the existing log search. — owner: owner,
  due: after release

## Clarifications (2026-10-31)

Ambiguity sweep (devil's advocate, mode A) resolved in place: AC-12 (where answers go), AC-13 (situation lines,
profile slot, when the pick starts), AC-10 (per-line verdict, no extra call), AC-07 (grammar counter), AC-04 (own
words only via "Something else", trimming, short answers), AC-05 (the reaction check and pacing), AC-03 (random order
in rounds of three). Owner proxy O1–O4: grammar list and fixed lines accepted; "invited, not required" accepted; route
skips: data-model, api (described in the design doc), screens and a separate sequences pass are skipped.

## Test plan

Inline (owner proxy O4). Levels: **unit** = pure Dart or pure TypeScript; **widget** = Flutter widget test with fakes;
**worker** = Node test of a Worker call through the local AI stub (`vocab-photo-api/test/*.test.mjs`); **device** = the
owner's manual check. Data: fake profile store, fake reaction/topics/events services, fake clock and seeded random;
no live AI in tests.

| AC | Test level | What the test proves |
|---|---|---|
| AC-01 | unit + widget | No level → plan starts with the intro; a tap saves the level; reaction then main question |
| AC-02 | unit | Level set (incl. Not sure) → no intro; intro and grammar never in one plan; grammar moves to the next warm-up |
| AC-03 | unit | Random order inside rounds of three; an unanswered question stays first; clearing the profile keeps the round |
| AC-04 | unit + widget | Send disabled for empty or > 80 (typed and spoken); 1–2 chars saved only into an empty field |
| AC-05 | unit + widget + worker | 2 s cutoff → fixed line, late reply dropped; the server check rejects long, linked or echoing replies; never counted |
| AC-06 | widget | Bar shows 3 or 4 steps; gear present; no Skip; mood not saved; answers kept after leaving |
| AC-07 | unit | Counter rule: +1 per finished warm-up, 0 after an answered grammar question → every 5th; 4 rules of the level; Beginner and Not sure mapping |
| AC-08 | unit | Talk limit reached → no grammar step, still due next time |
| AC-09 | worker | With a rule, start and reply prompts invite it and add the gentle fix only after a wrong verdict; tasks still need the target word |
| AC-10 | unit + widget | Counts right/wrong only; line hidden with no judged line; boxes and word results unchanged |
| AC-11 | widget | Profile section shows, changes and clears each field; cleared level → intro next time |
| AC-12 | unit + worker | Profile only in the topics request; one reaction request per answer, no retry; talk carries only the rule name; no body in logs |
| AC-13 | worker + unit | Slot 3 only for a profile topic (code); situation lines checked, hook fallback; pick starts after the main answer; 4 s from the topic step |
| AC-14 | worker | 50 unique ids, 8 groups, a hook each, the six new topics present, first three unchanged |
| AC-15 | worker | Each of the 6 old ids resolves to its merged topic; a test pins the alias map |
| AC-16 | unit + widget | 👍/👎 on the 3rd, 6th… talk reaching results, finished or ended; one tap records and hides |
| AC-17 | worker + unit | Events accept fixed names and values only; a free string is rejected; leave, finish and results send events |
| §6 NFRs | unit | ≤ 2 reaction calls + 1 topic pick per Learn; 3 or 4 steps |
| Device | device | Warm-up feel, speech in "Something else", grammar talk on a real model, settings section |
