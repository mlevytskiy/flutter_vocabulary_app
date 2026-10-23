---
id: T19
layer: wiring
deps: ["T18"]
acs: ["AC-25", "AC-26"]
estimate: M
owner: "implementer agent"
status: todo
---

# T19 — Add speech_to_text behind speechInputProvider, hold-to-talk and spoken replies

**Derives from:** [spec](../spec.md) AC-25, AC-26 · [sad](../sad.md) §5.1 · [screens](../screens.md)

## Definition of Done

pubspec pins speech_to_text at one exact version; iOS Info.plist and Android manifest permissions added; widget tests with a fake SpeechInput: hold → final text sent, reply spoken via PronunciationService, refused permission → message and typing still works, mic hidden when unavailable; flutter analyze clean

## Files

- `pubspec.yaml`
- `lib/core/services/speech_input.dart`
- `lib/core/providers.dart`
- `lib/features/learn/talk/talk_screen.dart`
- `ios/Runner/Info.plist`
- `android/app/src/main/AndroidManifest.xml`
- `test/learn_session/talk_voice_test.dart`
