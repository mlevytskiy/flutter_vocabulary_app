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

  /// Hands-free listening (learn-redesign AC-29, owner 2026-10-24): listens
  /// until the learner has been quiet for [pause] after speaking, then stops
  /// and calls [onDone] with all the words heard. [onPartial] gets the words
  /// so far. When the engine stops by itself first (Android after 2–3 s of
  /// silence, a no-match error) it listens again and appends; with nothing
  /// heard for [UntilPause.nothingHeardLimit] it calls [onDone] with ''.
  /// Call [init] first.
  Future<void> listenUntilPause({
    required Duration pause,
    required void Function(String text) onPartial,
    required void Function(String text) onDone,
  });

  /// Ends [listenUntilPause] without calling its `onDone`.
  Future<void> stopListening();
}

/// The silence detection of [SpeechInput.listenUntilPause], shared by both
/// engines (AC-29): the engine feeds it the words of its current session
/// ([heard]) and tells it when that session ended by itself
/// ([sessionEnded]); it keeps the words of earlier sessions, restarts the
/// engine, and ends once [pause] passed with no new words.
class UntilPause {
  UntilPause({
    required this.pause,
    required this.onPartial,
    required this.onDone,
    required this.restart,
    required this.stopEngine,
    this.nothingHeardLimit = const Duration(seconds: 60),
    this.restartDelay = const Duration(milliseconds: 300),
  });

  final Duration pause;
  final void Function(String text) onPartial;
  final void Function(String text) onDone;

  /// Starts a new engine session after one ended by itself.
  final Future<void> Function() restart;

  /// Stops the engine once the pause has passed.
  final Future<void> Function() stopEngine;

  /// With no words at all for this long, [onDone] gets ''.
  final Duration nothingHeardLimit;

  /// A session's stop and its error come together: one restart for both.
  final Duration restartDelay;

  String _committed = '';
  String _current = '';
  bool _active = false;
  Timer? _pauseTimer;
  Timer? _nothingTimer;
  Timer? _restartTimer;

  bool get active => _active;

  /// All the words heard so far, earlier sessions first.
  String get text => [_committed, _current].where((s) => s.isNotEmpty).join(' ');

  void begin() {
    _active = true;
    _nothingTimer = Timer(nothingHeardLimit, () => _finish(''));
  }

  /// The engine's words for its current session.
  void heard(String sessionWords) {
    final words = sessionWords.trim();
    if (!_active || words == _current) return;
    _current = words;
    final all = text;
    onPartial(all);
    if (all.isEmpty) return;
    _nothingTimer?.cancel();
    _pauseTimer?.cancel();
    _pauseTimer = Timer(pause, () => _finish(text));
  }

  /// The engine stopped by itself before the pause passed: keep its words
  /// and listen again.
  void sessionEnded() {
    if (!_active) return;
    _committed = text;
    _current = '';
    if (_restartTimer?.isActive ?? false) return;
    _restartTimer = Timer(restartDelay, () {
      if (_active) restart();
    });
  }

  /// Ends without [onDone].
  void cancel() {
    _active = false;
    _pauseTimer?.cancel();
    _nothingTimer?.cancel();
    _restartTimer?.cancel();
  }

  void _finish(String words) {
    if (!_active) return;
    cancel();
    stopEngine();
    onDone(words);
  }
}

/// [SpeechInput] over the `speech_to_text` package (the default engine).
class SpeechToTextInput implements SpeechInput {
  SpeechToTextInput({this.onDevice = false});

  /// Recognise on the phone only, never on Apple's or Google's servers
  /// (owner, 2026-10-24). Off: the system may use its servers when online.
  final bool onDevice;

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
      return await speech.hasPermission ? SpeechAvailability.unavailable : SpeechAvailability.permissionDenied;
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
          onDevice: onDevice,
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

  UntilPause? _untilPause;

  /// Listens in sessions of up to 60 s whose own pause is a second longer
  /// than ours, so our pause ends first where the engine allows; Android
  /// ends a session after 2–3 s of silence, which restarts it (AC-29).
  @override
  Future<void> listenUntilPause({
    required Duration pause,
    required void Function(String text) onPartial,
    required void Function(String text) onDone,
  }) async {
    final speech = _speech;
    if (speech == null) {
      onDone('');
      return;
    }
    await stopListening();
    late final UntilPause run;
    Future<void> session() async {
      if (!run.active || speech.isListening) return;
      try {
        await speech.listen(
          onResult: (SpeechRecognitionResult r) {
            if (_untilPause == run) run.heard(r.recognizedWords);
          },
          listenOptions: SpeechListenOptions(
            partialResults: true,
            listenMode: ListenMode.dictation,
            localeId: 'en_US',
            onDevice: onDevice,
            pauseFor: pause + const Duration(seconds: 1),
            listenFor: const Duration(seconds: 60),
          ),
        );
      } catch (_) {
        // The pause or the 60 s limit still ends it.
      }
    }

    run = UntilPause(
      pause: pause,
      onPartial: onPartial,
      onDone: onDone,
      restart: session,
      stopEngine: () async {
        _untilPause = null;
        try {
          await speech.stop();
        } catch (_) {}
      },
    );
    _untilPause = run;
    speech.statusListener = (status) {
      if (_untilPause == run && status == SpeechToText.doneStatus) run.sessionEnded();
    };
    speech.errorListener = (_) {
      if (_untilPause == run) run.sessionEnded();
    };
    run.begin();
    await session();
  }

  @override
  Future<void> stopListening() async {
    final run = _untilPause;
    if (run == null) return;
    _untilPause = null;
    run.cancel();
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
      return await speech.hasPermission() ? SpeechAvailability.unavailable : SpeechAvailability.permissionDenied;
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

  UntilPause? _untilPause;
  StreamSubscription<SpeechTranscript>? _transcript;

  /// Listens in the package's continuous mode, whose recognizer restarts by
  /// itself after each silence and whose transcript keeps every segment;
  /// our [UntilPause] decides when the learner is done (AC-29).
  @override
  Future<void> listenUntilPause({
    required Duration pause,
    required void Function(String text) onPartial,
    required void Function(String text) onDone,
  }) async {
    final speech = _speech;
    if (speech == null || !_initialized) {
      onDone('');
      return;
    }
    await stopListening();
    late final UntilPause run;
    run = UntilPause(
      pause: pause,
      onPartial: onPartial,
      onDone: onDone,
      restart: () async {},
      stopEngine: () async {
        _untilPause = null;
        await _transcript?.cancel();
        _transcript = null;
        try {
          await speech.stop();
        } catch (_) {}
      },
    );
    _untilPause = run;
    _transcript = speech.onTranscriptUpdate.listen((t) {
      if (_untilPause == run) run.heard(t.fullText);
    });
    run.begin();
    try {
      await speech.start(localeId: 'en-US', continuous: true);
    } catch (_) {
      // The 60 s limit still ends it.
    }
  }

  @override
  Future<void> stopListening() async {
    final run = _untilPause;
    if (run == null) return;
    _untilPause = null;
    run.cancel();
    await _transcript?.cancel();
    _transcript = null;
    try {
      await _speech?.cancel();
    } catch (_) {}
  }
}
