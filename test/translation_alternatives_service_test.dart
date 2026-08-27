// Unit tests for the pure response-parsing/validation logic behind
// normalizeToLemmaForm. These test parseNormalizedLemmaResponse directly
// against sample Azure OpenAI response bodies, without any live network
// call or HTTP mocking -- normalizeToLemmaForm itself can't be exercised
// here since it requires real (not-yet-configured) Azure OpenAI
// credentials, but this at least sanity-checks the JSON parsing and
// fallback rules that sit in front of it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/services/translation_alternatives_service.dart';

String _chatResponse(String assistantContent) => jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': assistantContent},
        }
      ],
    });

void main() {
  group('parseNormalizedLemmaResponse', () {
    final candidates = ['вимогливих', 'вимогливими'];

    test('returns normalized words on a well-formed response', () {
      final body = _chatResponse(jsonEncode({
        'normalized': ['вимогливий', 'вимогливий'],
      }));

      expect(parseNormalizedLemmaResponse(body, candidates),
          ['вимогливий', 'вимогливий']);
    });

    test('falls back to candidates when item count mismatches', () {
      final body = _chatResponse(jsonEncode({
        'normalized': ['вимогливий'], // only 1, expected 2
      }));

      expect(parseNormalizedLemmaResponse(body, candidates), candidates);
    });

    test('falls back to candidates when response contains empty strings',
        () {
      final body = _chatResponse(jsonEncode({
        'normalized': ['вимогливий', ''],
      }));

      expect(parseNormalizedLemmaResponse(body, candidates), candidates);
    });

    test('falls back to candidates when assistant content is not valid JSON',
        () {
      final body = _chatResponse('this is not json');

      expect(parseNormalizedLemmaResponse(body, candidates), candidates);
    });

    test('falls back to candidates when "normalized" key is missing', () {
      final body = _chatResponse(jsonEncode({'other_key': []}));

      expect(parseNormalizedLemmaResponse(body, candidates), candidates);
    });

    test('falls back to candidates when top-level response body is not JSON',
        () {
      expect(
          parseNormalizedLemmaResponse('not json at all', candidates),
          candidates);
    });

    test('falls back to candidates when "choices" is missing/empty', () {
      final body = jsonEncode({'choices': []});

      expect(parseNormalizedLemmaResponse(body, candidates), candidates);
    });

    test('preserves order (does not sort/dedupe)', () {
      final threeCandidates = ['банку', 'банком', 'банків'];
      final body = _chatResponse(jsonEncode({
        'normalized': ['банк', 'банк', 'банк'],
      }));

      expect(parseNormalizedLemmaResponse(body, threeCandidates),
          ['банк', 'банк', 'банк']);
    });
  });

  group('parseSelectedTranslationsResponse', () {
    test('returns the deduped selection on a well-formed response', () {
      final body = _chatResponse(jsonEncode({
        'selected': ['банк', 'берег', 'дамба'],
      }));

      expect(parseSelectedTranslationsResponse(body, 5),
          ['банк', 'берег', 'дамба']);
    });

    test('dedupes case/whitespace-insensitively within the AI response', () {
      final body = _chatResponse(jsonEncode({
        'selected': ['банк', ' Банк ', 'берег'],
      }));

      expect(parseSelectedTranslationsResponse(body, 5), ['банк', 'берег']);
    });

    test('caps at maxResults even if the AI returns more', () {
      final body = _chatResponse(jsonEncode({
        'selected': ['а', 'б', 'в', 'г', 'д', 'е'],
      }));

      expect(parseSelectedTranslationsResponse(body, 3), ['а', 'б', 'в']);
    });

    test('returns null (not an empty list) when the selection is empty', () {
      final body = _chatResponse(jsonEncode({'selected': <String>[]}));

      expect(parseSelectedTranslationsResponse(body, 5), isNull);
    });

    test('returns null when the selection is all empty/whitespace strings',
        () {
      final body = _chatResponse(jsonEncode({
        'selected': ['', '   '],
      }));

      expect(parseSelectedTranslationsResponse(body, 5), isNull);
    });

    test('returns null when assistant content is not valid JSON', () {
      final body = _chatResponse('not json');

      expect(parseSelectedTranslationsResponse(body, 5), isNull);
    });

    test('returns null when "selected" key is missing', () {
      final body = _chatResponse(jsonEncode({'other_key': []}));

      expect(parseSelectedTranslationsResponse(body, 5), isNull);
    });

    test('returns null when top-level response body is not JSON', () {
      expect(parseSelectedTranslationsResponse('not json at all', 5), isNull);
    });

    test('returns null when "choices" is missing/empty', () {
      final body = jsonEncode({'choices': []});

      expect(parseSelectedTranslationsResponse(body, 5), isNull);
    });
  });

  group('heuristicSelectAndNormalize', () {
    test('dedupes case/whitespace-insensitively', () {
      final candidates = ['банк', ' Банк ', 'БАНК'];

      expect(heuristicSelectAndNormalize(candidates, 5), ['банк']);
    });

    test('prefers single-word entries over multi-word phrases', () {
      final candidates = [
        'класти гроші в банк',
        'банк',
        'бути банкіром',
        'берег',
      ];

      expect(heuristicSelectAndNormalize(candidates, 5),
          ['банк', 'берег', 'класти гроші в банк', 'бути банкіром']);
    });

    test('caps the result at maxResults', () {
      final candidates =
          List.generate(10, (i) => 'слово$i'); // 10 distinct single words

      final result = heuristicSelectAndNormalize(candidates, 5);

      expect(result.length, 5);
      expect(result, ['слово0', 'слово1', 'слово2', 'слово3', 'слово4']);
    });

    test('handles a realistic large/messy Google dictionary-shaped list',
        () {
      // Modeled on the real "bank" alternatives captured while verifying
      // google_translate_dictionary_service.dart.
      final candidates = [
        'банківський',
        'банк',
        'берег',
        'дамба',
        'комплект',
        'набір',
        'насип',
        'риф',
        'суд',
        'вал',
        'депозит',
        'крен',
        'устя шахти',
        'вибій',
        'мілина',
        'фонд',
        'віраж',
        'класти гроші в банк',
        'бути банкіром',
        'робити віраж',
        'загачувати',
      ];

      final result = heuristicSelectAndNormalize(candidates, 5);

      expect(result.length, 5);
      // All single words -- there are plenty available, so no phrase
      // should have been needed to fill out the top 5.
      expect(result.every((w) => !w.contains(' ')), isTrue);
    });

    test('returns an empty list for an empty input', () {
      expect(heuristicSelectAndNormalize([], 5), isEmpty);
    });

    test('skips empty/whitespace-only entries', () {
      final candidates = ['банк', '', '   ', 'берег'];

      expect(heuristicSelectAndNormalize(candidates, 5), ['банк', 'берег']);
    });
  });
}
