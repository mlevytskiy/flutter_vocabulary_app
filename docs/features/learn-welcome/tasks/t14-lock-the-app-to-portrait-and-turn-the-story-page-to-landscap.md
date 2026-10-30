---
id: T14
title: "Lock the app to portrait and turn the story page to landscape"
layer: "wiring"
deps: ["T13"]
acs: ["AC-11"]
files_hint: ["lib/app.dart", "lib/features/learn/flow/story_page.dart", "ios/Runner/Info.plist", "android/app/src/main/AndroidManifest.xml", "test/learn_orientation_test.dart"]
owner: "implementer agent"
estimate: "S"
status: "todo"
---

# T14 — Lock the app to portrait and turn the story page to landscape

## Why

Derives from [AC-11](../spec.md); see [ADR-0005](../adr/0005-lock-the-app-to-portrait-and-turn-only-the-story-page.md).

## What

App start, the story page, platform files.

## Definition of Done

- [ ] `SystemChrome.setPreferredOrientations([portraitUp])` at start; Info.plist keeps landscape entries so the story page can rotate; Android manifest without a fixed orientation
- [ ] story page sets landscape on show and portrait on leave; the pager keeps its index
- [ ] test with a mocked `SystemChannels.platform`
- [ ] device check on iPhone and Android
- [ ] `flutter analyze` clean

## Notes

—
