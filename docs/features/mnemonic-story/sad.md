---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)", "Security Lead"]
updated_at: "2026-10-07"
feature_size: "M"
target_surfaces: [mobile-app, backend-service]  # decided in §4 (ADR-0001) — subset of: backend-service | web-frontend | mobile-app | desktop-app | cli | worker | library-sdk. Read (never re-derived) by api/sequences/tasks/plan-tests/review → _shared/surfaces.md
---

# Software Architecture Document — mnemonic-story

## 1. Introduction and goals

**Intent.** Ship the first real exercise behind the learn page's Start: a **mnemonic story** with one picture, written by AI from one **word group** of the session's words to learn (spec §1, §2). A session with more than 19 words to learn is first split by a fixed AI on the Worker into topical groups of 7 to 19 words. The learner selects one group on a pager at the top of the learn page. Each group gets one story made by three AIs in turn, the **story writer**, the **picture prompt writer** and the **picture maker**, chosen by the learner on a new Words settings screen. The story is kept on the phone and made again only when the learner asks. Every **story run** is kept as a record with each AI's result, price and time, so the owner can pick the best AIs for the money. Everything happens in the app. The web learn page does not change, and a daily **story allowance** caps what the whole app can spend.

**Top-3 quality goals (1-liners; full scenarios in §10):**

1. **Spending is bounded and never doubled.** ≤ 20 story runs start per UTC day across the whole app. A finished step is never paid again, even when the app is closed mid-run, and nothing reachable from a shared link can start a run (spec §6 "Story allowance", AC-10, AC-18, AC-19).
2. **A story run finishes on its own.** ≤ 3 min from start to the picture shown with the default AI choice, and the run carries on while the learner is away (spec §6 "Story run time", AC-10).
3. **A saved story opens at once.** ≤ 500 ms from Start to the picture and text shown, from the phone's own storage, with no network (spec §6 "Saved story open time", AC-07).

**Stakeholders.**

| Role | Interest | Sign-off owner? |
|---|---|---|
| learner | Selects a word group, reads its mnemonic story, chooses the AI choice, compares story runs, makes a story again | No |
| partner | Unchanged: the web learn page still leads to coming soon, and nothing on the web can start a run (AC-18) | No |
| Tech Lead (Maksym) | SAD approval | Yes |
| Security Lead | Required by spec §6.1: a new paid server capability reached with a secret that ships in the app | Yes |

**Decision overrides.**
- Decision override: story run results are held on the Worker for up to 7 days — rationale: spec §6.1 says stories, pictures and run records stay on the learner's device. To meet AC-10 (a step in progress when the app closes is collected later, not paid again), the Worker must hold each step's result until the app collects it. The device keeps the only lasting copy. The Worker's copy is deleted by the daily clean-up after 7 days ([ADR-0002](adr/0002-run-each-story-run-as-a-cloudflare-workflow.md), §11). Owner, 2026-10-07.
