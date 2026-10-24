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

## Amendment (owner, 2026-10-24, hands-free)

The owner asked for hands-free talk. `SpeechInput` gets `listenUntilPause(pause, onPartial, onDone)` and `stopListening()` in both engines; the silence detection is ours (`UntilPause`, shared): a timer reset by each new word ends listening after the learner's pause (2/3/4/6 s, `learn.pauseSeconds`, default 4); a session the engine ends by itself is restarted and its words kept; 60 s with nothing heard ends with no text. `speech_to_text` listens in dictation sessions of up to 60 s whose own pause is ours plus 1 s; `speech_to_text_pro` uses its continuous mode (the recognizer restarts by itself). `PronunciationService.speakAndWait` completes once a line was spoken, so the app never listens while speaking, and re-sets the iOS playback category before every line so speech plays through the speaker after recording. It picks the best installed voice (premium > enhanced > standard; offline first on Android) unless the learner chose one in Learn settings (`learn.ttsVoice`). Hands-free is on by default (`learn.handsFree`). No new packages (AC-29, AC-30).
