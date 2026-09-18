import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

enum Accent { uk, us }

class PronunciationException implements Exception {
  final String message;
  PronunciationException(this.message);

  @override
  String toString() => message;
}

/// Speaks a word using on-device text-to-speech (D1 in docs/roadmap.md) --
/// offline, no key, and UK/US is a property of the request (locale) rather
/// than of what some remote dictionary happens to hold. Wrapped behind this
/// service so the rest of the app never depends on the source choice.
class PronunciationService {
  final FlutterTts _tts = FlutterTts();
  bool _iosSessionConfigured = false;
  Map<Accent, Map<String, String>>? _iosVoiceByAccent;

  static const _localeFor = {
    Accent.uk: 'en-GB',
    Accent.us: 'en-US',
  };

  /// Without this, iOS plays TTS through the "ambient" audio session by
  /// default, which is silenced by the phone's mute switch -- the app looks
  /// like it worked (no exception) while nothing plays. `playback` ignores
  /// the mute switch, same as any other pronunciation/read-aloud app.
  Future<void> _ensureIosAudioSession() async {
    if (_iosSessionConfigured || !Platform.isIOS) return;
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.voicePrompt,
    );
    _iosSessionConfigured = true;
  }

  /// `setLanguage` alone is unreliable for GB vs. US on iOS -- it can leave
  /// the synthesizer's voice on whatever accent was last successfully
  /// resolved instead of switching, which shows up as "the flags are
  /// swapped". Looking the exact installed voice up via `getVoices` and
  /// selecting it with `setVoice` (name + locale, as the plugin's iOS side
  /// requires) is the reliable path. Built once and cached.
  Future<void> _ensureIosVoices() async {
    if (_iosVoiceByAccent != null || !Platform.isIOS) return;
    final voices = await _tts.getVoices as List<dynamic>;
    final byAccent = <Accent, Map<String, String>>{};
    for (final entry in voices) {
      final voice = Map<String, dynamic>.from(entry as Map);
      final locale = voice['locale'] as String?;
      final name = voice['name'] as String?;
      if (name == null) continue;
      for (final accent in Accent.values) {
        if (locale == _localeFor[accent] && !byAccent.containsKey(accent)) {
          byAccent[accent] = {'name': name, 'locale': locale!};
        }
      }
    }
    _iosVoiceByAccent = byAccent;
  }

  /// Stops whatever is currently playing (if anything) and speaks [word] in
  /// [accent]. A second call always interrupts the first -- there is no
  /// queue.
  Future<void> speak(String word, {required Accent accent}) async {
    try {
      await _ensureIosAudioSession();
      await _ensureIosVoices();
      await _tts.stop();
      final iosVoice = _iosVoiceByAccent?[accent];
      if (iosVoice != null) {
        await _tts.setVoice(iosVoice);
      } else {
        await _tts.setLanguage(_localeFor[accent]!);
      }
      await _tts.speak(word);
    } catch (e) {
      throw PronunciationException('Could not play pronunciation: $e');
    }
  }

  Future<void> stop() => _tts.stop();
}
