import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
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
}
