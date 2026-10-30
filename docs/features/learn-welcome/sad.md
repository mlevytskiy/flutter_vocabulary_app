---
status: Reviewed
owner: "Architect (Claude Opus 5.5); product calls by the owner and the Fable 5.1 owner proxy, 2026-10-30"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "L"
target_surfaces: [mobile-app, worker]
---

# Software Architecture Document — learn-welcome

> Spec: [spec.md](./spec.md) · Brief: [owner-brief.md](./owner-brief.md) · Architecture: [docs/architecture.md](../../architecture.md)

## 1. Goals

1. **Correct boxes**: every rating moves its box exactly by AC-08, saved at once (ADR-0004).
2. **Never wait without need**: topics within 4 s or fallback; stories start when the cards open and slot in late.
3. **Reuse**: the Talk screen (choices, mission, quick check), the story pipeline (`StoryRunTracker`), the Leitner
   rules and the results screen layout are reused, not rewritten.

## 2. Constraints

CLAUDE.md rules 1–7 (typed routes, providers, `@riverpod` notifiers, no new packages, move code by cut-and-paste),
Flutter 3.47.8 / Riverpod 3, Cloudflare Worker `vocab-photo-api`.

## 3. Context and scope

Learner → app (Learn flow) → Worker: `POST /learn/topics` (new), the talk mission/turn routes (topic and reply limit
added), the story run routes (per-word extras added, word-context). Story pictures come back through the existing
status polling.

## 4. Solution strategy

One `LearnFlowNotifier` owns the flow as a state machine (warm-up → cards with story slots → main dialog →
results). Pure Dart decides the card words, the split, the dialog words and the story slots, so they are unit
tested without widgets. The cards and story pages are one `PageView`; the story page asks for landscape when it
shows. The card is one shared widget with the self-check rating rules (ADR-0006).

## 5. Building blocks

### 5.1 App

| Block | File (new unless marked) | Job |
|---|---|---|
| Self-check rules | `lib/features/learn/session/self_check.dart` | `SelfRating`, `rateBox(box, rating, now)`, `nextSide(box)`, box labels (AC-07, AC-08) |
| Card words, split, dialog words | `lib/features/learn/flow/flow_words.dart` | `cardWords` (AC-05), `splitGroups` (AC-06), `dialogWords` (AC-13) |
| Story slots | `lib/features/learn/flow/story_slots.dart` | pure scheduler: next page after a card, given which stories are ready (AC-10) |
| Learn flow notifier | `lib/features/learn/flow/learn_flow_notifier.dart` | state machine, per-card save, story start/reuse, leave (AC-01, AC-08, AC-09, AC-16) |
| Topics service | `lib/core/services/learn_topics_service.dart` | `POST /learn/topics`, 4 s timeout, bundled fallback (AC-03) |
| Warm-up | `lib/features/learn/flow/warm_up_view.dart` + talk widgets | 2-step bar, choices, own topic (AC-02, AC-04) |
| Self-check card | `lib/features/learn/session/self_check_card.dart` | flip card, buttons, context line (AC-07, AC-18) |
| Flow pager | `lib/features/learn/flow/learn_flow_screen.dart` | cards, story pages, wait page, counter (AC-07, AC-10, AC-11) |
| Orientation | `lib/app.dart`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml` | portrait lock; story page landscape (ADR-0005) |
| Results | `lib/features/learn/session/session_results_screen.dart` (changed) | three parts and buttons (AC-15) |
| Entry | `lib/features/words_table/widgets/learn_share_bar.dart`, `lib/features/learn/entry/learn_sheet.dart` (removed), `lib/router/routes.dart` | Learn → flow route; < 4 words snackbar (AC-01, AC-17) |
| Model | `lib/core/models/word_box.dart` (changed) | `lastCheckSide` (rule 5) |

### 5.2 Worker

| Block | File | Job |
|---|---|---|
| Topics | `vocab-photo-api/src/learn/topics.ts` (new), `routes.ts` | 50 topics constant; `POST /learn/topics` picks 3 ids with the mission's model; not counted |
| Mission | `vocab-photo-api/src/learn/talk.ts`, `talk-mixed.ts` | takes `topic` and `maxReplies` (6 or 12) and the chosen words |
| Story extras | `vocab-photo-api/src/story/prompts.ts`, `routes.ts` | per-word `context`, `source`, `translation` into the story writer prompt (AC-12) |

## 6. Runtime view

1. Learn → `LearnFlowRoute(collectionId)`; < 4 words → snackbar. The notifier computes `cardWords` and
   `splitGroups`, starts `POST /learn/topics`, and shows the warm-up.
2. Q1 answered (topic id or own text) → Q2 answered (Hard / Easy) → the cards open; the notifier starts or reuses
   up to 3 story runs and the mission picture, all in the background.
3. Each rating: `rateBox` → one `CollectionStore.update` for that word (box, due, `lastUpDay`, `lastCheckSide`).
   After each card `story_slots` decides: next card, a story page, or the wait page.
4. Story page shows → landscape; next page → portrait.
5. After the last card and stories → the Talk screen in mission mode with the topic, `maxReplies` and
   `dialogWords`; its results go to `WordResult` (no box move); the quick check gives missed/hinted words a
   self-check card (self-check-cards).
6. Results screen → Exercises (learning session) · Talk with AI · Done.

## 7. Crosscutting

- Errors: topics fall back; a failed story run shows its wait page error with "Skip"; a refused talk (limit) skips
  the dialog with a note.
- Tests: pure files get unit tests; the Worker route gets vitest; screens get widget tests (`docs/testing.md`).

## 8. Architecture decisions

| ADR | Decision |
|---|---|
| [0001](./adr/0001-run-the-learn-flow-in-one-notifier-over-one-pager.md) | One `LearnFlowNotifier`, one pager for cards and story pages |
| [0002](./adr/0002-split-card-words-on-the-phone-in-list-order.md) | Phone-side split in list order with the source-tail rule |
| [0003](./adr/0003-keep-fifty-topics-in-the-worker-and-pick-three-with-ai.md) | 50 topics in the Worker, AI picks 3, 4 s fallback |
| [0004](./adr/0004-save-each-card-rating-at-once.md) | Save each rating at once (not at the session end) |
| [0005](./adr/0005-lock-the-app-to-portrait-and-turn-only-the-story-page.md) | Portrait lock; story page turns to landscape |
| [0006](./adr/0006-one-self-check-card-and-one-set-of-rating-rules.md) | One card widget and rating rules shared with self-check-cards |

## 9. Risks

- The once-a-day up rule and the per-card save must agree with exercise sessions' end-of-session write
  (learn-redesign ADR-0002): both go through `CollectionStore.update`, which reads the stored boxes first.
- Rotating inside a `PageView` can jump pages: the story page keeps the pager index across the rotation (test).
- Three parallel story runs share the 20-a-day story allowance; a refusal shows the wait page's error and Skip.
