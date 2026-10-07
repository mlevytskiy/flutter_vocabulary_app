---
status: Living
updated_at: "2026-10-07"
---

# Domain Context — mnemonic-story

> Project-wide terms (learner, partner, session, shared page, word row, translation) live in the
> repo-root [`CONTEXT.md`](../../../CONTEXT.md). Learn-page terms (learn page, exercise, stage,
> word to learn, coming soon) live in [`learn-part-step-1/CONTEXT.md`](../learn-part-step-1/CONTEXT.md).
> The entry for "mnemonic story" below replaces the one there (per-feature wins).

## Glossary

- mnemonic story — one connected story built from the words of one word group: a chain of steps joined by "→", one step per word, each step a Ukrainian sentence with the English word or phrase embedded as it is (for example "ви tackle величезну проблему-монстра → …"). It comes with one picture drawn from the story. NOT a definition (a definition explains one word; the story links all words of the group) and NOT a translation (the English word stays English inside the Ukrainian sentence).
- word group — 7 to 19 words to learn from one session, ideally 10 to 15, put together by topic or similar meaning, with a short name; the 7-to-19 size holds only when the session has more than 19 words to learn. A session with 19 words to learn or fewer is one word group of any size, named "All words"; words added to it later, while it stays at 19 or fewer and its group has a story, form their own group of any size. NOT a stage (stages group exercises, word groups group words) and NOT a session (a session can hold several word groups).
- story writer — the AI that writes the mnemonic story from a word group. NOT the picture prompt writer.
- picture prompt writer — the AI that turns a mnemonic story into a detailed description for drawing its picture. NOT the picture maker (it writes text, not the picture).
- picture maker — the AI that draws the mnemonic story's picture from the picture prompt writer's description. NOT the story writer.
- selected group — the one word group chosen on the learn page's group pager by tapping its card, remembered per session between visits. NOT pick from learn-part-step-1 (a ticked exercise in the web learn page's address) and NOT a ticked exercise.
- story run — one pass of a word group through the story writer, the picture prompt writer and the picture maker, with what each produced, which AI did it, how much it cost and how long it took. NOT a mnemonic story (a story is the result the learner reads; a run is the record of making it, kept for comparing AIs).
- outdated story — a mnemonic story whose word group's words changed after it was made (a word deleted, its English word edited, or it stopped being a word to learn; editing only a translation or definition does not count). It stays visible, marked "Words changed", until the learner makes a new one. NOT a failed story run (nothing failed; the words moved on).
- story allowance — the most story runs the whole app may start in one day (20 per UTC day, for every learner together), so that a leaked app secret cannot run up the AI bills. NOT the subtitle import allowance (a separate count).
- AI choice — the three AIs (story writer, picture prompt writer, picture maker) the learner picked in the Words screen's settings; every new story run uses the AI choice in force when it starts. NOT a per-story setting (changing it does not change stories already made).

## Invariants

- In a session with more than 19 words to learn, a word group holds 7 to 19 of them; in a smaller session a group may be any size. No word to learn is in two word groups of the same session. A word to learn is in no group only while it waits (see below).
- Only one word group is selected at a time on the learn page.
- Groups without a story keep their words, name and selection when the session is grouped again; new words are only added to them. A group whose story run is in progress counts as a group with a story.
- A word group with a mnemonic story follows edits to its own words (a deleted word leaves it, an edited word takes its new form) and its story becomes an outdated story; it never takes in new words. Only words outside such groups are regrouped.
- Words outside every group with a story are grouped only when there are at least 7 of them or a group without a story can take them; until then they wait.
- A mnemonic story shows every word of its group as written — a whole word in any letter case, a phrase's words in order and next to each other, each English word allowing the ending -s, -es, -ed or -ing; a story run whose story misses one does not go on to the picture.
- A mnemonic story is made again only when the learner asks for it; opening the learn page again never pays twice for the same word group.
- Only the learner's app can start a story run; nothing reachable from a shared link spends money on AI.
- No more than the story allowance of story runs start in one UTC day.
