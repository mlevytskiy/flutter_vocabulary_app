import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_pro/speech_to_text_pro.dart';

/// The speech recognition engine Talk with AI listens with, picked in Learn
/// settings (learn-redesign AC-28, ADR-0009 Amendment).
enum SpeechEngine {
  speechToText,
  speechToTextPro;

  /// The package's name, as the Learn settings radio shows it.
  String get label => switch (this) {
        SpeechEngine.speechToText => 'speech_to_text',
        SpeechEngine.speechToTextPro => 'speech_to_text_pro',
      };
}

/// What [SpeechInput.init] found: ready to listen, the microphone or speech
/// permission refused (AC-26), or no recognizer on the phone.
enum SpeechAvailability { ready, permissionDenied, unavailable }

/// Hold-to-talk speech input for Talk with AI (learn-redesign AC-25, AC-26,
/// ADR-0009). Implementations never throw to callers: failures come back as
/// [SpeechAvailability] from [init] or as no text.
abstract interface class SpeechInput {
  /// Prepares the recognizer (and on most phones asks for the permissions
  /// the first time). Safe to call more than once.
  Future<SpeechAvailability> init();

  /// Starts listening; [onText] gets the words heard so far, `isFinal` once
  /// the recognizer settles on them.
  Future<void> listen({required void Function(String text, bool isFinal) onText});

  /// Stops listening. Before it returns, [listen]'s `onText` has had the
  /// final text (`isFinal` true) when any words were heard.
  Future<void> stop();

  /// Stops listening and drops what was heard.
  Future<void> cancel();
}

/// [SpeechInput] over the `speech_to_text` package (the default engine).
class SpeechToTextInput implements SpeechInput {
  /// How long [stop] waits for the recognizer's final result before it
  /// settles on the last words heard.
  static const finalWait = Duration(milliseconds: 1200);

  SpeechToText? _speech;
  void Function(String text, bool isFinal)? _onText;
  String _heard = '';
  bool _final = false;
  Completer<void>? _finalSeen;

  @override
  Future<SpeechAvailability> init() async {
    try {
      final speech = _speech ??= SpeechToText();
      if (speech.isAvailable) return SpeechAvailability.ready;
      final ok = await speech.initialize(onError: (_) {}, onStatus: (_) {});
      if (ok) return SpeechAvailability.ready;
      return await speech.hasPermission
          ? SpeechAvailability.unavailable
          : SpeechAvailability.permissionDenied;
    } catch (_) {
      return SpeechAvailability.unavailable;
    }
  }

  @override
  Future<void> listen({required void Function(String text, bool isFinal) onText}) async {
    final speech = _speech;
    if (speech == null) return;
    _onText = onText;
    _heard = '';
    _final = false;
    final seen = _finalSeen = Completer<void>();
    try {
      await speech.listen(
        onResult: (SpeechRecognitionResult r) {
          if (_final) return;
          _heard = r.recognizedWords;
          if (r.finalResult) {
            _final = true;
            if (!seen.isCompleted) seen.complete();
          }
          onText(_heard, r.finalResult);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: 'en_US',
        ),
      );
    } catch (_) {
      _onText = null;
    }
  }

  @override
  Future<void> stop() async {
    final speech = _speech;
    final onText = _onText;
    if (speech == null || onText == null) return;
    try {
      await speech.stop();
      if (!_final) {
        await _finalSeen?.future.timeout(finalWait, onTimeout: () {});
      }
    } catch (_) {
      // Settle on what was heard.
    }
    if (!_final && _heard.isNotEmpty) {
      _final = true;
      onText(_heard, true);
    }
    _onText = null;
  }

  @override
  Future<void> cancel() async {
    _onText = null;
    try {
      await _speech?.cancel();
    } catch (_) {}
  }
}

/// [SpeechInput] over the `speech_to_text_pro` package (owner, 2026-10-24).
/// Its `stop()` drops the result listeners before the platform's final
/// result arrives, so [stop] settles on the last words heard.
class SpeechToTextProInput implements SpeechInput {
  SpeechToTextPro? _speech;
  bool _initialized = false;
  void Function(String text, bool isFinal)? _onText;
  String _heard = '';
  bool _final = false;

  @override
  Future<SpeechAvailability> init() async {
    try {
      final speech = _speech ??= SpeechToTextPro();
      if (_initialized) return SpeechAvailability.ready;
      // The permissions are asked on the first listen.
      if (await speech.initialize()) {
        _initialized = true;
        return SpeechAvailability.ready;
      }
      return await speech.hasPermission()
          ? SpeechAvailability.unavailable
          : SpeechAvailability.permissionDenied;
    } catch (_) {
      return SpeechAvailability.unavailable;
    }
  }

  @override
  Future<void> listen({required void Function(String text, bool isFinal) onText}) async {
    final speech = _speech;
    if (speech == null || !_initialized) return;
    _onText = onText;
    _heard = '';
    _final = false;
    try {
      await speech.listen(
        onResult: (SpeechResult r) {
          if (_final) return;
          _heard = r.text;
          if (r.isFinal) _final = true;
          onText(_heard, r.isFinal);
        },
        localeId: 'en-US',
      );
    } catch (_) {
      _onText = null;
    }
  }

  @override
  Future<void> stop() async {
    final speech = _speech;
    final onText = _onText;
    if (speech == null || onText == null) return;
    try {
      await speech.stop();
    } catch (_) {}
    if (!_final && _heard.isNotEmpty) {
      _final = true;
      onText(_heard, true);
    }
    _onText = null;
  }

  @override
  Future<void> cancel() async {
    _onText = null;
    try {
      await _speech?.cancel();
    } catch (_) {}
  }
}
