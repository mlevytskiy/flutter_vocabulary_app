---
id: T10
title: "Build the progress dialog that loads and reads the set in a web view"
layer: "ui"
deps: ["T6", "T7"]
acs: ["AC-02", "AC-05", "AC-07", "AC-07b", "AC-11"]
files_hint: ["lib/features/word_input/widgets/quizlet_progress_dialog.dart", "test/quizlet_progress_dialog_test.dart", "pubspec.yaml", "pubspec.lock", "docs/architecture.md"]
owner: "Maksym"
estimate: "L"
status: "todo"
---

# T10 — Build the progress dialog that loads and reads the set in a web view

## Why

[ADR-0002](../adr/0002-show-the-set-page-with-webview-flutter.md), [ADR-0004](../adr/0004-allow-only-quizlet-pages-of-the-pasted-set-in-the-web-view.md); spec AC-02, AC-05, AC-07, AC-07b, AC-11; [sad §4](../sad.md) waiting; [sad §6 F2](../sad.md); [sad §8](../sad.md) web view boundary.

## What

- `flutter pub add webview_flutter`.
- `WebViewController` + `NavigationDelegate` in `State`: `onNavigationRequest` uses T6's predicate; JavaScript on, **no `JavaScriptChannel`**; poll `runJavaScriptReturningResult(readerScript)` about once a second and feed T7's parser.
- Timers: 30 s to first load, 30 s for cards, both paused while the parser reports a robot check; preview small ↔ full size.
- Keep the timing and decision logic in a small controller class so it is testable without a real web view.
- `QUIZLET:` debugPrint lines with no card text (sad §7).

## Definition of Done

**Done when:** The dialog shows "Reading the Quizlet set…", the name once known and a small live preview; it refuses non-allowed navigations and new windows, ends with a failure on a load error, no first load within 30 s, or 30 s after load without cards (time paused and preview full size while a robot check is shown), returns the parsed set on success and a cancel on Cancel/Back; `webview_flutter` is added and listed in `docs/architecture.md` rule 6; logic tested with a fake page driver.

- [ ] controller tests pass with a fake page (load error, no load in 30 s, robot check pauses, cards found, other set id ignored, cancel)
- [ ] `flutter analyze` clean
- [ ] on a device, the preview shows the owner's example set

## Notes

- Largest task; if it runs past a day, split the controller (timers and decisions) from the widget. No new permission may be added (spec §6).
