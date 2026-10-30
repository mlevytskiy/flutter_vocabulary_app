// learn-welcome AC-03: topics from the Worker, the bundled three on failure.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/services/learn_topics_service.dart';

Map<String, String> _t(String id) =>
    {'id': id, 'title': 'T $id', 'description': 'D $id'};

void main() {
  test('sends the words with the secret and returns the 3 topics in order',
      () async {
    late http.Request seen;
    final service = LearnTopicsService(client: MockClient((r) async {
      seen = r;
      return http.Response(
          jsonEncode({
            'topics': [_t('b'), _t('a'), _t('c')]
          }),
          200);
    }));
    final topics = await service.pick([' cat ', '', 'dog']);
    expect(topics.map((t) => t.id), ['b', 'a', 'c']);
    expect(topics.first.title, 'T b');
    expect(seen.url.path, '/learn/topics');
    expect(seen.headers.containsKey('x-app-secret'), isTrue);
    expect(jsonDecode(seen.body), {
      'words': ['cat', 'dog']
    });
  });

  test('sends at most 60 words', () async {
    late http.Request seen;
    final service = LearnTopicsService(client: MockClient((r) async {
      seen = r;
      return http.Response('{}', 500);
    }));
    await service.pick([for (var i = 0; i < 80; i++) 'w$i']);
    expect((jsonDecode(seen.body)['words'] as List).length, 60);
  });

  test('no words: bundled, no request', () async {
    final service = LearnTopicsService(
        client: MockClient((_) async => fail('no request expected')));
    expect(await service.pick(['', ' ']), LearnTopicsService.bundled);
  });

  for (final status in [400, 401, 429, 500]) {
    test('status $status gives the bundled three', () async {
      final service = LearnTopicsService(
          client: MockClient((_) async => http.Response('{}', status)));
      expect(await service.pick(['a']), LearnTopicsService.bundled);
    });
  }

  for (final body in [
    'not json',
    '[]',
    '{"topics":"x"}',
    '{"topics":[]}',
    '{"topics":[{"id":"a","title":"A"}]}',
  ]) {
    test('bad body $body gives the bundled three', () async {
      final service = LearnTopicsService(
          client: MockClient((_) async => http.Response(body, 200)));
      expect(await service.pick(['a']), LearnTopicsService.bundled);
    });
  }

  test('a network error gives the bundled three', () async {
    final service = LearnTopicsService(
        client: MockClient((_) async => throw const SocketException('off')));
    expect(await service.pick(['a']), LearnTopicsService.bundled);
  });

  test('no answer within the timeout gives the bundled three', () async {
    final never = Completer<http.Response>();
    final service = LearnTopicsService(
        client: MockClient((_) => never.future),
        timeout: const Duration(milliseconds: 50));
    expect(await service.pick(['a']), LearnTopicsService.bundled);
  });

  test('the default timeout is 4 s and the bundled ids are fixed', () {
    expect(LearnTopicsService.defaultTimeout, const Duration(seconds: 4));
    expect(LearnTopicsService.bundled.map((t) => t.id),
        ['daily-routine', 'food-and-cooking', 'travel']);
  });
}
