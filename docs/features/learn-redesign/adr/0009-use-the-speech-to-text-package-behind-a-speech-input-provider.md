---
status: Accepted
owner: "Architect"
reviewers: ["Tech Lead"]
updated_at: "2026-10-23"
feature_size: "L"
ticket: "learn-redesign"
---

# 0009 — Use the speech_to_text package behind a speech input provider

- **Status:** Accepted
- **Date:** 2026-10-23
- **Deciders:** Architect (Claude Opus 5.5), Fable 5.1 owner proxy

## Context

V3 needs on-device speech recognition on iOS and Android; the owner approved a package or native code.

## Decision drivers

- rule 5 approval for speech-to-text
- AC-25, AC-26
- testability without devices

## Considered options

1. `speech_to_text` pinned, behind `speechInputProvider` (chosen)
2. Native platform channels in Swift/Kotlin (SFSpeechRecognizer / SpeechRecognizer)

## Decision outcome

Chosen: option 1. Add `speech_to_text` at one exact version (latest stable at least two weeks old that resolves with the current SDK). `SpeechInput` interface (`available()`, `listen(onFinal)`, `stop()`, permission state) with a real implementation and a fake for tests. Speaking replies reuses `PronunciationService` (flutter_tts).

## Consequences

- + least code, both platforms
- − one new dependency and platform permission strings
- − recognition quality depends on the phone

## Amendment (owner, 2026-10-24)

The owner asked for a second engine, `speech_to_text_pro` (0.0.1, MIT, verified publisher shirsh.dev, Android SpeechRecognizer / iOS SFSpeechRecognizer, published ~3 months before), and a choice in Learn settings. `SpeechInput` gets two implementations — `SpeechToTextInput` and `SpeechToTextProInput` — and `speechInputProvider` returns the one named by a persisted `SpeechEngine` preference (`speechToText` default, `speechToTextPro`). Both packages are pinned to exact versions. Because 0.0.1 is the only release, the default stays `speech_to_text`.
