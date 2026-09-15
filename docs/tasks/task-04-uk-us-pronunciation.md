# Task 04 — Hear a word in UK and US pronunciation

|  |  |
|---|---|
| **Roadmap step** | [#4](../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 3 (parallel with task-05 and task-08 — disjoint file sets) |
| **Depends on** | — |
| **Blocked on** | **D1** — which UK/US pronunciation source |
| **Files** | `lib/widgets/synced_text_field_row.dart` · `lib/services/` (new) · `lib/screens/word_input_screen.dart` (the row's suffix-icon slot) · `pubspec.yaml` |
| **Status** | not started |

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
2. **Add the trigger to the row.** `SyncedTextFieldRow` already takes `leftSuffixIcon` /
   `rightSuffixIcon` (`lib/widgets/synced_text_field_row.dart:61-62`), and
   `lib/screens/word_input_screen.dart` already puts the lightning icon and the dots button in
   those slots — so there is a real layout constraint here: the Word field's suffix area is
   occupied and the dots are 22px wide by design so toggling their state "never shifts the row's
   layout" (see `_buildTranslationDotsButton`'s comment). Two more always-visible buttons will not
   fit. Recommended: a **single speaker icon** that plays the primary accent on tap and opens a
   UK/US choice on long-press, or a speaker that plays UK then US in sequence. Do not grow the row.
   Whatever you choose, follow `docs/lightning_icon_rules.md`'s in-focus rule — icons in this row
   only show while the row has focus, and breaking that pattern for one icon will look like a bug.
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

- [ ] **AC-1** `flutter analyze` exits 0.
- [ ] **AC-2** On device: the speaker affordance is visible on a focused row with a 2+ character
      word, and absent when the Word field is empty or holds one character.
- [ ] **AC-3** On device, with earphones or speaker on: a word plays in British pronunciation and
      in American pronunciation, and the two are audibly different for a word where the accents
      diverge (`schedule`, `either`, `tomato`, `advertisement`).
- [ ] **AC-4** On device: the row's height and the horizontal position of the existing lightning
      icon and dots button are **unchanged** from before this task. Compare screenshots of the same
      row before and after; the row must not have grown or shifted.
- [ ] **AC-5** On device: tap the speaker twice in quick succession — the second tap interrupts the
      first. No two voices at once, no queue that keeps playing after you stop tapping.
- [ ] **AC-6** On device: start playback and immediately background the app — audio stops and does
      not resume on return.
- [ ] **AC-7** On device: start playback and immediately delete that row — audio stops, no crash,
      no exception in the console.
- [ ] **AC-8** On device with airplane mode on: the behaviour matches the D1 choice. On-device TTS
      still speaks. A network source shows a clear "couldn't load audio" message — never an
      indefinite spinner and never a silent no-op.
- [ ] **AC-9** On device: a word with no entry in the chosen source (try a nonsense string like
      `zzzqx`, and a multi-word phrase like `pull through`) produces either speech or an explicit
      "no audio" message. It must not fail silently.
- [ ] **AC-10** The exported AnkiDroid file is byte-identical to what it was before this task for
      the same word list.
