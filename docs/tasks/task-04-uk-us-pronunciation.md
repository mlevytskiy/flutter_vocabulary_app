# Task 04 — Hear a word in UK and US pronunciation

|  |  |
|---|---|
| **Roadmap step** | [#4](../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 3 (parallel with task-05 and task-08 — disjoint file sets) |
| **Depends on** | — |
| **Blocked on** | — (D1 resolved: on-device TTS, `flutter_tts`) |
| **Files** | `lib/core/widgets/synced_text_field_row.dart` · `lib/core/services/pronunciation_service.dart` (new) · `lib/core/providers.dart` · `lib/features/word_input/word_input_screen.dart` · `lib/features/word_input/widgets/word_row_item.dart` · `lib/features/word_input/widgets/pronunciation_buttons.dart` (new) · `pubspec.yaml` |
| **Status** | done; AC-1..4 verified (device pass through the icon-placement/accent-swap iterations above); AC-5..10 not explicitly checked |

## Blocked on D1

> Which UK/US pronunciation source: on-device TTS with an `en-GB`/`en-US` locale switch
> (synthesized, no key, offline), `dictionaryapi.dev` audio (one accent per entry, not a guaranteed
> pair), or Wiktionary/Commons recordings (real voices, inconsistent coverage)?

The choice decides the whole task, not just the implementation:

| Source | UK **and** US guaranteed | Offline | Real voice | Cost of a miss |
|---|:---:|:---:|:---:|---|
| On-device TTS (`flutter_tts`) | yes — it is a locale switch | yes | no | a wrong-ish synthesized vowel |
| `dictionaryapi.dev` audio | **no** — often one accent, sometimes neither | no | yes | the feature silently has nothing to play |
| Wiktionary / Commons | no — coverage is uneven | no | yes | same, plus attribution obligations |

**On-device TTS is the recommendation.** It is the only option where "UK and US" is a property of
the request rather than a property of whatever the dictionary happens to hold, which means the
feature never has an empty state — and an empty state is what kills a two-button UI. It also needs
no key, no network and no per-word latency, which matters in a classroom. The trade-off is honest
and worth naming: a synthesized voice is not a recording, and for words whose UK/US difference *is*
the point, it may not reproduce that difference convincingly. Answer D1 in `docs/roadmap.md` before
starting; if you pick a recording-based source, the prompt below still applies but add an explicit
"no audio for this word" state to the UI and to the acceptance criteria.

## Prompt

Let the owner hear a collected word in both British and American pronunciation, from the row the
word is already in.

Do the following:

1. **Wrap the source behind a service.** New `lib/services/pronunciation_service.dart` exposing
   something like `Future<void> speak(String word, {required Accent accent})` with
   `enum Accent { uk, us }`. Keep the source choice inside it. D3/task-09 may later add a
   dictionary source that also carries audio, and D1 itself may be revisited — the rest of the app
   should not know which one is in use. Follow the existing service shape: plain class, own
   exception type (compare `VocabPhotoException`, `ReversoException`).
2. **Add the trigger to the row.** As of the task-00 restructure the lightning icons and the dots
   button are `Positioned` overlays inside the `Stack` in
   `lib/features/word_input/widgets/word_row_item.dart`, not suffix icons.
   **Chosen instead of the single-speaker recommendation below**: two flag+speaker buttons (US,
   UK — `lib/features/word_input/widgets/pronunciation_buttons.dart`), one tap each. Three
   placements were tried before landing here: (1) the field's `leftSuffixIcon` — permanently
   narrowed the Word field's text area even when hidden; (2) a `Positioned` overlay at the Word
   field's own top-left corner, like the lightning icons — still sat on top of typed text; (3) a
   dedicated strip above the `Stack`, aligned to the Word field's right edge — correctly outside
   the field, but added a new band of height to the row whenever a row had a translation.
   **Final placement**: the row's *existing* top strip — the 26px band the close ("X") button
   already lives in — with "X" still pinned right and the flags (26×26 each, matching the strip's
   height exactly, so nothing grows or clips) positioned at the X coordinate directly above the
   Word field's own right edge. Getting that X coordinate into the top strip's Row (a sibling of,
   not a descendant of, the fields' own `LayoutBuilder`) needed an outer `LayoutBuilder` wrapping
   the whole card, replicating the drag-handle-slot (40px) and dots-button-slot (26px) math the
   inner one already does, then a leading spacer `SizedBox` sized to
   `dragHandleWidth + wordFieldWidth - flagsWidth`. Visibility: shown once the row **has a
   translation**
   (`translationController.text` non-empty) — deliberately *not* gated by
   `docs/lightning_icon_rules.md`'s in-focus rule, since this isn't a compose-time action tied to
   the row you're actively editing. (Original recommendation, not used: a single speaker icon, tap
   for a primary accent and long-press for a UK/US choice, or UK-then-US in sequence.)
3. **Only offer it when there is something to say.** The icon appears only when the Word field
   holds at least 2 characters (the same threshold the existing lightning icons use). An empty or
   one-letter Word field gets no speaker.
4. **Handle the overlaps.** Tapping while audio is already playing must stop the current playback
   and start the new one, not queue or overlap. Leaving the screen, backgrounding the app, or
   deleting the row all stop playback. Dispose whatever the plugin needs disposed in `dispose()` —
   this screen already manages a large amount of per-row disposal.
5. **Do not touch the export.** The idea brief keeps pronunciation as an in-app affordance; nothing
   about audio goes into the AnkiDroid file.

## Acceptance criteria

- [x] **AC-1** `flutter analyze` exits 0 (modulo the 5 pre-existing baseline infos, unchanged by
      this task; `flutter test` also green throughout).
- [x] **AC-2** On device: the two flag buttons are visible on any row that has a translation
      (focused or not), and absent on a row with no translation yet — overriding the original
      wording above (see step 2's note on the chosen design). Confirmed through the placement
      iterations above.
- [x] **AC-3** On device, with earphones or speaker on: a word plays in British pronunciation and
      in American pronunciation, and the two are audibly different. Confirmed — required the
      `getVoices`/`setVoice` fix over `setLanguage` (see `pronunciation_service.dart`'s
      `_ensureIosVoices`) after an initial swap on iPhone 11 Pro.
- [x] **AC-4** On device: the row's height and the horizontal position of the existing lightning
      icon and dots button are **unchanged** from before this task — restored to the letter of the
      original wording once the flags moved into the row's existing top strip (see step 2's note);
      the row never grows, with or without a translation. Confirmed through the placement
      iterations above.
- [ ] **AC-5** On device: tap the speaker twice in quick succession — the second tap interrupts the
      first. No two voices at once, no queue that keeps playing after you stop tapping. **Not
      explicitly checked.**
- [ ] **AC-6** On device: start playback and immediately background the app — audio stops and does
      not resume on return. **Not explicitly checked** — `didChangeAppLifecycleState(paused)` calls
      `pronunciationServiceProvider.stop()`, same call path as the flush-on-pause fix from task-03.
- [ ] **AC-7** On device: start playback and immediately delete that row — audio stops, no crash,
      no exception in the console. **Not explicitly checked** — `_removeItem` calls
      `pronunciationServiceProvider.stop()` unconditionally before removing.
- [ ] **AC-8** On device with airplane mode on: the behaviour matches the D1 choice. On-device TTS
      still speaks. **Not explicitly checked**, but expected to hold — on-device TTS has no network
      dependency.
- [ ] **AC-9** On device: a word with no entry in the chosen source (try a nonsense string like
      `zzzqx`, and a multi-word phrase like `pull through`) produces either speech or an explicit
      "no audio" message. It must not fail silently. **Not explicitly checked**, but expected to
      hold — on-device TTS always attempts to speak whatever text it's given, there's no "no entry"
      state for this source (see D1's table in docs/roadmap.md).
- [ ] **AC-10** The exported AnkiDroid file is byte-identical to what it was before this task for
      the same word list. **Not explicitly checked**, but the export path was not touched by this
      task.
