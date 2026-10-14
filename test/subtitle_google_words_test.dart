import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_google_words.dart';

/// Answers a multi-line request the way Google does: the lines translated
/// and joined with the same newlines.
class FakeGoogle extends GoogleTranslateService {
  FakeGoogle(this.answer);
  final String Function(String text) answer;
  final asked = <({String text, String to, String from})>[];

  @override
  Future<TranslationResult> translate(String text, {required String to, String from = 'auto'}) async {
    asked.add((text: text, to: to, from: from));
    return TranslationResult(text: answer(text));
  }
}

FakeGoogle dictionary(Map<String, String> words) =>
    FakeGoogle((text) => text.split('\n').map((w) => words[w] ?? (throw TranslationException('offline'))).join('\n'));

/// Subtitle words translated on the phone with Google Translate, in one request.
void main() {
  test('one request, English to Ukrainian, the words one per line', () async {
    final google = dictionary({'harbour': 'гавань', 'fog': 'туман', 'tide': 'приплив'});
    await SubtitleGoogleWords(google).translate(['harbour', 'fog', 'tide'], contexts: const {}, maximum: 5);
    expect(google.asked, [(text: 'harbour\nfog\ntide', to: 'uk', from: 'en')]);
  });

  test('each word gets its line\'s translation and the phone\'s context line, in order, without a definition', () async {
    final google = dictionary({'harbour': 'гавань', 'fog': 'туман'});
    final words = await SubtitleGoogleWords(google)
        .translate(['harbour', 'fog'], contexts: {'harbour': 'Into the harbour.', 'fog': 'The fog.'}, maximum: 5);
    expect(words.map((w) => [w.word, w.translation, w.context, w.description]), [
      ['harbour', 'гавань', 'Into the harbour.', null],
      ['fog', 'туман', 'The fog.', null],
    ]);
  });

  test('a word given back unchanged or empty is left out and a spare word fills its place; at most the maximum', () async {
    final google = dictionary({'mortimer': 'Mortimer', 'zzz': ' ', 'harbour': 'гавань', 'fog': 'туман', 'tide': 'приплив'});
    final words = await SubtitleGoogleWords(google)
        .translate(['mortimer', 'zzz', 'harbour', 'fog', 'tide'], contexts: const {}, maximum: 2);
    expect(words.map((w) => w.word), ['harbour', 'fog']);
  });

  test('lines that do not match the words fail the import rather than mix up translations', () async {
    final google = FakeGoogle((_) => 'гавань туман');
    expect(
      SubtitleGoogleWords(google).translate(['harbour', 'fog'], contexts: const {}, maximum: 5),
      throwsA(isA<TranslationException>()),
    );
  });

  test('a failed request fails the whole import', () async {
    final google = dictionary({'harbour': 'гавань'});
    expect(
      SubtitleGoogleWords(google).translate(['harbour', 'fog'], contexts: const {}, maximum: 5),
      throwsA(isA<TranslationException>()),
    );
  });

  test('no words, no request', () async {
    final google = dictionary(const {});
    expect(await SubtitleGoogleWords(google).translate(const [], contexts: const {}, maximum: 5), isEmpty);
    expect(google.asked, isEmpty);
  });
}
