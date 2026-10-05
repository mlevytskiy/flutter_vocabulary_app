# Tracker — photo-from-gallery

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Turn on the Android Photo Picker for gallery picks](./T1-turn-on-android-photo-picker.md) | wiring | Maksym | S | — | todo |
| T2 | [Read the image picker and the photo scaler through providers in the photo chain](./T2-picker-and-scaler-through-providers.md) | wiring | Maksym | S | — | todo |
| T3 | [Add the Camera/Gallery source choice dialog](./T3-photo-source-dialog.md) | ui | Maksym | S | — | todo |
| T4 | [Open the source choice from Get words from photo, behind the one-import-at-a-time guard](./T4-source-choice-and-one-import-guard.md) | ui | Maksym | S | T2, T3 | todo |
| T5 | [Pick one photo from the gallery and run it through the shared photo chain with gallery failure texts](./T5-gallery-pick-and-failure-texts.md) | app | Maksym | M | T4 | todo |
| T6 | [Run the device pass for the spec §6 targets on one iPhone and one Android phone](./T6-device-pass.md) | tests | Maksym | M | T1, T5 | todo |

**Total:** 6 tasks, ~2 person-days (S ≈ ¼ day, M ≈ ½ day; T6 also needs both phones).
