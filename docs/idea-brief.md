---
status: Draft
owner: "Maksym"
updated_at: "2026-09-14"
depth: "hard"
---

# Idea brief — word-collector

## 1. Raw idea

"I want to create an application to save words. I learn English in some courses and see that the application that they use is not good for me. They use Quizlet, and in that application I can't export words from file and use it as owner of these words. So I want to create this in my own application and make it more modern, more useful for myself first of all. And the goal is to create something useful that we can use in a pair. For example, I have a speaking club or I have some meeting with people who learn English or some lesson, and usually we have two people in both sides who work with some material, and in this case it's good to have some application when we have entered words and maybe we should have some shared page, web page, when we have also see what we shared data that these words. Why it should be application? because I also want to use a possibility to get words from photo. And application is the most appropriate, I think in this case. I can take photo and it automatically gets highlighted words from it, English words, and fill up with these words. and I can share these words as I want with file or maybe with this mediator page. And after that, I can use some application for learning words. For example, I use a Droid application and it's possible to make file. After that, I import it in Droid application and learn these words. So yes, that's why I wanna create the application."

## 2. Problem

Collecting new English words during courses, lessons and speaking clubs is slow and the result isn't owned by the learner: Quizlet holds the words and won't export them back as a file. The words themselves already exist in physical material — marked with a highlighter while reading — but moving 5–10 marked words from a paper page into a usable list means retyping them plus their translations one at a time. Sharing that list with the one or two other people in the room has no path at all today except reading words aloud or sending a file after the fact.

## 3. Users

- **The learner (the owner)** — Maksym, in weekly English courses and speaking clubs; collects roughly 5–10 words per session, and is the primary and only guaranteed user.
- **The partner across the table** — one, sometimes two other people in a pair lesson or small speaking club who need the same word list during the session and may correct entries in it. They have no account and no prior knowledge of the tool; they only ever receive a link.
- **Downstream: the learning app** — words leave as a file for AnkiDroid, which stays the place learning actually happens.

## 4. Why now

Two concrete triggers rather than a general wish. First, the courses are running now and Quizlet's export limitation is being hit every week. Second, the hardest part is already built and working: photo capture with highlighted-word extraction ships on iOS, one-tap translation fill works, and a server component exists — so the remaining work is the surface around a proven mechanism, not a research bet. The Reverso integration also has to come out now (its free tier stopped working), which forces a decision about where extra word information comes from.

## 5. Out of scope

- **Own learning / spaced-repetition engine** — learning is outsourced to AnkiDroid; only a cheap viewing mode with a memorized / not-yet mark is in the first version, and its mark stays on the device and is never exported.
- **Languages other than English↔Ukrainian** — deliberately closed after discussion; a wider language set was considered and rejected for the first version, and a later migration is accepted as the cost.
- **Session → app sync-back** — corrections made on the shared page do not flow back into the app; the file download is the only return path for now. The direction stays planned, not built.
- **Reverso as an information source** — removed from the app entirely; the free tier does not work.
- **A dictionary for English→Ukrainian translation** — no free one was found, so machine translation stays the only translation source. Free English-description dictionaries are a later addition for extra word detail.
- **Accounts, passwords, permissions on the shared page** — a link is the only credential.
- **Large groups** — the shared page targets two, at most three people.

## 6. Risks

- **Weakest spot: highlight-extraction fidelity is the whole product, and it currently has a correctness defect.** The maximum-words setting behaves as a quota rather than a cap: when fewer words are highlighted than the limit, unhighlighted words are returned to fill it. Every value the idea promises collapses if the app returns words that were never marked, because then the list has to be pruned by hand and typing five words is faster.
- **Assumes the partner opens the link mid-session; false if people stay in conversation.** The shared page is the largest component of the project and the one whose adoption depends on someone other than the owner. If it goes unused, the project's value shrinks to capture-plus-export — which is still useful, but a fraction of what's being built.
- **Assumes a durable, editable, unauthenticated link is acceptable; false if the link leaks.** Session data and photos persist indefinitely and anyone holding the URL can rewrite or delete the word list. Tolerable at two or three trusted people, dangerous by default at any larger scale.
- **Machine translation of a bare typed word will sometimes give the wrong sense, and a wrong translation gets memorized.** Mitigated for photo capture, where the surrounding text gives context, and partly mitigated for typed words by showing the alternative translation variants — but not eliminated. The words most worth capturing are the ambiguous ones.
- **The project competes with the thing it serves.** Building the app takes the same evenings as learning English; the app only pays for itself if it reaches usable state within a few sessions.
- **Scope has a habit of growing by "opening doors."** Three were opened and mostly closed during this interview; subtitles, frequency ranking and goal-based prioritisation are already queued behind the first version.

## 7. Recommendation

Build it as a **word collector whose differentiator is capture technology**, not as a small Quizlet. The mechanism to be excellent at is the one already working: a highlighter marks words on a physical page, a photo turns exactly those marked words — and only those — into a list with translation, pronunciation and the sentence they came from. Fix the quota-versus-cap defect before adding anything, because it is the single behaviour the whole promise rests on. Design the shared session as **source-agnostic** from the start: the word table on one side, whatever the words came from on the other — a photo today, a movie's subtitle text next — so every future capture source is an addition rather than a rewrite. First version: highlighter capture, one-tap translation, UK/US pronunciation, the durable editable shared link, file download for AnkiDroid, and a cheap local viewing mode.

## 8. Open questions

- Which pronunciation source to use for UK and US audio — undecided. *Owner: Maksym.*
- When more words are highlighted than the maximum, which ones are dropped — reading order, or the owner chooses? *Owner: Maksym.*
- Which free English-description dictionary provides the extra word detail, and when it lands. *Owner: Maksym.*
- How long a shared session and its photos live, and whether anyone can delete one. *Owner: Maksym.*
- Whether the random per-person names on the shared page are needed at all, given nothing depends on identity in the first version. *Owner: Maksym.*
- Whether the shared page shows multiple photos as a scrollable set, or one photo per session to start. *Owner: Maksym.*
- What the machine translation source is for typed words once quality complaints appear — the photo path already uses a stronger context-aware translation than the typed path. *Owner: Maksym.*
