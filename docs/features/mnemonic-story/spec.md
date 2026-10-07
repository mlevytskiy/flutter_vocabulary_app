---
status: Draft
owner: "Maksym"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-07"
feature_size: "M"
---

# Spec — mnemonic-story

> **Glossary:** [CONTEXT](./CONTEXT.md) · [learn-part-step-1 CONTEXT](../learn-part-step-1/CONTEXT.md) · repo-root [CONTEXT](../../../CONTEXT.md)
> **Reference module / docs / channels used:** None beyond the interview, the three CONTEXT files, [`learn-part-step-1/spec.md`](../learn-part-step-1/spec.md), [`docs/roadmap.md`](../../roadmap.md), [`docs/architecture.md`](../../architecture.md) and the owner's sample story (quoted in ¶4).

## 1. Context

Learn-part-step-1 built the way in: a Learn button, a learn page with eleven exercises, and Mnemonic story as the only one that can be ticked. Start still opens a coming-soon screen. The learner has no exercise yet. The owner wants the first real one: a mnemonic story with a picture, made by AI from the session's words. The owner also wants to find out which AIs make the best stories for the money. In the owner's words: "I want to use different AI to create mnemonic story and image from this story … I wanna check different AI Agent and evaluate who is better for making that mnemonic story. So I need one additional screen with full information about their work: price, time, results."

Why now: the learn page and its Start button exist and point at a placeholder. The owner has a sample story that shows the format works for them. A long session (more than 19 words) cannot become one readable story, so the words have to be split into groups first.

Committed approach: the session's words to learn are split into word groups of 7 to 19 (ideally 10 to 15), by topic, only when there are more than 19; a session with 19 words or fewer is one word group of any size. A fixed AI on the server does the grouping and names the groups. A pager at the top of the learn page lets the learner select one group. Each group gets one mnemonic story with one picture, made by three AIs in turn: the story writer, the picture prompt writer and the picture maker. The story and picture are kept for the group and made again only when the learner asks. The three AIs are chosen on a new settings screen opened from the Words screen, with a price next to each. A story-runs screen shows every run with each AI's result, price and time, so the owner can compare them. Everything happens in the app only. Nothing reachable from a shared link can spend money on AI, and a daily story allowance caps what the whole app can spend. This is grounded in three findings. Research (2026-10-07) found no product that turns a topical group of the user's own 10–15 words into one connected story with a picture, and none that shows each AI's result, price and time side by side. Existing tools work per word or per card, or write a plain story without a picture. The sharpest failure found is a paid three-AI chain behind an app secret that anyone who unpacks the app can read; the story allowance answers it. The owner's success criterion is choosing the best three AIs from real numbers.

- Owner's sample (Russian and English; ours is Ukrainian and English): "Вы tackle огромную проблему-монстра → карабкаетесь вверх, чтобы live up to планки ожиданий → цепляетесь за неё как tenacious осьминог → ваш determined компас всё равно показывает вперёд → in a pinch вы используете запасную лестницу → наверху сидит one-finger typer и одним пальцем стучит по клавиатуре → spell check подчёркивает его ошибку красным → он пугается и veers off с дороги → встречает очень chatty рекрутера → и сообщает ему, что willing to relocate, показывая уже собранный чемодан."
- Learn-part-step-1's invariant "the learn page saves nothing" is narrowed by owner decision (2026-10-07): ticks still last one visit, but word groups, mnemonic stories and story runs are kept. This needs new domain models (word group, mnemonic story, story run); choosing to keep stories is the owner's approval under CLAUDE.md rule 5, to be recorded there at `design`.
- New visible parts approved under CLAUDE.md rule 3 by this spec: a settings button on the Words screen, the Words settings screen, the story-runs screen with a run's details screen, the group pager on the learn page, the story screen that replaces the coming-soon screen for Mnemonic story in the app, and a confirmation before making a new story.
- The web learn page does not change: Mnemonic story there still leads to the coming-soon screen (owner decision 2026-10-07).
- Assumption (owner, 2026-10-07): story runs are never removed and take no more than 3 MB each, so their storage is not capped. Real use is a few runs a week, about 100 MB a year. Revisit if the story runs list grows large.

## 2. Goals

- A learner with any number of words can study them as mnemonic stories, one readable story with a picture per word group.
- The owner can tell which AIs make the best story for the money, from the app's own record of real runs.
- AI spending stays bounded and visible: nothing is paid twice for the same group without a request, and a leaked app secret cannot run up the bills.

## 3. Non-goals

- **Mnemonic story on the web:** the partner keeps the coming-soon screen. Showing stories on the shared page is a later roadmap step; generating from the web is out, because a link is the only credential.
- **Grading stories automatically for quality:** beyond checking that every word appears, quality is judged by the owner on the story-runs screen. An AI judge would add cost before there is data to tune it.
- **Other exercises and learning progress:** the other ten exercises stay coming soon; no scores or "memorized" marks are kept, as in learn-part-step-1.
- **Showing the cost of grouping:** the grouping AI is fixed on the server and cheap; its cost is not recorded or shown. Only story runs are compared.
- **Exact billing:** prices shown are the app's own estimate or record per run, not a copy of the providers' invoices.

## 4. User stories

### US-01: Select a word group to learn

**As a** learner
**I want** my session's words split into named groups and to select one on the learn page
**So that** each story covers a manageable set of related words

### US-02: Read the mnemonic story with its picture

**As a** learner
**I want** to press Start and see the selected group's story with its picture
**So that** I can remember the words through one connected scene

### US-03: Choose the AIs that make stories

**As a** learner
**I want** to choose the story writer, the picture prompt writer and the picture maker, seeing a price next to each
**So that** I control what makes my stories and what it costs

### US-04: Compare story runs

**As a** learner
**I want** a list of all story runs with each AI's result, price and time
**So that** I can tell which AIs are worth using

### US-05: Make a story again

**As a** learner
**I want** to ask for a new story for a group, and be told when a story no longer matches its words
**So that** I can try other AIs or fix a story after editing words

### US-06: Keep AI spending bounded

**As a** learner
**I want** story runs limited per day and impossible to start from a shared link
**So that** nobody can run up my AI bills

## 5. Acceptance criteria

"Word to learn" is as defined in learn-part-step-1: a word row with an English word plus a translation or a definition.

### AC-01 (US-01) — happy path

**Given** a learner opens the learn page of a session with more than 19 words to learn, and its words are grouped
**When** the learner looks at the top of the page
**Then** the page shows the line "We grouped your words into sets of up to 19 words. Please select one group to learn." above a pager with one card per word group, each showing the group's name and its words. The group selected last time in this session is selected again, or the first group if none was selected or that group is gone. Tapping another group's card selects it and unselects the previous one; swiping the pager only browses. Exactly one group is selected at a time.

### AC-02 (US-01) — happy path

**Given** a learner opens the learn page of a session with 19 words to learn or fewer, none of them in a group with a mnemonic story
**When** the learner looks at the page
**Then** no group line and no group pager are shown, and the story is made from all the session's words to learn as one word group named "All words", whatever its size. The 7-to-19 rule applies only when a session has more than 19 words to learn.

### AC-02b (US-01) — domain invariant

**Given** a session has 19 words to learn or fewer, its group has a mnemonic story, and the learner adds words so that the session still has 19 or fewer
**When** the session is grouped again
**Then** the added words form their own word group of any size, with its own card on the group pager and its own story. The group with a story keeps its words.

### AC-03 (US-01) — cross-context

**Given** a session (the current one or one opened from History) has more than 19 words to learn, and its words to learn changed since it was last grouped
**When** the learner opens its Words screen or its learn page
**Then** grouping starts, without any message on the Words screen. If the learn page is open before grouping finishes, the group pager shows "Grouping your words…" and fills in when it finishes. The words to learn have changed when an English word was added, deleted or edited, or a row became or stopped being a word to learn. Editing only a translation or a definition is not a change. Opening either screen again with no change does not group the words again.

### AC-04 (US-01) — error

**Given** grouping did not produce valid groups (it failed, left a word out, put a word in two groups, or, for a session with more than 19 words to learn, made a group outside 7 to 19 words)
**When** the learner opens the learn page
**Then** no such groups are shown. The page says "Could not group your words" with a "Try again" button, and Start stays unavailable for Mnemonic story until grouping succeeds.

### AC-05 (US-01) — domain invariant

**Given** a session's groups include a group with a mnemonic story, and the learner adds words so that fewer than 7 words are outside every group with a story
**When** the session is grouped again
**Then** those words join a group without a story if one exists and stays within 19 words. Otherwise they wait, and the learn page shows "N more words are waiting for a group (at least 7 are needed)", because a word group holds 7 to 19 words. Groups without a story keep their words, name and selection; new words are only added to them. A group whose story run is in progress counts as a group with a story, so its words do not change during the run.

### AC-06 (US-02) — happy path

**Given** a learner opens the learn page and the selected group has no mnemonic story yet
**When** the page opens, or the learner selects (taps) a group without a story
**Then** a story run for that group starts in the background with the current AI choice, without waiting for Start. A run already going for another group carries on; several runs can be going at once, and each counts against the story allowance (AC-19). When the learner ticks Mnemonic story and presses Start, the story screen opens. While the run is going, it shows which step is running ("Writing the story…", "Writing the picture prompt…", "Drawing the picture…"). When the run finishes, it shows the picture at the top and the story text under it. The learner can zoom into the picture and pan around it.

### AC-07 (US-02) — domain invariant

**Given** a word group already has a mnemonic story
**When** the learner opens the learn page again, selects that group or opens its story screen, in this visit or after restarting the app
**Then** the same story and picture are shown and no new story run starts, because a mnemonic story is made again only when the learner asks

### AC-08 (US-02) — error

**Given** a story run's story is missing a word of its group as written (left out, put in another form, or translated)
**When** the story writer's step finishes
**Then** the picture is not drawn. The story screen says "The story missed these words: …", lists them, and offers "Try again", which starts a new story run. The run appears in the story runs as failed at the story step, with that step's price and time.

A word counts as present when it appears as a whole word, in any letter case. A phrase counts when its words appear in order, next to each other. Each English word may carry the ending -s, -es, -ed or -ing ("veers off" counts for "veer off"). A word inside another word ("live" in "deliver") does not count, and neither does any other form or a translation.

### AC-08b (US-02) — error

**Given** a story run is in progress
**When** the story writer or the picture prompt writer fails, refuses, or gives no answer within 90 seconds (the picture maker: within 120 seconds)
**Then** the run is marked failed at that step, with the step's price and time. If the story writer failed, the story screen says "Could not write the story" and "Try again" starts a new story run. If the picture prompt writer failed, it says "Could not write the picture prompt" and "Try again" redoes only that step in the same run, from the same story. A picture maker that fails or gives no answer in time is handled as in AC-09.

### AC-09 (US-02) — error

**Given** a story run wrote the story and the picture prompt, but the picture could not be drawn (the picture maker refused or failed)
**When** the learner opens the story screen
**Then** the story text is shown with "The picture could not be drawn" and a "Draw again" button. "Draw again" redoes only the picture in the same story run, from the same picture prompt and with the picture maker chosen now, without writing the story again. The failed attempt stays on that run as a failed attempt, with its picture maker, price and time.

### AC-10 (US-02) — error

**Given** a story run is in progress and the learner leaves the learn page, locks the phone or closes the app
**When** the learner comes back to the learn page or the story screen for that group
**Then** the steps already finished are kept and the run carries on from the next step. No finished step is redone or paid again. A step that was in progress when the learner left is not paid again either: its result is collected when the learner comes back.

### AC-11 (US-01) — cross-context

**Given** a learner opens the learn page from an older History session that is not the current session
**When** grouping and story runs happen for it
**Then** they use and keep that History session's words, groups and stories, and the current session is not changed

### AC-12 (US-03) — happy path

**Given** a learner is on the Words screen
**When** the learner taps the settings button, which looks like the main screen's settings button, and opens Words settings
**Then** Words settings show three choices, each a list of the AIs on the app's offered list, a fixed list kept on the server: the story writer and the picture prompt writer (Anthropic Sonnet 5.5, Anthropic Opus 5.5 and the OpenCode Zen models put on the list), and the picture maker (the Grok and Higgsfield picture models put on the list). Each story writer and picture prompt writer option shows a price per story: "≈ $X (estimate)" until it has run, worked out from the provider's list price for a group of 15 words, then "$X average · N runs". The average and N count only the learner's runs where that AI finished that step, kept separately for the story writer and the picture prompt writer. Each picture maker option shows its fixed price per picture. The choice is kept after the app restarts and is used by every new story run.

*Owner-requested addition (2026-10-07, T18): each option list runs from the cheapest to the most expensive, and each option also shows a small line with the provider's list price (for example "List price: $0.30 in · $1.20 out per 1M tokens" or "List price: $0.02 per picture", with "≈" when the price is approximate), under the label above.*

### AC-13 (US-03) — cross-context

**Given** the AI chosen for one of the three steps is no longer offered (it was taken off the app's offered list, or its provider stopped serving it)
**When** the learner opens Words settings or a story run is about to start
**Then** Words settings show "<AI name> is no longer available" and that step falls back to the default AI for it. No story run starts with an AI that is not offered.

### AC-14 (US-04) — happy path

**Given** at least one story run has happened
**When** the learner taps "Story runs" in Words settings
**Then** a list of all story runs opens, newest first. Each shows the group's name, the date, the three AIs, the total price and total time (the sum of the step times, so pauses such as a closed app do not count), and whether it finished or where it stopped. Tapping a run shows the story writer's name and the story, the picture prompt writer's name and the prompt, the picture maker's name and the picture, and the price and time of each step.

### AC-15 (US-04) — domain invariant

**Given** a story run stopped at a step, or was replaced by a newer story for the same group
**When** the learner opens the story runs
**Then** that run is still listed with the results, prices and times of the steps it finished, because story runs are a record for comparing AIs and are never removed by a newer story

### AC-16 (US-05) — happy path

**Given** the learner is on the story screen of a group with a mnemonic story
**When** the learner presses "Make a new story" and confirms
**Then** a new story run starts with the current AI choice. The old story and picture stay shown while it runs. Only when it finishes with a picture do its story and picture replace the group's story. If it fails, the old story stays, with "The new story could not be made" and "Try again". The earlier run stays in the story runs either way.

### AC-17 (US-05) — cross-context

**Given** a word group has a mnemonic story, and the learner deletes one of its words, edits its English word, or makes it stop being a word to learn on the Words screen
**When** the learner opens that group's story
**Then** the story is still shown, marked "Words changed", with "Make a new story". Nothing is made again on its own. The group's card shows its current words: a deleted word is gone, an edited word shows its new form. "Make a new story" uses the current words, even if fewer than 7 are left. Editing only a translation or a definition does not mark the story.

### AC-18 (US-06) — authorization

**Given** a partner opens the web learn page of a shared session, or anyone tries to start a story run without the learner's app
**When** they tick Mnemonic story and press Start, or try to start a run any other way
**Then** the web learn page leads to the same coming-soon screen as before, and no story run starts, because only the learner's app may spend money on AI

### AC-19 (US-06) — domain invariant

**Given** the story allowance for the day (20 story runs for the whole app, per UTC day) is used up
**When** a story run would start (on opening the learn page, selecting a group, "Try again", "Draw again" or "Make a new story")
**Then** no run starts and nothing is paid. The story screen and the learn page say "Today's story limit is reached. Try again tomorrow." Each new story run takes one from the allowance when its story step starts, and each "Draw again" takes one. A step that carries on after the learner comes back (AC-10), and redoing the picture prompt (AC-08b), take none. A picture prompt or picture step that does not belong to a counted run is refused.

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Grouping time | ≤ 30 s for a 60-word session | 5 runs on the owner's phone at release |
| Story run time | ≤ 3 min from start to the picture shown, with the default AI choice | the total times (sum of step times) on the story runs screen, median of the first 10 runs |
| Saved story open time | ≤ 500 ms from Start to the picture and text shown | 5 runs on the owner's phone at release |
| Story allowance | ≤ 20 story runs started per UTC day across the whole app | server-side count, one unit per run start or "Draw again" (AC-19); a test that the 21st of a day is refused |
| Price accuracy | the month's sum of run prices within ±25 % of the providers' invoices | owner compares the story runs total with the invoices after the first month |
| Picture zoom | zoom up to at least 4× with pan, no visible blur at 2× on the owner's phone | device check at release |
| Storage | ≤ 3 MB on the device per story run (picture included) | check app storage after 10 runs |

## 6.1 Security / privacy

- **Data classification:** internal. Stories, pictures and run records stay on the learner's device; the session's words go to the chosen AI providers, as photo words already go to an AI today.
- **Personal data touched:** none new. Words to learn are sent to third-party AI providers. They are vocabulary, not personal data, but the learner should know they leave the device, as with photo extraction today.
- **AuthZ/AuthN impact:** story runs and grouping can be started only by the learner's app, through the same app secret as photo extraction. The web learn page gains no way to start them (AC-18). A daily story allowance for the whole app caps spending (AC-19), and the server accepts only AIs from its own list of offered models, so a caller cannot pick an unlisted, more expensive one.
- **Abuse cases:**
  - Leaked app secret used to run paid chains: capped by the story allowance; the server refuses AIs not on its list and refuses a picture prompt or picture step that does not belong to a counted run.
  - Shared-link holder tries to generate: no way exists from the web (AC-18).
  - Grouping calls spammed: grouping runs only when the session's words changed (AC-03) and is limited by the same address rate limit as other app calls; it does not count against the story allowance.
  - Unwanted or unsafe pictures from words such as those found in film subtitles: the picture maker may refuse, which is handled as a failed picture (AC-09); the story is still shown.
- **Security review:** Required. A new paid server capability is reached with a secret that ships in the app.

## 7. Metrics / KPIs

- **AI choices compared:** baseline 0, target story runs with ≥ 3 different AI choices within 14 days of release.
- **Stories learned:** baseline 0, target ≥ 5 word groups with a finished mnemonic story within 30 days.
- **Run success:** baseline unmeasured, target ≥ 80 % of story runs finish with a picture over the first 30 days, as shown on the story runs screen.
- **Default chosen:** baseline none, target the owner settles a default AI choice within 30 days of release.

## 8. Open questions

- [ ] Higgsfield charges in credits under a plan rather than a fixed dollar price per picture. How should its price be shown next to it and on the story runs? Default now: the plan's price per picture worked out from credits, labelled "≈". — owner: Maksym, due: before `sdd:design`
- [ ] Which AIs are the defaults for each step (used first, and when a chosen AI disappears, AC-13)? Default now: Sonnet 5.5 for story and picture prompt, Grok for the picture. — owner: Maksym, due: before `sdd:design`
