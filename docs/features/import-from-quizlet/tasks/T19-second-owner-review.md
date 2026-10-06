---
id: T19
title: "Apply the second owner review: link field style, back side to the right field, captions icon, Settings button with the SnackBar"
layer: "ui"
deps: ["T18"]
acs: ["AC-01", "AC-02", "AC-09", "AC-17"]
files_hint: ["lib/features/word_input/widgets/quizlet_link_dialog.dart", "lib/features/word_input/widgets/quizlet_link_how_to.dart", "lib/core/services/quizlet_cards.dart", "lib/features/word_input/quizlet_import_flow.dart", "lib/features/word_input/widgets/word_input_speed_dial.dart", "lib/features/settings/settings_screen.dart", "lib/core/providers.dart", "lib/features/word_input/word_input_screen.dart"]
owner: "Maksym"
estimate: "S"
status: "done"
---

# T19 — Apply the second owner review (2026-10-06)

## What

1. Link dialog: the field is styled like the Word and Translation fields (outline border, light resting label, 12/16 padding, bodyLarge); the how-to sketch is 130 px instead of 150 (first 110, raised a little on the owner's request); the dialog's insets and paddings are tighter; its content scrolls from the bottom, so with the keyboard up the field stays in sight and the animation scrolls away above it.
2. No machine translation. `backIsTranslation`: a back whose letters are at least half Cyrillic is a Ukrainian translation and goes into the translation; any other back goes into the definition; the example always into the definition; every other field empty (null, so the results dialog shows no line for it). The translate step and `quizletTranslateConcurrency` are gone from `quizlet_import_flow.dart`.
3. "From subtitles" keeps `Icons.closed_caption`; the Settings icon picker, `SubtitlesIcon` and `subtitlesIconProvider` are removed (a stored `subtitles_icon` value is simply ignored).
4. The Settings button and the SnackBar: the button was a `Positioned` in the body, which the Scaffold does not move, while the speed dial is the Scaffold's floating action button, which it lifts above a SnackBar — so the SnackBar covered Settings and the two buttons left their shared line. Both now sit in the floating-button slot (a centred row as wide as the screen less 16 px margins), so they move together and keep their old places.

## Definition of Done

- [x] widget tests: field style and the field in sight with the keyboard up on a 375×667 screen; back side rules and no translation call; captions icon; both buttons on one line above a SnackBar
- [x] `flutter test` passes, `flutter analyze` shows no new issue
- [ ] checked on the owner's phones (T17)
