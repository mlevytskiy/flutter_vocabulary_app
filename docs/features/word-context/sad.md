---
status: Reviewed
owner: "Architect (Claude Opus 5.5); product calls by the owner and the Fable 5.1 owner proxy, 2026-10-30"
reviewers: ["Tech Lead"]
updated_at: "2026-10-30"
feature_size: "M"
target_surfaces: [mobile-app, worker]
---

# Software Architecture Document — word-context

> Spec: [spec.md](./spec.md) · Brief: [owner-brief](../learn-welcome/owner-brief.md)

## 1. Goals

1. **Typed data**: an embedded `WordOrigin` with real fields, not JSON (ADR-0001).
2. **No extra AI cost**: photo context rides the existing `/analyze` call (ADR-0002); backfill uses only the
   dictionary and text already stored (ADR-0004).
3. **Pure rules**: derivation, edit flags, file-name parsing and film-time lookup are pure Dart.

## 2. Constraints

CLAUDE.md rules 1–7; Isar embedded objects (`WordPair` is embedded in `WordCollection`); stored names pinned.

## 3. Building blocks

### 3.1 App

| Block | File | Job |
|---|---|---|
| Model | `lib/core/models/word_origin.dart` (new), `word_pair.dart`, `session_source.dart` | `WordOrigin`, `SourceType`, `ContextKind`, `WordPair.origin/context/contextKind/contextTried`, `SessionSource.fullText` |
| Rules | `lib/core/words/word_origin_rules.dart` (new) | `originForRow`, `withEditedTranslation/Definition`, `withChangedWord`, `episodeFromFileName`, `firstLineTime` |
| Store | `lib/core/services/collection_store.dart` | one-time origin derivation of old rows; fields kept through `put` |
| Words editing | `lib/features/words/words_notifier.dart`, `widgets/translation_dots_button.dart`, `definition_dots_button.dart` | edit flags, word change clears |
| Photo import | `lib/core/services/vocab_photo_service.dart`, `lib/core/models/vocab_word.dart`, the photo import path | `context=true`, `full_text`, `context_source` |
| Subtitles | `lib/core/services/subtitle_parser.dart`, `subtitle_words_service.dart`, `lib/features/words/subtitle_import_flow.dart` | timed lines; movie origin and context per row |
| Dictionary context | `lib/core/services/dictionary_service.dart`, `lib/core/models/definition_result.dart` | example per sense |
| Backfill | `lib/core/words/context_backfill.dart` (new), started like collection autofill | AC-12 |
| Popup | `lib/features/words/widgets/translation_options_content.dart` | context line (AC-13) |

### 3.2 Worker

| Block | File | Job |
|---|---|---|
| Analyze | `vocab-photo-api/src/index.ts` | `full_text`, per-word `context` + `context_source` (`photo`/`ai`), exercise-sheet rule |
| Define | `vocab-photo-api/src/define.ts` | already returns "definition: …\nexample: …" senses; no change unless the app needs a split field |

## 4. Runtime

- Import photo → `/analyze?context=true` → rows with origin image, context, kind; source gets `fullText`.
- Import subtitles → parser keeps `(start, text)` lines → words service sends lines + per-word context → rows with
  origin movie (name/season/episode from the search result or file name, time of the first matching line).
- Learner edits translation/definition → notifier sets the flag; edits the word → clears context and flags.
- Launch → store derives missing origins once → backfill queue fills empty contexts, 20 a minute.

## 5. Architecture decisions

| ADR | Decision |
|---|---|
| [0001](./adr/0001-store-the-origin-as-an-embedded-word-origin-on-the-row.md) | Embedded `WordOrigin` + context fields on `WordPair` |
| [0002](./adr/0002-get-photo-context-from-the-same-analyze-call.md) | Photo context and full text from the same `/analyze` call |
| [0003](./adr/0003-keep-subtitle-cue-times-in-the-parser.md) | The parser keeps cue start times; the first matching line wins |
| [0004](./adr/0004-backfill-context-at-launch-from-stored-text-and-the-dictionary.md) | Launch backfill from the dictionary and stored text only |

## 6. Risks

- Every place that copies a `WordPair` (copy, JSON, share, trial put-aside, morph between rows) must carry the new
  fields: a test per path (AC-14).
- The photo prompt grows; the `/analyze` validator must accept old answers without `full_text`.
