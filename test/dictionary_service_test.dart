@Tags(['smoke'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/models/definition_result.dart';
import 'package:flutter_vocabulary_app/core/services/dictionary_service.dart';

/// definition-mode T8: the app side of the Worker's dictionary route — three
/// outcomes, never an exception (spec AC-05..AC-07, sad §8).
void main() {
  late List<http.Request> requests;

  DictionaryService answering(int status, Object body,
      {Duration timeout = const Duration(seconds: 6)}) {
    requests = [];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status,
          headers: {'content-type': 'application/json'});
    });
    return DictionaryService(client: client, timeout: timeout);
  }

  test('asks the dictionary route with the word and the shared secret',
      () async {
    final service = answering(200, {
      'outcome': 'senses',
      'word': 'tenacious',
      'senses': ['persistent', 'retentive'],
    });

    await service.define('  tenacious ');

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, endsWith('/define'));
    expect(requests.single.headers.containsKey('x-app-secret'), isTrue);
    expect(jsonDecode(requests.single.body), {'word': 'tenacious'});
  });

  test('senses come back in order', () async {
    final result = await answering(200, {
      'outcome': 'senses',
      'word': 'tenacious',
      'senses': ['persistent', 'retentive'],
    }).define('tenacious');

    expect(result.kind, DefinitionKind.senses);
    expect(result.senses, ['persistent', 'retentive']);
    expect(result.firstSense, 'persistent');
  });

  test('an unknown word brings suggestions and no senses', () async {
    final result = await answering(200, {
      'outcome': 'not_found',
      'word': 'determinated',
      'suggestions': ['determinate', 'determined'],
    }).define('determinated');

    expect(result.kind, DefinitionKind.notFound);
    expect(result.senses, isEmpty);
    expect(result.suggestions, ['determinate', 'determined']);
  });

  group('everything else is "unavailable", never an exception', () {
    test('the Worker says unavailable', () async {
      final result = await answering(503, {
        'outcome': 'unavailable',
        'error': 'Dictionary did not answer in time',
      }).define('claim');
      expect(result.kind, DefinitionKind.unavailable);
    });

    test('a server error with a non-JSON body', () async {
      final client = MockClient((_) async => http.Response('oops', 500));
      final result = await DictionaryService(client: client).define('claim');
      expect(result.kind, DefinitionKind.unavailable);
    });

    test('an old Worker without the route', () async {
      final result =
          await answering(404, {'error': 'Not found'}).define('claim');
      expect(result.kind, DefinitionKind.unavailable);
    });

    test('a network error', () async {
      final client =
          MockClient((_) async => throw http.ClientException('offline'));
      final result = await DictionaryService(client: client).define('claim');
      expect(result.kind, DefinitionKind.unavailable);
    });

    test('a hung request times out', () async {
      final client = MockClient((_) => Completer<http.Response>().future);
      final result = await DictionaryService(
        client: client,
        timeout: const Duration(milliseconds: 20),
      ).define('claim');
      expect(result.kind, DefinitionKind.unavailable);
    });
  });

  test('senses round-trip through the stored row JSON (ADR-0003)', () {
    final json = DefinitionResult.encodeSenses(['a', 'b']);
    expect(DefinitionResult.decodeSenses(json), ['a', 'b']);
    expect(DefinitionResult.decodeSenses(null), isEmpty);
    expect(DefinitionResult.decodeSenses('not json'), isEmpty);
  });
}
