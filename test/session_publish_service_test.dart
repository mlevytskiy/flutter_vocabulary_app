import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/models/source_photo.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_publish_service.dart';

void main() {
  late List<http.Request> requests;

  SessionPublishService serviceAnswering(int status, Object body) {
    requests = [];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
    });
    return SessionPublishService(client: client);
  }

  const answer = {
    'id': '35ffe55d-907d-4540-a5bb-5bda856dc6f5',
    'url': 'https://example.workers.dev/s/35ffe55d-907d-4540-a5bb-5bda856dc6f5',
    'expiresAt': '2026-10-21T07:32:30.434Z',
  };

  group('the request', () {
    test('posts the pairs as entries with the shared secret', () async {
      final service = serviceAnswering(200, answer);

      await service.publish([
        WordPair(word: 'receipt', translation: 'квитанція'),
        WordPair(word: 'shelf', translation: 'полиця'),
      ]);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/sessions');
      expect(request.headers['x-app-secret'], isNotEmpty);
      expect(request.headers['content-type'], startsWith('application/json'));
      final body = jsonDecode(utf8.decode(request.bodyBytes));
      expect(body, {
        'detail': 'translation',
        'entries': [
          {'word': 'receipt', 'translation': 'квитанція'},
          {'word': 'shelf', 'translation': 'полиця'},
        ],
      });
    });

    test('drops blank pairs — the trailing empty row never reaches the page',
        () async {
      final service = serviceAnswering(200, answer);

      await service.publish([
        WordPair(word: ' cup ', translation: 'чашка'),
        WordPair(),
        WordPair(word: '  ', translation: ''),
      ]);

      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body['entries'], [
        {'word': 'cup', 'translation': 'чашка'},
      ]);
    });

    test('refuses to publish when only blank pairs are left, without a request',
        () async {
      final service = serviceAnswering(200, answer);

      expect(
        () => service.publish([WordPair(), WordPair(word: ' ')]),
        throwsA(isA<SessionPublishException>()),
      );
      expect(requests, isEmpty);
    });
  });

  group('the answer', () {
    test('carries the id, the public url and the expiry', () async {
      final service = serviceAnswering(200, answer);

      final published = await service.publish([
        WordPair(word: 'tea', translation: 'чай'),
      ]);

      expect(published.id, '35ffe55d-907d-4540-a5bb-5bda856dc6f5');
      expect(published.url, answer['url']);
      expect(published.expiresAt, DateTime.parse('2026-10-21T07:32:30.434Z'));
    });

    test("surfaces the Worker's error message on a non-200", () async {
      final service = serviceAnswering(401, {'error': 'Unauthorized'});

      expect(
        () => service.publish([WordPair(word: 'tea', translation: 'чай')]),
        throwsA(
          isA<SessionPublishException>()
              .having((e) => e.message, 'message', 'Unauthorized'),
        ),
      );
    });

    test('reports a non-JSON body as an unexpected response', () async {
      final client = MockClient(
        (_) async => http.Response('<html>502</html>', 502),
      );
      final service = SessionPublishService(client: client);

      expect(
        () => service.publish([WordPair(word: 'tea', translation: 'чай')]),
        throwsA(
          isA<SessionPublishException>()
              .having((e) => e.message, 'message', contains('502')),
        ),
      );
    });
  });

  // definition-mode T16 (ADR-0004, spec AC-16, AC-19); since good-looking-web
  // T18 every stored translation and definition goes, whatever the mode (AC-27).
  group('definitions and the detail mode', () {
    final pairs = [
      WordPair(word: 'claim', translation: 'заява', definition: 'to ask for'),
      WordPair(word: 'gated', definition: 'having a gate'),
    ];

    test('definition mode still sends the stored translations', () async {
      final service = serviceAnswering(200, answer);
      await service.publish(pairs, detail: WordDetailMode.definition);
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body, {
        'detail': 'definition',
        'entries': [
          {'word': 'claim', 'translation': 'заява', 'definition': 'to ask for'},
          {'word': 'gated', 'translation': '', 'definition': 'having a gate'},
        ],
      });
    });

    // AC-27
    test('a translation-mode session with stored definitions sends them',
        () async {
      final service = serviceAnswering(200, answer);
      await service.publish(pairs, detail: WordDetailMode.translation);
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body, {
        'detail': 'translation',
        'entries': [
          {'word': 'claim', 'translation': 'заява', 'definition': 'to ask for'},
          {'word': 'gated', 'translation': '', 'definition': 'having a gate'},
        ],
      });
    });

    test('both sends translations and definitions', () async {
      final service = serviceAnswering(200, answer);
      await service.publish(pairs, detail: WordDetailMode.both);
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body['detail'], 'both');
      expect(body['entries'][0],
          {'word': 'claim', 'translation': 'заява', 'definition': 'to ask for'});
    });

    test('a too-long definition surfaces the Worker message naming the word',
        () async {
      final service = serviceAnswering(400, {
        'error': 'The definition of "gated" is too long (at most 500 characters)',
      });
      expect(
        () => service.publish(pairs, detail: WordDetailMode.definition),
        throwsA(isA<SessionPublishException>().having(
            (e) => e.message, 'message', contains('"gated"'))),
      );
    });
  });
  // good-looking-web T18 (ADR-0006, spec AC-24, AC-25, OQ-3).
  group('source photos', () {
    SourcePhoto photo(String id, int minute) => SourcePhoto()
      ..id = id
      ..fileName = '$id.jpg'
      ..takenAt = DateTime.utc(2026, 9, 28, 10, minute);

    // AC-24
    test('with photos off the payload has no sources and no sourceId',
        () async {
      final service = serviceAnswering(200, answer);
      await service.publish([
        WordPair(word: 'shelf', translation: 'полиця', sourceId: 'p1'),
        WordPair(word: 'cup', translation: 'чашка'),
      ]);
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body.containsKey('sources'), isFalse);
      for (final entry in body['entries'] as List) {
        expect((entry as Map).containsKey('sourceId'), isFalse);
      }
    });

    // AC-25
    test('declares the linked photos by taken time and links their rows',
        () async {
      final service = serviceAnswering(200, answer);
      final published = await service.publish(
        [
          WordPair(word: 'shelf', translation: 'полиця', sourceId: 'p2'),
          WordPair(word: 'cup', translation: 'чашка'),
          WordPair(word: 'tea', translation: 'чай', sourceId: 'p1'),
          WordPair(sourceId: 'unused'), // blank: dropped, links nothing
        ],
        sources: [photo('p2', 5), photo('p1', 1), photo('unused', 0)],
      );
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body['sources'], [
        {'id': 'p1', 'order': 0},
        {'id': 'p2', 'order': 1},
      ]);
      expect(body['entries'], [
        {'word': 'shelf', 'translation': 'полиця', 'sourceId': 'p2'},
        {'word': 'cup', 'translation': 'чашка'},
        {'word': 'tea', 'translation': 'чай', 'sourceId': 'p1'},
      ]);
      expect(published.declaredSources.map((p) => p.id), ['p1', 'p2']);
      expect(published.leftOutSources, isEmpty);
    });

    // spec OQ-3
    test('11 photos: the first 10 taken are declared, the last is left out',
        () async {
      final service = serviceAnswering(200, answer);
      final photos = [for (var i = 10; i >= 0; i--) photo('p$i', i)];
      final published = await service.publish(
        [
          for (var i = 0; i <= 10; i++)
            WordPair(word: 'w$i', translation: 't$i', sourceId: 'p$i'),
        ],
        sources: photos,
      );
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body['sources'], [
        for (var i = 0; i < 10; i++) {'id': 'p$i', 'order': i},
      ]);
      // The left-out photo's row still publishes, linked to nothing.
      expect(body['entries'].last, {'word': 'w10', 'translation': 't10'});
      expect(published.declaredSources, hasLength(10));
      expect(published.leftOutSources.map((p) => p.fileName), ['p10.jpg']);
    });
  });

  // good-looking-web T18 (ADR-0008).
  group('republish', () {
    const withToken = {...answer, 'editToken': 'tok-1'};

    test('a first publish sends no token and returns the one it gets',
        () async {
      final service = serviceAnswering(200, withToken);
      final published =
          await service.publish([WordPair(word: 'tea', translation: 'чай')]);
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body.containsKey('publishedId'), isFalse);
      expect(body.containsKey('editToken'), isFalse);
      expect(published.editToken, 'tok-1');
    });

    test('sends the published id and token when the session has them',
        () async {
      final service = serviceAnswering(200, withToken);
      await service.publish(
        [WordPair(word: 'tea', translation: 'чай')],
        publishedId: 'old-id',
        editToken: 'old-token',
      );
      final body = jsonDecode(utf8.decode(requests.single.bodyBytes));
      expect(body['publishedId'], 'old-id');
      expect(body['editToken'], 'old-token');
    });

    test('an answer without a token (an older Worker) still publishes',
        () async {
      final service = serviceAnswering(200, answer);
      final published =
          await service.publish([WordPair(word: 'tea', translation: 'чай')]);
      expect(published.editToken, isNull);
    });
  });
}
