---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — mnemonic story (after learn-part-step-1)"
---

# 0002 — Run each story run as a Cloudflare Workflow

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

A story run is three paid AI calls in a row: the story writer (≤ 90 s), the picture prompt writer (≤ 90 s) and the picture maker (≤ 120 s) (AC-08b). The learner may leave, lock the phone or close the app at any point. The run must carry on, no finished step may be paid again, and a step in progress must be collected later rather than paid twice (AC-10). The app has no background execution. If the app drove each step with one request, closing it would cancel the Worker's request and lose a result that was already paid for. `ctx.waitUntil` keeps work alive for only about 30 s after the response, which is too short for these steps. The server must also refuse a picture prompt or picture step that does not belong to a counted run (spec §6.1).

## Decision drivers

- No finished step is redone or paid again, even when the app closes (AC-10; sad §1 quality goal 1).
- ≤ 3 min from start to the picture shown with the default AI choice (spec §6 "Story run time").
- ≤ 20 story runs started per UTC day across the whole app, taken on the server (AC-19).
- No new runtime npm dependency in the Worker (sad §2), and as little hand-written state machine as possible for a one-person team.

## Considered options

1. **Cloudflare Workflows** — each run is a Workflow instance named by the app's run id. Each step is a durable `step.do` whose result is persisted, and paid steps have retries off. Results go to D1 (text, prices, times) and R2 (the picture). The app starts the run, polls one status call, and collects the results.
2. **Cloudflare Queues + run state in D1** — the Worker enqueues each step. A queue consumer (up to 15 min per message) calls the provider, writes the result and enqueues the next step. The state machine, and protection against at-least-once delivery, are our own code.
3. **A Durable Object per run** — the run's state lives in the object's storage, and steps run from alarms. This is the most code of the three and a new programming model in this repo, and long picture steps (Higgsfield's submit-and-poll) must be split by hand.

## Decision outcome

**Chosen:** Option 1. Workflows gives durable, resumable steps from the platform, so AC-10 holds without our own state machine or de-duplication. The app-generated run id as the instance id makes a repeated start return the same run without taking a second allowance unit. Paid steps run with `retries: { limit: 0 }`: a failed step is recorded as failed, and the learner decides whether to try again (AC-08b, AC-09). "Try again" for the picture prompt and "Draw again" each create a new instance for that one step of the same run, after the Worker checks that the run exists in D1 and that this step failed. Draw again takes one allowance unit, and the prompt redo takes none (AC-19). Run and step rows stay in D1 with no expiry, so a redo of a counted run is accepted at any later time. A picture is deleted from R2 once the app has collected it, or by the daily clean-up after 7 days (sad §1 decision override).

## Consequences

**Positive**
- AC-10 holds by construction. The app only starts runs and collects them, and when it is closed nothing is lost.
- The allowance, the model check and the "counted run" check sit in one place on the server.
- Several runs can go at once (AC-06). Each is its own instance.

**Negative**
- A new binding (`workflows` in `wrangler.jsonc`) and a new platform feature in this repo. Local tests must run the Workflow under `wrangler dev` with stub providers.
- If the Workflows engine restarts in the middle of an unfinished step, it runs that step again, so a rare double charge is possible (sad §11).
- The Worker keeps run and step rows (story, prompt, AI, price, time) with no expiry, which narrows spec §6.1's "stays on the device" (sad §1 decision override). A picture not collected within 7 days is lost and must be drawn again.
- The app polls. To stay within the per-address limit of 20 requests per 60 s, it uses one status call for all runs it still follows, every 5 s, and only while the learn page or the story screen is open.

**Neutral**
- Moving to Queues later would keep the D1 tables and the app contract and replace only the orchestration (about 3 days of work).

## Links

- Spec: [[../spec.md]] AC-06, AC-08, AC-08b, AC-09, AC-10, AC-16, AC-19, §6, §6.1
- SAD: [[../sad.md]] §4, §6, §7, §8, §11
- Related ADR: [[0001-change-the-app-and-the-worker-as-two-surfaces]], [[0004-serve-the-offered-ai-list-with-prices-from-the-worker]]
