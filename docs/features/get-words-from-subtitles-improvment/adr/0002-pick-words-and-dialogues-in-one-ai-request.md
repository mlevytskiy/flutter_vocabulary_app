---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: []
updated_at: "2026-10-07"
feature_size: "M"
ticket: "roadmap — get words from subtitles improvement (dialogues)"
---

# 0002 — Pick words and dialogues in one AI request

- **Status:** Accepted
- **Date:** 2026-10-07
- **Deciders:** Maksym (owner, Tech Lead), with Claude during the design walk

## Context

Today a subtitle import is one Anthropic call through `POST /subtitles/words`: the app sends the stripped dialogue lines, the Worker takes one unit of `all_subtitle_imports`, asks the chosen model once (`max_tokens` 16000, 225 s Worker limit, 240 s app limit) and returns words only if the reply is complete. With the dialogues setting on, the import must also return up to 10 film dialogues holding the proposed words, complete or nothing (spec AC-04, AC-05, AC-08).

## Decision drivers

- Switch off is unchanged: 0 differences in what the import sends and shows (spec §6, sad §1 quality goal 1).
- 0 extra failed imports at maximum 20 with the switch on (spec §6).
- Complete or nothing: a cut-off reply gives neither words nor dialogues (AC-08).
- No hard time target; time is measured per model and shown (spec §6).

## Considered options

1. **One request** — with `dialogues: true`, the same call returns `words` and `dialogues` in one JSON object; `max_tokens` 20000 for that request only.
2. **Two requests in a row** — today's call unchanged for the words, then a second call with the lines and the chosen words that picks the dialogues.

## Decision outcome

**Chosen:** Option 1. One call keeps one allowance unit, one wait and one completeness check. A reply that did not end normally, or has a missing or malformed `dialogues` array, fails the whole import, which is AC-08 for free. Two calls would roughly double the time and the input tokens, since the full subtitle text is sent twice. And because of AC-08, a failed second call would still throw away a paid first one.

## Consequences

**Positive**
- One unit, one wait, one reply check. The dialogues can only name words from the same reply.
- Without the field, the request is byte for byte today's, and a Worker test pins that.

**Negative**
- A longer reply. At maximum 100, the call may come closer to the 225 s limit or the higher `max_tokens`. The device pass in spec §6 watches this, and it is a §11 risk.
- The model's attention is shared between words and dialogues, which may slightly change which words it picks.

**Neutral**
- Splitting into two calls later only touches the Worker route and the prompt. The app contract (`dialogues` in the reply) can stay.

## Links

- Spec: [[../spec.md]] AC-04, AC-05, AC-07, AC-08, §6
- SAD: [[../sad.md]] §4
- Related ADR: words-from-subtitles ADR-0004 (the subtitle model allow-list)
