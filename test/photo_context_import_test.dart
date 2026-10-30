// word-context T7: /analyze is asked for context; the photo's full text and
// each word's context with its kind are read from the answer (older deploys
// included), and a photo word becomes an image row with that context
// (AC-02, AC-10).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/services/vocab_photo_service.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);

  /// Runs analyzePhoto(context: true) against a Worker answering [body];
  /// returns the result and the request URL.
  Future<(VocabAnalysisResult, Uri)> analyze(Map<String, dynamic> body) async {
    late Uri asked;
    final client = MockClient((request) async {
      asked = request.url;
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final result = await http.runWithClient(
      () => VocabPhotoService()
          .analyzePhoto(bytes, mediaType: 'image/jpeg', context: true),
      () => client,
    );
    return (result, asked);
  }

  group('VocabPhotoService.analyzePhoto with context', () {
    test('sends context=true and reads full_text and context_source',
        () async {
      final (result, url) = await analyze({
        'words': [
          {
            'word': 'harbour',
            'context': 'The boats left the harbour at dawn.',
            'context_source': 'photo',
            'translation': 'гавань',
          },
          {
            'word': 'reluctant',
            'context': 'She was reluctant to answer.',
            'context_source': 'ai',
          },
          {'word': 'fog', 'context': ''},
        ],
        'full_text': 'The boats left the harbour at dawn.\nreluctant\nfog',
        'timings': {'aiMs': 1200},
      });

      expect(url.queryParameters['context'], 'true');
      expect(result.fullText,
          'The boats left the harbour at dawn.\nreluctant\nfog');
      expect(result.words.map((w) => w.contextSource), ['photo', 'ai', null]);
      expect(result.aiDuration, const Duration(milliseconds: 1200));
    });

    test('an older deploy: no full_text is null, a context without a kind is '
        'from the photo', () async {
      final (result, _) = await analyze({
        'words': [
          {'word': 'harbour', 'context': 'at the harbour'},
          {'word': 'fog'},
        ],
      });

      expect(result.fullText, isNull);
      expect(result.words.map((w) => w.contextSource), ['photo', null]);
    });

    test('a blank full_text is null', () async {
      final (result, _) = await analyze({'words': [], 'full_text': '  '});
      expect(result.fullText, isNull);
    });
  });

  group('wordPairFromPhotoAnalysis', () {
    test('a photo line: image origin, trimmed context, kind source', () {
      final pair = wordPairFromPhotoAnalysis(
        VocabWord(
            word: 'harbour',
            translation: 'гавань',
            context: '  The boats left the harbour.  ',
            contextSource: 'photo'),
        sourceId: 'photo-1',
      );
      expect(pair.origin.typeOfSource, SourceType.image);
      expect(pair.context, 'The boats left the harbour.');
      expect(pair.contextKind, ContextKind.source);
      expect(pair.sourceId, 'photo-1');
      expect(pair.translation, 'гавань');
      expect(pair.origin.wasTranslationEditByUser, isFalse);
      expect(pair.origin.wasDescriptionEditByUser, isFalse);
    });

    test('an AI sentence: kind ai', () {
      final pair = wordPairFromPhotoAnalysis(VocabWord(
          word: 'reluctant',
          context: 'She was reluctant to answer.',
          contextSource: 'ai'));
      expect(pair.contextKind, ContextKind.ai);
      expect(pair.context, 'She was reluctant to answer.');
    });

    test('no context: empty, kind none, still an image row', () {
      for (final w in [
        VocabWord(word: 'fog'),
        VocabWord(word: 'fog', context: '   ', contextSource: 'ai'),
      ]) {
        final pair = wordPairFromPhotoAnalysis(w);
        expect(pair.origin.typeOfSource, SourceType.image);
        expect(pair.context, '');
        expect(pair.contextKind, ContextKind.none);
      }
    });

    test('wordPairFromPhoto (subtitles, Quizlet) is left as it was', () {
      final pair = wordPairFromPhoto(
          VocabWord(word: 'fog', context: 'a line', contextSource: 'photo'));
      expect(pair.origin.typeOfSource, SourceType.manuallyEntered);
      expect(pair.context, '');
      expect(pair.contextKind, ContextKind.none);
    });
  });
}
