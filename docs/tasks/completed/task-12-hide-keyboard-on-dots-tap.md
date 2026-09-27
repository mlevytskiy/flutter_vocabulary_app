# Task 12 — Tapping the dots closes the keyboard

|  |  |
|---|---|
| **Roadmap step** | [#12](../../roadmap.md#steps) |
| **Size** | S (an hour, not a day) |
| **Wave** | 1 (after task-11 — same `word_input_screen.dart`) |
| **Depends on** | **task-11** (same file; this one is a two-line edit once 11 has landed) |
| **Blocked on** | — |
| **Unlocks** | task-13 (same file again) |
| **Files** | `lib/features/word_input/widgets/translation_dots_button.dart` · `lib/features/word_input/widgets/word_row_item.dart` · `lib/features/word_input/word_input_screen.dart` |
| **Status** | done — unfocus fires from `menuOnChange`(open) via a new `onOpen` callback threaded `screen → WordRowItem → TranslationDotsButton`. The "close icon doesn't work" half of the report is addressed separately: the close icon now calls a screen-owned `_closeTranslationOptions` handler, threaded as `onClose` the same way `onOpen` is, and picking a chip goes through that same handler — so the close path no longer depends on the popup package's outside-tap detection. Covered by `test/dots_popup_close_test.dart` (one controller per row, close icon hides the menu and the row's own handler fires) and `test/dots_close_race_test.dart` (the popup survives the keyboard dismissing right after the tap). Analyse clean, suite green. Needs an on-device pass for AC-2…AC-6, which a widget test cannot check.

**Note for whoever picks this up:** the popup package keeps its menu hit-rectangle in a library-level global that every open menu writes during layout. It is only sound with exactly one menu open, so the screen's one-controller-per-row rule is load-bearing, not tidiness. An early version of the close test shared a single controller across 14 rows and reproduced a dead close button that the app itself does not have. |

## The report

> We should hide keyboard when I click on 3 dots.

It is a real problem, not cosmetic: the popup opens anchored to the dots button in the lower part of
a row, and on a phone with the keyboard up the popup's body can be pushed into the strip between the
keyboard and the app bar, where `TranslationOptionsContent`'s `maxHeight: 420` and its
`SingleChildScrollView` have very little room left to work with.

## Why it needs a decision and not just a line

The mechanics are one call — `FocusManager.instance.primaryFocus?.unfocus()`, the same one
`_navigateToTableScreen` already makes at `word_input_screen.dart:677` for the same reason. What
needs deciding is **when**:

- The row's lightning icons are gated by Rule 0 of `docs/lightning_icon_rules.md` — "a lightning
  icon can only be visible while its row is in focus". Unfocusing hides both of that row's icons
  while the popup is open. That is arguably correct (the popup is the active surface), but it is a
  visible change to a documented rule and must not be discovered as a surprise.
- The dots button itself is **not** in that gate ("This gate does not apply to the Translation dots
  button — it is always rendered"), so the button stays put either way. Good.

**Decided here: unfocus on tap, before the popup opens.** It is what the owner asked for, it stops
the keyboard from competing with the popup for the bottom of the screen, and the icons returning on
the next focus of the row is the rule working as written.

## Prompt

Read `CLAUDE.md`, `docs/lightning_icon_rules.md` Rule 0, and `word_input_screen.dart:670-680` for
the existing unfocus-on-navigate pattern. One commit.

1. **Put the unfocus where the tap is owned.** `TranslationDotsButton` currently hands its tap
   straight to `popup_menu_2` (`pressType: PressType.singleClick`) and never sees a callback, so the
   screen cannot hook it. Add the unfocus at the screen's edge: pass an `onOpen` callback (or have
   the screen's `_selectTranslationOption`-style helper be the one place it happens) so the
   controller is popped at one predictable point rather than inside a widget that has no `ref`.
2. **Do it for the dots only.** The Translation lightning icon's tap must keep its focus — its own
   visibility rule depends on the row still being focused, and unfocusing after tapping it would
   hide the icon that was just tapped mid-load. Verify this explicitly.
3. **Keep `TranslationDotsButton` a `StatelessWidget` with no `ref`.** It takes callbacks today;
   keep it that way (rule 2, `docs/architecture.md`).
4. **Note the icon change in `docs/lightning_icon_rules.md`'s Changelog** — one entry saying that
   opening the popup drops the row's focus, and therefore hides that row's two lightning icons until
   the row is focused again. Do not rewrite Rule 0 itself.

## Acceptance criteria

- [ ] **AC-1** `flutter analyze` exits 0; `flutter test` passes; the three greps in `CLAUDE.md` are
      clean. (`build_runner` is not needed — no provider or model changes.)
- [ ] **AC-2** On device, keyboard up and the cursor in either field of a row: tapping that row's
      dots closes the keyboard and opens the popup in the same tap.
- [ ] **AC-3** On device: with the keyboard closed already, tapping the dots behaves exactly as
      before — a single tap still opens the popup (the added unfocus must not swallow the tap).
- [ ] **AC-4** On device: tapping the **Translation lightning** icon does **not** close the keyboard
      and does not hide the icon mid-request.
- [ ] **AC-5** On device, small phone (or a simulator with a small screen): with the keyboard up, the
      popup's chips are readable and reachable rather than squeezed into a sliver.
- [ ] **AC-6** On device: closing the popup and tapping back into the row restores focus and brings
      both lightning icons back per Rule 0.
