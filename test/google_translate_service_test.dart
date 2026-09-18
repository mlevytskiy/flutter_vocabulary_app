import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';

/// Answers recorded from Google in 2026-09, keyed by the `q` the request
/// carries. A test never touches the network -- the live check is
/// `tool/smoke_google_translate.dart`, run by hand.
const _fixtures = {
  'home': 'translate_home.json',
  'the home': 'translate_the_home.json',
  'beautiful': 'translate_beautiful.json',
  'a cup of tea': 'translate_phrase.json',
};

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  late List<Uri> requests;
  late GoogleTranslateService service;

  setUp(() {
    requests = [];
    final client = MockClient((request) async {
      requests.add(request.url);
      final name = _fixtures[request.url.queryParameters['q']];
      if (name == null) {
        return http.Response('{"error":"no fixture"}', 404);
      }
      return http.Response.bytes(
        utf8.encode(_fixture(name)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    service = GoogleTranslateService(client: client);
  });

  group('the request', () {
    test('asks for the translation, dictionary and alternatives at once',
        () async {
      await service.translate('home', from: 'en', to: 'uk');

      final uri = requests.single;
      expect(uri.path, '/translate_a/single');
      expect(uri.queryParametersAll['dt'], ['t', 'bd', 'at']);
      expect(uri.queryParameters, containsPair('client', 'gtx'));
      expect(uri.queryParameters, containsPair('sl', 'en'));
      expect(uri.queryParameters, containsPair('tl', 'uk'));
      expect(uri.queryParameters, containsPair('q', 'home'));
    });
  });

  group('parsing a recorded answer', () {
    test('reads the primary translation, alternatives and dictionary',
        () async {
      final result = await service.translate('home', from: 'en', to: 'uk');

      expect(result.text, 'додому');
      expect(result.alternatives, ['додому', 'будинок']);
      expect(result.detectedSourceLanguage, 'en');
      expect(
        [for (final e in result.dictionary) e.pos],
        ['adjective', 'adverb', 'noun', 'verb'],
      );
      expect(
        result.byPos('noun')!.wordList,
        containsAll(['батьківщина', 'дім', 'домівка']),
      );
    });

    test('orders the groups for the popup by part of speech', () async {
      final result = await service.translate('home', from: 'en', to: 'uk');

      expect(
        [for (final e in result.dictionaryByPriority) e.pos],
        ['noun', 'verb', 'adjective', 'adverb'],
      );
    });

    test('keeps the back-translations of a dictionary word', () async {
      final result = await service.translate('home', from: 'en', to: 'uk');

      final noun = result.byPos('noun')!;
      expect(noun.words.first.backTranslations, isNotEmpty);
    });

    test('a phrase has no dictionary and reports the detected language',
        () async {
      final result = await service.translate('a cup of tea', to: 'uk');

      expect(result.text, 'чашка чаю');
      expect(result.hasDictionary, isFalse);
      expect(result.detectedSourceLanguage, 'en');
    });
  });

  group('the part-of-speech rule', () {
    test('"home" resolves to a noun via the article lookup', () async {
      // The noun group holds neither "додому" nor "будинок", so "the home" is
      // asked for and its ranked "домівка" wins.
      final wt = await service.translateWord('home', to: 'uk');

      expect(wt.best, 'домівка');
      expect(wt.bestPos, 'noun');
      expect(
        [for (final uri in requests) uri.queryParameters['q']],
        ['home', 'the home'],
      );
    });

    test('"beautiful" falls back to the first word of its only group',
        () async {
      final wt = await service.translateWord('beautiful', to: 'uk');

      expect(wt.best, 'вродливий');
      expect(wt.bestPos, 'adjective');
      expect(requests, hasLength(1), reason: 'no article lookup');
    });

    test('a phrase falls back to the plain translation', () async {
      final wt = await service.translateWord('a cup of tea', to: 'uk');

      expect(wt.best, 'чашка чаю');
      expect(wt.bestPos, isNull);
    });
  });

  group('failures', () {
    test('a non-200 becomes a TranslationException', () async {
      await expectLater(
        service.translate('not recorded', to: 'uk'),
        throwsA(isA<TranslationException>()),
      );
    });
  });
}
