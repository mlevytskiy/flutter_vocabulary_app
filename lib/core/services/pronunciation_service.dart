import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'openai_voice_service.dart';
import 'voice_player.dart';

enum Accent { uk, us }

/// A text-to-speech voice as `setVoice` takes it: name and locale.
typedef VoiceId = ({String name, String locale});

/// How good an installed voice sounds (learn-redesign AC-30): iOS's
/// premium / enhanced / default, Android's very high / high / the rest.
enum VoiceQuality {
  premium,
  enhanced,
  standard;

  /// The AI voice picker's label.
  String get label => switch (this) {
        VoiceQuality.premium => 'Premium',
        VoiceQuality.enhanced => 'Enhanced',
        VoiceQuality.standard => 'Standard',
      };

  static VoiceQuality parse(String? quality) => switch (quality) {
        'premium' || 'very high' => VoiceQuality.premium,
        'enhanced' || 'high' => VoiceQuality.enhanced,
        _ => VoiceQuality.standard,
      };
}

/// One installed English voice, as `getVoices` lists it.
class TtsVoice {
  const TtsVoice({
    required this.name,
    required this.locale,
    required this.quality,
    this.networkRequired = false,
  });

  final String name;

  /// A language tag such as `en-US`.
  final String locale;
  final VoiceQuality quality;

  /// Android voices that only speak online.
  final bool networkRequired;

  VoiceId get id => (name: name, locale: locale);
}

/// The installed English voices of `getVoices` [raw], best first (AC-30):
/// offline before online (Android), then premium, enhanced, standard, then
/// en-US, en-GB, the other English locales. Leaves out Android voices not
/// installed and iOS's novelty voices (Bells, Zarvox…).
List<TtsVoice> rankEnglishVoices(List<dynamic> raw) {
  final voices = <TtsVoice>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final name = entry['name'];
    final locale = entry['locale'];
    if (name is! String || locale is! String) continue;
    final tag = locale.replaceAll('_', '-');
    if (!tag.toLowerCase().startsWith('en')) continue;
    final features = entry['features'];
    if (features is String && features.split('\t').contains('notInstalled')) continue;
    final identifier = entry['identifier'];
    if (identifier is String && identifier.contains('speech.synthesis.voice')) continue;
    voices.add(TtsVoice(
      name: name,
      locale: tag,
      quality: VoiceQuality.parse(entry['quality'] as String?),
      networkRequired: entry['network_required'] == '1',
    ));
  }
  int localeRank(String l) => switch (l) { 'en-US' => 0, 'en-GB' => 1, _ => 2 };
  voices.sort((a, b) {
    if (a.networkRequired != b.networkRequired) return a.networkRequired ? 1 : -1;
    final q = a.quality.index.compareTo(b.quality.index);
    if (q != 0) return q;
    final l = localeRank(a.locale).compareTo(localeRank(b.locale));
    if (l != 0) return l;
    return a.name.compareTo(b.name);
  });
  return voices;
}

/// The best of [ranked] for [locale] (e.g. `en-GB`); null when none.
TtsVoice? bestVoiceFor(List<TtsVoice> ranked, String locale) =>
    ranked.where((v) => v.locale == locale).firstOrNull;

/// Learn settings' voice for Talk with AI (openai-voice, AC-31): the
/// source and, for [VoiceSource.openAi], which OpenAI voice.
typedef TalkVoiceChoice = ({VoiceSource source, String openAiVoice});

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
///
/// Talk with AI's lines ([speakAndWait]) can instead be spoken by OpenAI's
/// natural voice through the Worker (openai-voice, owner 2026-10-24; AC-31),
/// when [voiceChoice] says so; the phone voice speaks any line OpenAI fails.
class PronunciationService {
  PronunciationService({
    FlutterTts? tts,
    OpenAiVoiceService? openAi,
    VoicePlayer? player,
    Future<TalkVoiceChoice> Function()? voiceChoice,
  })  : _tts = tts ?? FlutterTts(),
        _openAi = openAi,
        _player = player,
        _voiceChoice = voiceChoice;

  final FlutterTts _tts;
  final OpenAiVoiceService? _openAi;
  final VoicePlayer? _player;
  final Future<TalkVoiceChoice> Function()? _voiceChoice;

  /// Moves on with every [speakAndWait] and [stop]: a line whose turn has
  /// passed is not played (nor spoken by the phone) once its audio arrives.
  int _line = 0;
  bool _iosSessionConfigured = false;
  Map<Accent, Map<String, String>>? _iosVoiceByAccent;
  List<TtsVoice>? _english;

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
    await _applyIosPlayback();
  }

  /// Sets the playback category. Talk's speech recognizer leaves the session
  /// in play-and-record, where iOS can send speech to the quiet earpiece, so
  /// [speakAndWait] sets it again before every line (AC-29).
  Future<void> _applyIosPlayback() async {
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
    // The best-quality installed voice per accent (AC-30).
    final ranked = await _englishVoices();
    final byAccent = <Accent, Map<String, String>>{};
    for (final accent in Accent.values) {
      final best = bestVoiceFor(ranked, _localeFor[accent]!);
      if (best != null) byAccent[accent] = {'name': best.name, 'locale': best.locale};
    }
    _iosVoiceByAccent = byAccent;
  }

  Future<List<TtsVoice>> _englishVoices() async =>
      _english ??= rankEnglishVoices(await _tts.getVoices as List<dynamic>);

  /// The installed English voices, best first, for the AI voice picker
  /// (AC-30); empty when the phone lists none.
  Future<List<TtsVoice>> englishVoices() async {
    try {
      return await _englishVoices();
    } catch (_) {
      return const [];
    }
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

  /// Speaks [text] and completes once it was spoken, stopped or failed
  /// (Talk's hands-free loop, AC-29: it listens only after this).
  ///
  /// OpenAI's voice speaks it when Learn settings say so, or with
  /// [openAiVoice] when given (Play sample): a text over 1200 characters in
  /// sentence chunks one after another, and from the first chunk OpenAI
  /// fails on (no key, offline, day limit, playback) the phone voice speaks
  /// the rest (AC-31). The phone voice is [voice] when given, else the best
  /// installed voice of [accent] (AC-30). [onProgress] gets how much of
  /// [text] was spoken, 0 to 1, from either voice.
  Future<void> speakAndWait(
    String text, {
    required Accent accent,
    VoiceId? voice,
    String? openAiVoice,
    void Function(double progress)? onProgress,
  }) async {
    final line = ++_line;
    await _player?.stop();
    final openAiVoiceToUse = openAiVoice ?? await _openAiVoiceFromSettings();
    if (line != _line) return;
    var rest = text;
    var report = onProgress;
    final (openAi, player) = (_openAi, _player);
    if (openAiVoiceToUse != null && openAi != null && player != null) {
      final chunks = splitForSpeech(text);
      final total = chunks.fold<int>(0, (n, c) => n + c.length);
      var before = 0;
      var i = 0;
      try {
        for (; i < chunks.length; i++) {
          final chunk = chunks[i];
          final mp3 = await openAi.synthesize(chunk, openAiVoiceToUse);
          if (line != _line) return;
          final at = before;
          final outer = onProgress;
          await player.play(mp3, onProgress: outer == null ? null : (p) => outer((at + p * chunk.length) / total));
          if (line != _line) return;
          before += chunk.length;
        }
        return;
      } catch (e) {
        if (line != _line) return;
        debugPrint('openai voice: falling back to the phone voice ($e)');
        rest = chunks.sublist(i).join(' ');
        final spoken = before / total;
        final outer = onProgress;
        if (outer != null && spoken > 0) report = (p) => outer(spoken + p * (1 - spoken));
      }
    }
    await _speakWithPhone(rest, accent: accent, voice: voice, onProgress: report);
  }

  /// The OpenAI voice Learn settings picked, or null for the phone voice.
  Future<String?> _openAiVoiceFromSettings() async {
    final choice = _voiceChoice;
    if (choice == null) return null;
    try {
      final c = await choice();
      return c.source == VoiceSource.openAi ? c.openAiVoice : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _speakWithPhone(String text,
      {required Accent accent, VoiceId? voice, void Function(double progress)? onProgress}) async {
    try {
      if (Platform.isIOS) {
        await _applyIosPlayback();
      }
      await _tts.stop();
      final chosen = voice ?? bestVoiceFor(await englishVoices(), _localeFor[accent]!)?.id;
      if (chosen != null) {
        await _tts.setVoice({'name': chosen.name, 'locale': chosen.locale});
      } else {
        await _tts.setLanguage(_localeFor[accent]!);
      }
      final done = Completer<void>();
      var ended = false;
      void finish() {
        if (!done.isCompleted) done.complete();
      }

      _tts.setCompletionHandler(() {
        ended = true;
        finish();
      });
      _tts.setCancelHandler(finish);
      _tts.setErrorHandler((_) => finish());
      _tts.setProgressHandler((spoken, start, end, word) {
        if (onProgress != null && spoken.isNotEmpty) onProgress((end / spoken.length).clamp(0.0, 1.0));
      });
      final started = await _tts.speak(text);
      if (started != 1) finish();
      // A missed completion never leaves Talk waiting for good.
      await done.future.timeout(
          Duration(seconds: 10 + text.length ~/ 8), onTimeout: () {});
      if (ended) onProgress?.call(1.0);
    } catch (e) {
      throw PronunciationException('Could not speak: $e');
    }
  }

  /// Stops whatever is speaking, the phone voice or OpenAI's.
  Future<void> stop() async {
    _line++;
    await _player?.stop();
    await _tts.stop();
  }
}
