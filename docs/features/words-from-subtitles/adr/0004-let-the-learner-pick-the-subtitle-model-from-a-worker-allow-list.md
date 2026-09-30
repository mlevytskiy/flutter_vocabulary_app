---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-09-30"
feature_size: "S"
ticket: "docs/features/words-from-subtitles/spec.md"
---

# 0004 — Let the learner pick the subtitle model from a Worker allow-list

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

The owner wants to compare AI models on subtitle imports after release (spec §1 decision, AC-21): which picks words closest to the chosen level and purpose, how long it takes, what it costs. The photo import uses a single fixed model (`claude-sonnet-5`) in the Worker. The app secret ships in the app, so whatever the app may ask for, anyone holding the secret may ask for too.

## Decision drivers

- AC-21: the learner chooses the model in Settings; the results dialog names the model, the time and the approximate cost.
- spec §6.1: no general-purpose AI through a leaked secret — the most expensive models must not be reachable.
- Four models with different request rules: Sonnet 5 and Sonnet 5.5 at $2 / $10, Haiku 4.5 at $1 / $5, Opus 5.5 at $4 / $20 per million tokens.

## Considered options

1. **Settings choice, sent per request, checked against a Worker allow-list** — the app stores the choice and sends it; the Worker accepts only the four listed ids and refuses anything else.
2. **Model chosen in Worker configuration** — a `wrangler` variable picks the model for everyone; comparing means redeploying the Worker between imports, with nothing on the phone.

## Decision outcome

**Chosen:** option 1. Settings offers Sonnet 5 (default, the photo model), Sonnet 5.5, Haiku 4.5 and Opus 5.5; the choice persists with the other import preferences and applies to subtitle imports only. The Worker holds the allow-list and builds each model's request (reasoning settings differ by model); an unknown id is refused before the allowance is touched. The response returns the model id, the AI time and the input and output token counts; the app turns them into the "model · time · ≈ cost" line with a dated price table in one file.

## Consequences

**Positive**
- Model comparison happens on the phone, per import, with the numbers in front of the learner.
- The allow-list caps the worst per-import cost at the Opus 5.5 price.

**Negative**
- Four request variants to keep working and to test; a model retired by Anthropic needs a Worker change.
- The cost line goes stale when prices change until the app's table is updated.

**Neutral**
- Narrowing to one model after the comparison is a matter of shortening the list in both places.

## Links

- Spec: [[../spec.md]] AC-21, §1 decisions, §6.1
- SAD: [[../sad.md]] §4, §8, §11
- Related ADR: [[0003-count-subtitle-imports-per-address-and-per-day-in-d1]]
