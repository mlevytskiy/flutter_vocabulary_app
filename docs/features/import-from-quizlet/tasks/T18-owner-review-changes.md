---
id: T18
title: "Apply the owner review: Include photos, + menu icons, link how-to, cards pager, photo source cards"
layer: "ui"
deps: ["T13", "T14"]
acs: ["AC-01", "AC-02", "AC-05", "AC-12", "AC-15"]
files_hint: ["lib/features/words_table/words_table_screen.dart", "lib/core/providers.dart", "lib/features/settings/settings_screen.dart", "lib/features/word_input/widgets/word_input_speed_dial.dart", "lib/features/word_input/widgets/quizlet_logo_icon.dart", "lib/features/word_input/widgets/quizlet_link_dialog.dart", "lib/features/word_input/widgets/quizlet_link_how_to.dart", "lib/features/word_input/widgets/quizlet_progress_dialog.dart", "lib/features/word_input/widgets/photo_source_dialog.dart"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T18 — Apply the owner review (2026-10-06)

## Why

The owner's review of the built feature (spec §1 "owner review" decisions). It supersedes part of T14 (the "Include sources" switch) and changes what T10 and T9 show.

## What

1. Words screen: back to "Include photos (N)", counting and hiding photos only; a set source with a remaining row is always sent, without asking; a session whose only sources are sets shows no switch (AC-12, AC-15).
2. + menu: "From subtitles" dark grey instead of orange; its icon is picked in Settings from film, film strip, film reel, clapper, TV, captions and subtitles (film by default), kept as the `subtitles_icon` preference (`subtitlesIconProvider`). *(T19: fixed to captions, the picker removed.)*
3. + menu: "Import from Quizlet" shows a painted white Quizlet-like "Q" (`QuizletLogoIcon`) instead of `Icons.style`.
4. Link dialog: a how-to animation above the field — a sketched set page, a finger tapping Share, then Copy link, "Link copied", a pointer down to the field, each step named under it; plays three times, a tap replays it, text in the field stops it (`QuizletLinkHowTo`).
5. Progress dialog: a pager of skeleton cards under a skeleton title for at least 1 s; then the set's name and its cards (term, back side), scrolled from the first to the last in 2 s, alongside the translations; the dialog closes when both are done. The web view stays loaded under the pager at the same size; only the robot check shows it, full size (AC-02, AC-05).
6. "Get words from photo" dialog: "Photos" instead of "Gallery"; Camera and Photos as two bordered cards side by side, each an icon above its name.

## Definition of Done

**Done when:** each of the six changes is in the app and covered by widget tests (words table, settings, speed dial, link dialog animation, progress dialog skeleton → cards → scroll → close and robot check, photo source dialog), and the spec, ux-flows, sad, CONTEXT and `docs/architecture.md` describe them.

- [x] `flutter test` passes (381 tests)
- [x] `flutter analyze` shows no new issue
- [ ] device look checked by the owner (T17)

**Note for T17:** the time to the results dialog now includes the skeleton second and the 2 s scroll (the scroll overlaps the translations), so the p95 ≤ 10 s target has up to about 3 s less headroom.
