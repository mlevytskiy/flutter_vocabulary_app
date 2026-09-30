import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/config/vocab_api_config.dart';
import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_words_service.dart';

/// words-from-subtitles T7: POST /subtitles/words from the app, with every
/// answer mapped to one of three outcomes (api-sync-report.md App error
/// mapping; sad §8 Error handling).
void main() {
  late http.Request sent;

  SubtitleWordsService serviceAnswering(int status, Object body, {Duration timeout = const Duration(seconds: 5)}) =>
      SubtitleWordsService(
        client: MockClient((request) async {
          sent = request;
          return http.Response(body is String ? body : jsonEncode(body), status,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        timeout: timeout,
      );

  Future<SubtitleWordsResult> pick(SubtitleWordsService service) => service.pickWords(
        lines: const ['I was reluctant to leave.'],
        purpose: ImportPurpose.frequentWords,
        level: EnglishLevel.c1,
        maximum: 30,
        model: SubtitleModel.haiku45,
        sessionWords: const ['tide'],
      );

  Future<SubtitleWordsError> failureOf(SubtitleWordsService service) async {
    try {
      await pick(service);
    } on SubtitleWordsException catch (e) {
      return e.error;
    }
    fail('expected a SubtitleWordsException');
  }

  test('sends the contract body with the app secret', () async {
    await pick(serviceAnswering(200, {'words': [], 'model': 'claude-haiku-4-5-20251001', 'timings': {'aiMs': 1}, 'usage': {'inputTokens': 1, 'outputTokens': 1}}));
    expect(sent.method, 'POST');
    expect(sent.url.toString(), '${VocabApiConfig.baseUrl}/subtitles/words');
    expect(sent.headers['x-app-secret'], VocabApiConfig.appSecret);
    expect(sent.headers['content-type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {
      'lines': ['I was reluctant to leave.'],
      'purpose': 'frequent_words',
      'level': 'C1',
      'maximum': 30,
      'model': 'claude-haiku-4-5-20251001',
      'sessionWords': ['tide'],
    });
  });

  test('200 becomes the words, the model, the AI time and the token counts', () async {
    final result = await pick(serviceAnswering(200, {
      'words': [
        {'word': 'reluctant', 'translation': 'неохочий', 'description': 'Unwilling.', 'context': 'I was reluctant to leave.'},
      ],
      'model': 'claude-haiku-4-5-20251001',
      'timings': {'aiMs': 18450},
      'usage': {'inputTokens': 31250, 'outputTokens': 2140},
    }));
    expect(result.words.single.word, 'reluctant');
    expect(result.words.single.translation, 'неохочий');
    expect(result.words.single.description, 'Unwilling.');
    expect(result.words.single.context, 'I was reluctant to leave.');
    expect(result.model, SubtitleModel.haiku45);
    expect(result.aiDuration, const Duration(milliseconds: 18450));
    expect(result.inputTokens, 31250);
    expect(result.outputTokens, 2140);
  });

  test('422 is "no English lines"', () async {
    expect(await failureOf(serviceAnswering(422, {'error': 'x', 'code': 'no_english_lines'})), SubtitleWordsError.noEnglish);
  });

  test('any 429 is "too many imports", with or without a code', () async {
    expect(await failureOf(serviceAnswering(429, {'error': 'x', 'code': 'too_many_imports'})), SubtitleWordsError.tooManyImports);
    expect(await failureOf(serviceAnswering(429, {'error': 'Too many requests, please slow down'})), SubtitleWordsError.tooManyImports);
  });

  test('every other failure is "could not pick"', () async {
    for (final status in [400, 401, 404, 413, 500, 502, 503]) {
      expect(await failureOf(serviceAnswering(status, {'error': 'x'})), SubtitleWordsError.notPicked, reason: '$status');
    }
    expect(await failureOf(serviceAnswering(200, 'not json')), SubtitleWordsError.notPicked);
    expect(await failureOf(serviceAnswering(200, {'words': 'nope'})), SubtitleWordsError.notPicked);
    expect(await failureOf(serviceAnswering(200, {'words': [], 'model': 'claude-fable-5-1', 'timings': {'aiMs': 1}, 'usage': {'inputTokens': 1, 'outputTokens': 1}})),
        SubtitleWordsError.notPicked, reason: 'a model the app does not know');
  });

  test('no connection is "could not pick"', () async {
    final service = SubtitleWordsService(
      client: MockClient((_) async => throw const SocketException('offline')),
    );
    expect(await failureOf(service), SubtitleWordsError.notPicked);
  });

  test('no answer in time is "could not pick"', () async {
    final service = SubtitleWordsService(
      client: MockClient((_) => Future.delayed(const Duration(seconds: 1), () => http.Response('{}', 200))),
      timeout: const Duration(milliseconds: 50),
    );
    expect(await failureOf(service), SubtitleWordsError.notPicked);
  });

  test('the default timeout is 240 s', () {
    expect(SubtitleWordsService.defaultTimeout, const Duration(seconds: 240));
  });
}
