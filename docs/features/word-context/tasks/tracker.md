# Tracker — word-context

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Record word-context approvals in CLAUDE.md rules 3 and 5](./t1-record-word-context-approvals-in-claude-md-rules-3-and-5.md) | docs | implementer agent | S | — | done |
| T2 | [Add WordOrigin, SourceType, ContextKind and the new row and photo fields](./t2-add-wordorigin-sourcetype-contextkind-and-the-new-row-and-ph.md) | infra | implementer agent | M | T1 | todo |
| T3 | [Add the pure origin rules: derive type, edit flags, word change, episode from a file name, first line time](./t3-add-the-pure-origin-rules-derive-type-edit-flags-word-change.md) | domain | implementer agent | M | T2 | todo |
| T4 | [Derive origins of old rows once on load](./t4-derive-origins-of-old-rows-once-on-load.md) | infra | implementer agent | S | T3 | todo |
| T5 | [Set the edit flags on learner edits and clear on a word change](./t5-set-the-edit-flags-on-learner-edits-and-clear-on-a-word-chan.md) | app | implementer agent | M | T3 | todo |
| T6 | [Return the photo's full text and per-word context with its kind from /analyze](./t6-return-the-photo-s-full-text-and-per-word-context-with-its-k.md) | ports | implementer agent | M | — | todo |
| T7 | [Save photo context, its kind and the full text when a photo is imported](./t7-save-photo-context-its-kind-and-the-full-text-when-a-photo-i.md) | app | implementer agent | M | T2, T6 | todo |
| T8 | [Keep subtitle cue times and save the movie origin and context on film rows](./t8-keep-subtitle-cue-times-and-save-the-movie-origin-and-contex.md) | app | implementer agent | M | T3 | todo |
| T9 | [Set the dictionary example as context when a definition is filled or picked](./t9-set-the-dictionary-example-as-context-when-a-definition-is-f.md) | app | implementer agent | S | T2, T5 | todo |
| T10 | [Backfill empty contexts at launch from the dictionary and stored text](./t10-backfill-empty-contexts-at-launch-from-the-dictionary-and-st.md) | app | implementer agent | M | T4, T9 | todo |
| T11 | [Show the context in the Words screen word popup](./t11-show-the-context-in-the-words-screen-word-popup.md) | ui | implementer agent | S | T1, T2 | todo |
| T12 | [Finish word-context: generated code, analyze, changed tests, grep check, deploy note](./t12-finish-word-context-generated-code-analyze-changed-tests-gre.md) | docs | implementer agent | S | T5, T7, T8, T10, T11 | todo |

**Total:** 12 tasks, ~9.5 person-days.
