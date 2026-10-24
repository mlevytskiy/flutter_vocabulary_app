import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:flutter_vocabulary_app/core/services/openai_voice_service.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/core/services/voice_player.dart';

/// The phone's text to speech: speaks at once, reports the progress of the
/// whole text, then completes.
class PhoneTts extends Fake implements FlutterTts {
  final spoken = <String>[];
  VoidCallback? _done;
  ProgressHandler? _progress;

  @override
  Future<dynamic> stop() async => 1;
  @override
  Future<dynamic> setVoice(Map<String, String> voice) async => 1;
  @override
  Future<dynamic> setLanguage(String language) async => 1;
  @override
  Future<dynamic> get getVoices async => const <dynamic>[];
  @override
  void setCompletionHandler(VoidCallback callback) => _done = callback;
  @override
  void setCancelHandler(VoidCallback callback) {}
  @override
  void setErrorHandler(ErrorHandler handler) {}
  @override
  void setProgressHandler(ProgressHandler callback) => _progress = callback;
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    scheduleMicrotask(() {
      _progress?.call(text, 0, text.length ~/ 2, 'x');
      _done?.call();
    });
    return 1;
  }
}

class FakeOpenAi implements OpenAiVoiceService {
  final asked = <(String, String)>[];
  OpenAiVoiceException? error;

  /// Fails only from this call on (0-based), when set.
  int failFrom = 0;

  @override
  Future<Uint8List> synthesize(String text, String voice) async {
    asked.add((text, voice));
    if (error != null && asked.length > failFrom) throw error!;
    return Uint8List.fromList(text.codeUnits.take(4).toList());
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakePlayer implements VoicePlayer {
  final played = <Uint8List>[];
  bool fail = false;
  Completer<void>? hold;
  int stops = 0;

  @override
  Future<void> play(Uint8List mp3, {void Function(double progress)? onProgress}) async {
    played.add(mp3);
    if (fail) throw Exception('cannot play');
    onProgress?.call(0.5);
    if (hold != null) await hold!.future;
    onProgress?.call(1.0);
  }

  @override
  Future<void> stop() async {
    stops++;
    final h = hold;
    if (h != null && !h.isCompleted) h.complete();
  }
}

void main() {
  late PhoneTts phone;
  late FakeOpenAi openAi;
  late FakePlayer player;
  var choice = (source: VoiceSource.openAi, openAiVoice: 'sage');

  PronunciationService service() => PronunciationService(
        tts: phone,
        openAi: openAi,
        player: player,
        voiceChoice: () async => choice,
      );

  setUp(() {
    phone = PhoneTts();
    openAi = FakeOpenAi();
    player = FakePlayer();
    choice = (source: VoiceSource.openAi, openAiVoice: 'sage');
  });

  test('AC-31: with the OpenAI source a line is synthesized with the picked voice and played', () async {
    await service().speakAndWait('Do you like the sea?', accent: Accent.us);
    expect(openAi.asked, [('Do you like the sea?', 'sage')]);
    expect(player.played, hasLength(1));
    expect(phone.spoken, isEmpty);
  });

  test('with the phone source the phone speaks and OpenAI is never asked', () async {
    choice = (source: VoiceSource.phone, openAiVoice: 'sage');
    await service().speakAndWait('Hello.', accent: Accent.us);
    expect(openAi.asked, isEmpty);
    expect(phone.spoken, ['Hello.']);
  });

  test('a service without a voice choice speaks with the phone', () async {
    await PronunciationService(tts: phone).speakAndWait('Hello.', accent: Accent.us);
    expect(phone.spoken, ['Hello.']);
  });

  test('an explicit openAiVoice (Play sample) uses OpenAI with that voice', () async {
    choice = (source: VoiceSource.phone, openAiVoice: 'sage');
    await service().speakAndWait('Sample.', accent: Accent.us, openAiVoice: 'onyx');
    expect(openAi.asked, [('Sample.', 'onyx')]);
    expect(phone.spoken, isEmpty);
  });

  for (final error in OpenAiVoiceError.values) {
    test('AC-31: ${error.name} falls back to the phone voice for that line', () async {
      openAi.error = OpenAiVoiceException(error, 'x');
      await service().speakAndWait('Hello.', accent: Accent.us);
      expect(phone.spoken, ['Hello.']);
      expect(player.played, isEmpty);
    });
  }

  test('a playback error falls back to the phone voice', () async {
    player.fail = true;
    await service().speakAndWait('Hello.', accent: Accent.us);
    expect(phone.spoken, ['Hello.']);
  });

  test('a text over 1200 characters plays in sentence chunks, in order', () async {
    final sentence = '${'word ' * 30}end.';
    final text = List.filled(20, sentence).join(' ');
    await service().speakAndWait(text, accent: Accent.us);
    expect(openAi.asked.length, greaterThan(1));
    expect(openAi.asked.every((a) => a.$1.length <= 1200), isTrue);
    expect(openAi.asked.map((a) => a.$1).join(' '), text);
    expect(player.played.length, openAi.asked.length);
    expect(phone.spoken, isEmpty);
  });

  test('a later chunk that fails speaks the rest with the phone', () async {
    final sentence = '${'word ' * 30}end.';
    final text = List.filled(20, sentence).join(' ');
    openAi
      ..error = OpenAiVoiceException(OpenAiVoiceError.network, 'x')
      ..failFrom = 1;
    await service().speakAndWait(text, accent: Accent.us);
    expect(player.played, hasLength(1));
    expect(phone.spoken, hasLength(1));
    expect('${openAi.asked.first.$1} ${phone.spoken.single}', text);
  });

  test('progress: the OpenAI path reports position over duration, ending at 1', () async {
    final seen = <double>[];
    await service().speakAndWait('Hello.', accent: Accent.us, onProgress: seen.add);
    expect(seen, [0.5, 1.0]);
  });

  test('progress: the phone path reports the spoken offset over the text length', () async {
    choice = (source: VoiceSource.phone, openAiVoice: 'sage');
    final seen = <double>[];
    await service().speakAndWait('abcdefghij', accent: Accent.us, onProgress: seen.add);
    expect(seen, [0.5, 1.0]);
  });

  test('stop() stops OpenAI playback and speakAndWait completes without the phone', () async {
    player.hold = Completer<void>();
    final s = service();
    final speaking = s.speakAndWait('Hello.', accent: Accent.us);
    await Future<void>.delayed(Duration.zero);
    await s.stop();
    await speaking;
    expect(player.stops, greaterThan(0));
    expect(phone.spoken, isEmpty);
  });
}
