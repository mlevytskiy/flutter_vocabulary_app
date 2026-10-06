# implement handoff — import-from-quizlet

Resume note for a new Claude session. Source of truth for done/todo: `tracker.md` + `git log --grep "SDD-Task"`.

## How the run works
- Branch `feature/import-from-quizlet` (from master @ 4da3167). Nothing pushed, nothing deployed.
- Each task runs in its own fresh subagent, one at a time, in tracker order. The per-task prompt is below under "Per-task prompt". It does TDD, gates the work, commits with `SDD-Task`/`SDD-AC` trailers, and flips the tracker row.
- Gate baseline: `flutter analyze` = 9 pre-existing info lints; the grep hit `static final PhotoScaler instance` is pre-existing.
- **User WIP is stashed:** `git stash list` → "pre-quizlet-implement: user WIP (speed dial icon, good-looking-web CONTEXT)". It changes `Icons.subtitles` to `Icons.movie` in word_input_speed_dial.dart and edits docs/features/good-looking-web/CONTEXT.md. Restore it with `git stash pop` after all tasks are done. A conflict in word_input_speed_dial.dart is possible: keep the feature's code and apply the one-line icon change by hand.

## To resume
In a new session: "continue implementing import-from-quizlet per docs/features/import-from-quizlet/tasks/implement-handoff.md".
First check `git status` and `git log --oneline -20`. If a task left uncommitted work, inspect it: finish that task, or `git restore` its files and redo it.

## Remaining plan
**State (2026-10-06): run stopped after T16 at the user's request. The stash has already been popped (user WIP is back in the working tree, uncommitted). What's left: the final gate, the owner deploy, T17, then /sdd:review.**

### Original plan
- T13 → T14 → T15 → T16 (docs only; the remote migration and `wrangler deploy` are run by the owner) → T17 is blocked on the owner (manual device pass).
- Then: `git stash pop`, final gate (`dart run build_runner build --delete-conflicting-outputs`, `flutter analyze`, `flutter test`, the CLAUDE.md grep), then report.

## Status log (update after each task)
| Task | Commit | Notes for later |
|---|---|---|
| T1 | e8410a1 | migration promoted as 0003_set_sources.sql; T16 must apply it `--remote` before deploy |
| T2 | 6332761 | Worker stores sets (kind/name/url), no source cap, 400 invalid_source; /changes feed is photos only |
| T3 | e37c522 | set page in the pager and phone dialog; **look not checked visually** (360px and wide) |
| T4 | 1cd3dc3 | SessionSource + SourceKind; Isar name kept `SourcePhoto`; legacy record read only checked indirectly |
| T5 | ac9a331 | Screenshot item and package removed (spec §1 owner decision) |
| T6 | 5673e8f | quizlet_link.dart: find / setIdOf / isNavigationAllowed |
| T7 | 47b302e | page script + parser; **fixtures are synthetic, selectors are guesses**; T17 must capture real pages |
| T8 | 6fc01ec | quizlet_cards.dart proposeWords → QuizletProposal |
| T9 | ca362c6 | quizlet_link_dialog.dart + QuizletImportMessages |
| T10 | 97d4c96 | webview_flutter added (ADR-0002); progress dialog + QuizletReadController seam; device check pending |
| T11 | 904e2e4 | showQuizletResultDialog |
| T12 | 2e533a6 | quizlet_import_flow.dart runQuizletImport; the progress dialog stays open during translation (afterRead) |
| T13 | b461bc2 | menu item (green, Icons.style); notifier upsertSetSource → source id `quizlet-<setId>`; WordInputScreen has a @visibleForTesting quizletDriverFactory |
| T14 | 6db5b7d | Include sources (N) switch; no cap; sets never uploaded |
| T15 | a5e11a2 | ordinary-words test; existing quirk: blank rows left between imported words when the first row is reused (photo/subtitle path, not changed) |
| T16 | 92ec8ac | 2026-10-06: remote migration 0003 applied + Worker deployed (version a8eed637); remaining: publish check from the old store build. Docs only; tracker says in_progress; owner deploy checklist in vocab-photo-api/README.md |

## Per-task prompt
The text sent to each subagent: "Your task: Tn — <title> (task file …). <context notes from the log above>. Read the full instructions in <this section> and follow them exactly."

1. Read CLAUDE.md, docs/architecture.md, the task file, and its tasks.json entry; also the cited ACs in spec.md §5 and the relevant parts of sad/data-model/adr/ux-flows/CONTEXT.
2. TDD: write the failing test first, classify the first run, and quote the failing line. Then write the minimal code to pass, and refactor. Never weaken a test.
3. Gate: build_runner if codegen changed; `flutter test`; `flutter analyze` (no new issues); `npm --prefix vocab-photo-api run typecheck`; `npm --prefix vocab-photo-api test` if the Worker was touched; the CLAUDE.md grep.
4. Commit only this task's files, with the `feat(import-from-quizlet): <title>` message and the `SDD-Task`/`SDD-AC` trailers plus `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Flip the tracker row in the same commit.
5. No deploy, no `--remote`, no push. Never run `dart format` on the whole repo.
6. If the task can't be done as written: follow CLAUDE.md rule 6 and report.
