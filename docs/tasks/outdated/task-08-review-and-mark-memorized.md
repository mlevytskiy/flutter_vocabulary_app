# Task 08 — Review collected words on the device and mark one memorized

|  |  |
|---|---|
| **Roadmap step** | [#8](../../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 3 (parallel with task-04 and task-05 — a new screen plus `main.dart`, disjoint from both) |
| **Depends on** | **task-03** — the memorized mark needs a local store to live in |
| **Blocked on** | — |
| **Files** | `lib/screens/` (new) · `lib/main.dart` · `lib/models/word_pair.dart` · `lib/services/word_store.dart` |
| **Status** | not started |

## Prompt

Add a cheap viewing mode: walk the collected words one at a time, see the translation on demand,
and mark a word as memorized.

**This is not a learning engine.** `docs/idea-brief.md` §5 outsources learning to AnkiDroid and
closes spaced repetition explicitly. No intervals, no scheduling, no scoring, no streaks, no
"due today". A list you can flip through and a boolean per word. If you find yourself adding a
date field to decide what to show next, stop — that is the thing this task is defined against.

Two constraints from the brief that are easy to violate by accident:

- **The mark stays on the device and is never exported.** Not in the TSV file, not in the shared
  session, not in the published payload. §5 says this twice.
- **The mark is not a filter on the collection.** A memorized word is still in the list, still
  exported, still shared. Marking is not deleting.

Do the following:

1. **Add the flag to the model.** A `memorized` boolean on `WordPair` (`lib/models/word_pair.dart`),
   defaulting to false. Include it in the `toJson`/`fromJson` that task-03 added, and make
   `fromJson` tolerate its absence — data written before this task has no such key, and the store's
   corrupt-data path returns an empty list, so a thrown exception here silently wipes every
   collected word. Test that specific case.
2. **Build the review screen.** New file in `lib/screens/`. One word at a time: the English word,
   the translation revealed on tap, "memorized" and "not yet", and forward/back. Follow the
   existing screens' construction (`WordsTableScreen` takes its data as a constructor argument and
   is a plain `StatefulWidget` with `setState` — there is no state-management package in this
   project, do not introduce one for this).
3. **Reach it from somewhere obvious.** `lib/main.dart` puts `WordInputScreen` at `home` with no
   routing at all; `WordsTableScreen` is pushed from the input screen. Follow that pattern — push
   from the input screen's existing speed-dial or app bar rather than adding a router.
4. **Persist the mark immediately.** Marking writes through `word_store.dart` on the spot, because
   the OS can kill the app at any moment (see `_pollForLostPhoto`'s comment in
   `word_input_screen.dart` — Android does exactly this). Do not batch marks until the screen is
   popped.
5. **Show the mark in the collection.** Something quiet on the input screen's row or in the words
   table — a checkmark, a dimmed style. This is how the owner sees progress at all. Do not let it
   change row height or shift the lightning icon and dots button; `_buildTranslationDotsButton`'s
   comment explains that constraint, and task-04 is working in the same row.
6. **Handle the empty and one-word cases.** An empty collection gets a message, not a broken
   carousel. A single word gets no "next".

## Acceptance criteria

- [ ] **AC-1** `flutter analyze` exits 0; `flutter test` passes.
- [ ] **AC-2** Store round-trip: a pair marked memorized loads back marked; an unmarked one loads
      back unmarked.
- [ ] **AC-3 — the migration case.** `fromJson` on a map with **no** `memorized` key returns a pair
      with `memorized == false` and does not throw. Then: seed the store with a pre-task JSON
      payload (no `memorized` anywhere), launch, and confirm the words are all still there. A throw
      here is indistinguishable from "corrupt data" and loses the collection.
- [ ] **AC-4** On device: open the review screen with 5 collected words, flip through all 5, reveal
      each translation, and go back and forward. The order is stable and no word is skipped or
      repeated.
- [ ] **AC-5** On device: mark word 2 memorized, force-quit the app, reopen, return to the review
      screen. Word 2 is still marked.
- [ ] **AC-6** On device: mark word 2 memorized, then force-quit **without** leaving the review
      screen. The mark survived — it was written on the tap, not on the pop.
- [ ] **AC-7** On device: a memorized word is still present in the word list and still appears in
      the words table.
- [ ] **AC-8 — the export stays clean.** Mark 2 of 5 words memorized and export the AnkiDroid file.
      `diff` it against the file exported before marking: identical. `grep -i memor <file>` returns
      nothing.
- [ ] **AC-9** If task-05 has landed: publish a session with marked words and `curl` the stored
      session document — no `memorized` key anywhere in it.
- [ ] **AC-10** On device: the input screen row for a memorized word has the same height and the
      same lightning-icon and dots positions as an unmarked row. Compare screenshots.
- [ ] **AC-11** On device with zero collected words: the review screen shows an empty-state message
      and does not crash. With exactly one word: no "next" affordance, no index out of range.
- [ ] **AC-12** Toggle a word memorized and back to not-yet several times — the state follows the
      taps and persists correctly at each step.
- [ ] **AC-13** `grep -rniE "interval|schedule|due|streak|srs" lib/screens/<the new screen>` returns
      nothing. No scheduling logic was built.
