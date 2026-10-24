# Mixed conversation missions

Owner request: 2026-10-24. Replace compulsory spoken answers on every turn with
short action choices and occasional speaking tasks. This authorizes the Talk UI
changes below; retain its theme, mission picture, bubbles, voice player and routes.
Checkpoint before implementation: `42245e9` (app source already at `f39bcd7`).

## Behaviour

- Start with 2–3 short action intentions. After two learner turns, offer one
  purposeful speaking task. Repeat for three rounds: nine learner turns total.
- Choices affect the scene; the AI responds to the selected action. No complete
  scripted answers or disguised definition questions. Plan around 3–4 compatible
  words (or fewer when supplied), with the existing opening picture and mission.
- “Say something else” opens the existing mic and typing controls on a choice turn.
  Speaking tasks always allow typing. Recording starts only with a mic gesture;
  automatic reading of AI replies never activates the microphone in mixed mode.
- Practice words are hidden until requested. Hint is immediately available during
  a speaking task. Existing explicit-hint scoring remains in place.
- Choice selections never tick words or advance their Leitner boxes. Learner-authored
  typed/spoken answers use the existing whole-word matcher and hint-aware scoring.
  This matcher does not assess semantic correctness or pronunciation.
- A failed selection keeps its source when retried; it cannot become independent
  recall. Duplicate sends while waiting are ignored.
- The ninth learner turn receives a final in-character outcome. Keep that outcome
  readable with “See results”; do not cut straight to results on word completion.
  End talk still finishes early. Unused words keep their existing review state.
- Original Workers without mixed response fields retain the legacy conversation UI.

## Transport and implementation

`POST /learn/talk` keeps its current route, secret, allowance, timeout and history cap.
New clients send `mode: "mixed"`. Learner history entries selected from a button
include `source: "choice"`; learner-authored lines omit it. The response adds:

- `interaction`: `choice`, `speak`, or `complete` (determined by the server).
- `choices`: 2–3 nonempty distinct strings, at most 80 characters, for choice turns.
- `speakingPrompt`: a nonempty instruction of at most 200 characters for speech turns.

The opening retains `mission`; every turn retains `reply` and `target`. Invalid
structured model answers fail with the existing retryable error. The server keeps
its legacy plain-text protocol for callers without `mode`. No dependencies, domain
models, persistence schemas, migrations or routes are added.

Screen state for custom input and word visibility stays in widget State. Interaction,
choice attribution, retry and scoring live in the existing Riverpod Talk notifier.
The mission's role, goal, brief and image description accompany each reply.

## Verification

- `test/talk_mixed_api_test.dart`: wire shape, source attribution, malformed responses,
  backwards compatibility.
- `test/learn_session_talk_test.dart`: choice/retry scoring, assisted versus independent
  use, outcome retained, scene continuity.
- `test/learn_session_talk_screen_b_test.dart`: choices → speaking, no automatic mic,
  explicit mic start, custom answer and ending controls.
- `vocab-photo-api/test/learn-talk-mixed.test.mjs`: cadence, parsing, target advancement,
  structured model output, route contract through the local AI stub.
- Existing talk/voice/hands-free tests plus smoke and changed tiers.

Both the updated Worker and app build are needed to enable mixed missions. Local
stub tests do not establish the live model's narrative quality or device audio behaviour.
