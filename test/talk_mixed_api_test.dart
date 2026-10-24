import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';

void main() {
  test('mixed API sends selection provenance and reads the speaking task', () async {
    final service = TalkApiService(client: MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['mode'], 'mixed');
      expect(body['history'].last['source'], 'choice');
      return http.Response(
          jsonEncode({
            'reply': 'What happened?',
            'target': 'spoiled',
            'interaction': 'speak',
            'choices': [],
            'speakingPrompt': 'Explain what is wrong with the berries.'
          }),
          200);
    }));
    final turn = await service.reply(
        scene: 'Kitchen',
        words: [(word: 'spoiled', translation: 'зіпсований')],
        target: 'spoiled',
        history: [const TalkLine(role: 'learner', text: 'Check the berries', isChoice: true)]);
    expect(turn.interaction, 'speak');
    expect(turn.speakingPrompt, 'Explain what is wrong with the berries.');
  });

  test('malformed mixed responses fail safely; older Workers remain usable', () async {
    for (final payload in [
      {
        'interaction': 'choice',
        'choices': ['Only one']
      },
      {'interaction': 'speak', 'speakingPrompt': ''},
      {'interaction': 'unknown'},
    ]) {
      final service = TalkApiService(
          client: MockClient(
              (_) async => http.Response(jsonEncode({'reply': 'Hello', 'target': 'word', ...payload}), 200)));
      await expectLater(service.start(scene: '', words: [(word: 'word', translation: '')], target: 'word'),
          throwsA(isA<TalkApiException>()));
    }
    final legacy =
        TalkApiService(client: MockClient((_) async => http.Response('{"reply":"Hello","target":"word"}', 200)));
    expect(
        (await legacy.start(scene: '', words: [(word: 'word', translation: '')], target: 'word')).interaction, isNull);
  });
}
