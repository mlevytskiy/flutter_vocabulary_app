// learn-warm-up-v2 T9: the reaction call (AC-05, AC-12), the events call
// (AC-17) and the topic pick with profile, mood and situation lines (AC-13).
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/core/services/learn_events_service.dart';
import 'package:flutter_vocabulary_app/core/services/learn_topics_service.dart';
import 'package:flutter_vocabulary_app/core/services/warm_up_reaction_service.dart';

Map<String, String> _t(String id) => {
      'id': id,
      'title': 'T $id',
      'description': 'D $id',
      'situation': 'S $id',
    };

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('WarmUpReactionService (AC-05, AC-12)', () {
    test('sends the question and the trimmed answer once, returns the line',
        () async {
      final seen = <http.Request>[];
      final service = WarmUpReactionService(client: MockClient((r) async {
        seen.add(r);
        return _json({'reaction': 'Nice, a teacher!'});
      }));
      expect(await service.react('daily', '  I teach kids  '),
          'Nice, a teacher!');
      expect(seen, hasLength(1));
      expect(seen.single.url.path, '/learn/warm-up/reaction');
      expect(seen.single.headers.containsKey('x-app-secret'), isTrue);
      expect(jsonDecode(seen.single.body),
          {'question': 'daily', 'answer': 'I teach kids'});
    });

    test('an empty reaction gives one of the six fixed lines', () async {
      final service = WarmUpReactionService(
          client: MockClient((_) async => _json({'reaction': ''})));
      expect(WarmUpReactionService.fixedLines,
          contains(await service.react('goal', 'travel')));
    });

    test('the six fixed lines', () {
      expect(WarmUpReactionService.fixedLines, [
        'Got it, thanks!',
        'Nice, good to know.',
        "Great, let's go on.",
        'Thanks, that helps!',
        'Sounds good!',
        'Cool, thanks for sharing.',
      ]);
    });

    test('the fixed line is picked at random', () async {
      final service = WarmUpReactionService(
          client: MockClient((_) async => _json({}, 500)),
          random: Random(1));
      final lines = <String>{
        for (var i = 0; i < 40; i++) await service.react('intro', 'B1'),
      };
      expect(lines.length, greaterThan(1));
      expect(WarmUpReactionService.fixedLines.toSet().containsAll(lines),
          isTrue);
    });

    test('a failure, a bad body or a throw gives the fixed line, one try only',
        () async {
      for (final reply in <Future<http.Response> Function()>[
        () async => _json({}, 500),
        () async => http.Response('not json', 200),
        () async => _json({'reaction': 42}),
        () async => throw const SocketExceptionLike(),
      ]) {
        var calls = 0;
        final service = WarmUpReactionService(client: MockClient((_) {
          calls++;
          return reply();
        }));
        expect(WarmUpReactionService.fixedLines,
            contains(await service.react('mood', 'mystery')));
        expect(calls, 1);
      }
    });

    test('an unknown question, a blank or a long answer: no request', () async {
      final service = WarmUpReactionService(
          client: MockClient((_) async => fail('no request expected')));
      for (final call in [
        () => service.react('topic', 'x'),
        () => service.react('goal', '   '),
        () => service.react('goal', 'a' * 81),
      ]) {
        expect(WarmUpReactionService.fixedLines, contains(await call()));
      }
    });

    testWidgets('no reply within 2 s: the fixed line; the late reply is dropped',
        (tester) async {
      final service = WarmUpReactionService(client: MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        return _json({'reaction': 'Too late!'});
      }));
      String? got;
      unawaited(service.react('intro', 'B1').then((v) => got = v));
      await tester.pump(const Duration(milliseconds: 1900));
      expect(got, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(WarmUpReactionService.fixedLines, contains(got));
      await tester.pump(const Duration(seconds: 2));
      expect(got, isNot('Too late!'));
    });
  });

  group('LearnEventsService (AC-17)', () {
    test('sends the fixed names and values as one batch', () async {
      late http.Request seen;
      final service = LearnEventsService(client: MockClient((r) async {
        seen = r;
        return _json({'ok': true});
      }));
      await service.send([
        const LearnEvent.warmUpShown('intro'),
        const LearnEvent.warmUpAnswered('grammar'),
        const LearnEvent.warmUpLeft('topic'),
        const LearnEvent.warmUpFinished(3),
        const LearnEvent.grammarAnswer(rule: true),
        const LearnEvent.topicPicked(own: true),
        const LearnEvent.talkEnd(finished: false),
        const LearnEvent.talkAgain(),
        const LearnEvent.talkRating(up: true),
      ]);
      expect(seen.url.path, '/learn/events');
      expect(seen.headers.containsKey('x-app-secret'), isTrue);
      expect(jsonDecode(seen.body), {
        'events': [
          {'name': 'warm_up_shown', 'value': 'intro'},
          {'name': 'warm_up_answered', 'value': 'grammar'},
          {'name': 'warm_up_left', 'value': 'topic'},
          {'name': 'warm_up_finished', 'n': 3},
          {'name': 'grammar_answer', 'value': 'rule'},
          {'name': 'topic_picked', 'value': 'own'},
          {'name': 'talk_end', 'value': 'ended'},
          {'name': 'talk_again'},
          {'name': 'talk_rating', 'value': 'up'},
        ]
      });
    });

    test('a step off the fixed list is dropped, the rest still goes',
        () async {
      late http.Request seen;
      final service = LearnEventsService(client: MockClient((r) async {
        seen = r;
        return _json({'ok': true});
      }));
      await service.send([
        const LearnEvent.warmUpShown('I love cats'),
        const LearnEvent.warmUpShown('mood'),
        const LearnEvent.warmUpFinished(-1),
      ]);
      expect(jsonDecode(seen.body), {
        'events': [
          {'name': 'warm_up_shown', 'value': 'mood'}
        ]
      });
    });

    test('more than 20 events go in batches of at most 20', () async {
      final sizes = <int>[];
      final service = LearnEventsService(client: MockClient((r) async {
        sizes.add((jsonDecode(r.body)['events'] as List).length);
        return _json({'ok': true});
      }));
      await service.send([for (var i = 0; i < 45; i++) const LearnEvent.talkAgain()]);
      expect(sizes, [20, 20, 5]);
    });

    test('nothing to send: no request', () async {
      final service = LearnEventsService(
          client: MockClient((_) async => fail('no request expected')));
      await service.send([]);
      await service.send([const LearnEvent.warmUpLeft('nope')]);
    });

    test('never throws: a failure or a throwing client is swallowed',
        () async {
      for (final client in [
        MockClient((_) async => _json({'error': 'x'}, 400)),
        MockClient((_) async => throw const SocketExceptionLike()),
      ]) {
        await LearnEventsService(client: client)
            .send([const LearnEvent.talkRating(up: false)]);
      }
    });
  });

  group('LearnTopicsService with profile and mood (AC-12, AC-13)', () {
    test('sends the profile (non-empty fields, trimmed) and the mood',
        () async {
      late http.Request seen;
      final service = LearnTopicsService(client: MockClient((r) async {
        seen = r;
        return _json({
          'topics': [_t('a'), _t('b'), _t('c')]
        });
      }));
      final topics = await service.pick(['cat'],
          level: ' Intermediate ', goal: '', daily: 'I work in IT',
          mood: 'mystery');
      expect(jsonDecode(seen.body), {
        'words': ['cat'],
        'profile': {'level': 'Intermediate', 'daily': 'I work in IT'},
        'mood': 'mystery',
      });
      expect(topics.map((t) => t.situation), ['S a', 'S b', 'S c']);
    });

    test('no profile and no mood: only the words; an unknown mood is left out',
        () async {
      late http.Request seen;
      final service = LearnTopicsService(client: MockClient((r) async {
        seen = r;
        return _json({}, 500);
      }));
      await service.pick(['cat'], level: ' ', mood: 'happy');
      expect(jsonDecode(seen.body), {
        'words': ['cat']
      });
    });

    test('a profile field over 80 characters is cut to 80', () async {
      late http.Request seen;
      final service = LearnTopicsService(client: MockClient((r) async {
        seen = r;
        return _json({}, 500);
      }));
      await service.pick(['cat'], goal: 'g' * 100);
      expect((jsonDecode(seen.body)['profile']['goal'] as String).length, 80);
    });

    test('the bundled three carry a situation line', () {
      for (final t in LearnTopicsService.bundled) {
        expect(t.situation, isNotEmpty);
      }
    });

    testWidgets(
        'the 4 s count from the topic step, not from the start of the pick',
        (tester) async {
      final service = LearnTopicsService(client: MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 6));
        return _json({
          'topics': [_t('a'), _t('b'), _t('c')]
        });
      }));
      final pending = service.start(['cat'], mood: 'useful');
      await tester.pump(const Duration(seconds: 3)); // main answer → topic step
      List<LearnTopic>? got;
      unawaited(pending.topics().then((v) => got = v));
      await tester.pump(const Duration(seconds: 2)); // 5 s since start
      expect(got, isNull);
      await tester.pump(const Duration(seconds: 2)); // reply at 6 s
      expect(got!.map((t) => t.id), ['a', 'b', 'c']);
    });

    testWidgets('no topics within 4 s of the topic step: the bundled three',
        (tester) async {
      final service = LearnTopicsService(client: MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 10));
        return _json({
          'topics': [_t('a'), _t('b'), _t('c')]
        });
      }));
      final pending = service.start(['cat']);
      await tester.pump(const Duration(seconds: 1));
      List<LearnTopic>? got;
      unawaited(pending.topics().then((v) => got = v));
      await tester.pump(const Duration(milliseconds: 3900));
      expect(got, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(got, LearnTopicsService.bundled);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('topics already in when the topic step comes show at once',
        (tester) async {
      final service = LearnTopicsService(
          client: MockClient((_) async => _json({
                'topics': [_t('a'), _t('b'), _t('c')]
              })));
      final pending = service.start(['cat']);
      await tester.pump(const Duration(seconds: 1));
      List<LearnTopic>? got;
      unawaited(pending.topics().then((v) => got = v));
      await tester.pump();
      expect(got!.first.id, 'a');
    });
  });
}

/// A stand-in for a network error thrown by the client.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
