import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Plays the OpenAI voice's mp3 for Talk with AI (openai-voice, AC-31);
/// a fake in tests.
abstract class VoicePlayer {
  /// Plays [mp3] and completes when it ended or [stop] was called; throws
  /// when it cannot play. [onProgress] gets position over duration, 0 to 1,
  /// and 1 once the line played to its end.
  Future<void> play(Uint8List mp3, {void Function(double progress)? onProgress});

  Future<void> stop();
}

/// [VoicePlayer] on the `audioplayers` package (owner, 2026-10-24).
///
/// iOS: before each line the audio session is set to play-and-record with
/// the loudspeaker as the default route -- the category speech_to_text
/// records in, so Talk's recognizer can start right after without a
/// category switch, and speech never lands on the quiet earpiece. The
/// plugin deactivates the session once nothing plays, which leaves it free
/// for the recognizer. Android: speech content with a transient focus that
/// ducks other audio.
class AudioplayersVoicePlayer implements VoicePlayer {
  AudioPlayer? _player;
  Completer<void>? _playing;

  static final _context = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {
        AVAudioSessionOptions.defaultToSpeaker,
        AVAudioSessionOptions.allowBluetooth,
        AVAudioSessionOptions.allowBluetoothA2DP,
      },
    ),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  @override
  Future<void> play(Uint8List mp3, {void Function(double progress)? onProgress}) async {
    // One line at a time: a new one ends the one playing.
    await stop();
    final player = _player ??= AudioPlayer();
    await player.setAudioContext(_context);
    final done = _playing = Completer<void>();
    void finish([Object? error]) {
      if (done.isCompleted) return;
      error == null ? done.complete() : done.completeError(error);
    }

    var duration = Duration.zero;
    var ended = false;
    // A platform error reaches every stream made from the player's events.
    void failed(Object e) => finish(e);
    final subs = <StreamSubscription<dynamic>>[
      player.onDurationChanged.listen((d) => duration = d, onError: failed),
      player.onPositionChanged.listen((p) {
        if (onProgress != null && duration > Duration.zero) {
          onProgress((p.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0));
        }
      }, onError: failed),
      player.onPlayerComplete.listen((_) {
        ended = true;
        finish();
      }, onError: failed),
    ];
    try {
      await player.play(BytesSource(mp3, mimeType: 'audio/mpeg'));
      // A missed completion never leaves Talk waiting for good: mp3 speech
      // is well above 2 kB a second.
      await done.future.timeout(Duration(seconds: 10 + mp3.length ~/ 2000), onTimeout: () {});
    } finally {
      for (final s in subs) {
        await s.cancel();
      }
      if (identical(_playing, done)) _playing = null;
    }
    if (ended) onProgress?.call(1.0);
  }

  @override
  Future<void> stop() async {
    final playing = _playing;
    if (playing != null && !playing.isCompleted) playing.complete();
    await _player?.stop();
  }
}
