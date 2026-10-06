---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-10-06"
feature_size: "M"
ticket: "import-from-quizlet"
---

# 0002 — Show the set page with webview_flutter

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

The set's page must open inside the app, behind a progress dialog with a small live preview that grows to full size for Quizlet's own robot check (AC-02, AC-05). The app must refuse to open any page that is not Quizlet's own (AC-11) and must run its own script on the page to read the cards. The app has no web view today; exactly one new package is approved for this (spec §1 decision, CLAUDE.md rule 5).

## Decision drivers

- sad §1 quality goal 2 (contain the third-party page): a hook before every top-level navigation that can cancel it; no new windows.
- sad §1 quality goal 1: run a script on the page and get its result back as a string.
- The preview is a widget inside a dialog that can change size (AC-05).
- One owner maintains the app: a package that keeps pace with Flutter releases, with a small API.
- spec §6: no new device permissions.

## Considered options

1. **`webview_flutter`** (flutter.dev) — `NavigationDelegate` (`onNavigationRequest`, `onPageStarted`, `onPageFinished`, `onWebResourceError`, `onUrlChange`), `runJavaScriptReturningResult`, a plain widget; `window.open` opens nothing by default.
2. **`flutter_inappwebview`** — a larger API: navigation hooks for every frame, content blockers, user scripts at document start, JavaScript handlers.

## Decision outcome

**Chosen:** Option 1. It covers every need of AC-02, AC-05, AC-07 and AC-11 with the smallest surface and is maintained alongside Flutter. Option 2's extra power (blocking sub-frames and requests) is exactly what sad ADR-0004 decided not to use, because blocking sub-frames risks breaking Quizlet's own robot check.

## Consequences

**Positive**
- Small, stable API; platform implementations (`webview_flutter_android`, `webview_flutter_wkwebview`) come transitively.
- Uses the system web view; no new permission (network access is already granted).

**Negative**
- No request filtering: adverts and third-party scripts load inside the preview (acceptable: they cannot navigate the top-level page away from Quizlet — ADR-0004).
- No document-start scripts: the reader runs after load and polls (sad §4 tactical decision).

**Neutral**
- Switching to `flutter_inappwebview` later rewrites the progress dialog and the reader host (~2–3 days); the Dart parser (ADR-0003) is unaffected.
- CLAUDE.md rule 5 and `docs/architecture.md` rule 6 list the package once it lands.

## Links

- Spec: [[../spec.md]] §1 decision (one web-view package), AC-02, AC-05, AC-11
- SAD: [[../sad.md]] §2, §4
- Related ADR: [[0003-read-the-page-data-with-a-thin-script-and-parse-it-in-dart]], [[0004-allow-only-quizlet-pages-of-the-pasted-set-in-the-web-view]]
