import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/config/vocab_api_config.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';

/// learn-kit S-13: the app side of the Worker's /learn/data and /learn/check
/// (AC-07, AC-20, AC-23, AC-24, AC-27, AC-28 – AC-34c), and the app's verdict
/// on a check (S-21: AC-31 – AC-33).
void main() {
  late List<http.Request> requests;

  LearnApiService answering(int status, Object body,
      {Duration dataTimeout = LearnApiService.dataTimeout,
      Duration checkTimeout = LearnApiService.checkTimeout}) {
    requests = [];
    return LearnApiService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(body), status,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      dataTimeout: dataTimeout,
      checkTimeout: checkTimeout,
    );
  }

  const words = <LearnWord>[
    (rowId: 'a', word: 'bank', translation: 'берег'),
    (rowId: 'b', word: 'run', translation: 'бігти'),
  ];

  LearnApiError? errorOf(Object e) => e is LearnApiException ? e.error : null;

  group('fetchData', () {
    test('posts kind and words with the app secret and reads typed answers per row', () async {
      final api = answering(200, {
        'kind': 'synonym',
        'results': [
          {'rowId': 'a', 'value': {'synonym': 'shore'}},
          {'rowId': 'b', 'value': null},
        ],
      });
      final results = await api.fetchData(LearnDataKind.synonym, words);
      expect(results['a']?.synonym, 'shore');
      expect(results.containsKey('b'), isTrue);
      expect(results['b'], isNull);
      final sent = requests.single;
      expect(sent.url.path, endsWith('/learn/data'));
      expect(sent.headers['x-app-secret'], VocabApiConfig.appSecret);
      expect(jsonDecode(sent.body), {
        'kind': 'synonym',
        'words': [
          {'rowId': 'a', 'word': 'bank', 'translation': 'берег'},
          {'rowId': 'b', 'word': 'run', 'translation': 'бігти'},
        ],
      });
    });

    test('every kind reads its own shape; a broken value is no answer', () async {
      Future<Object?> one(LearnDataKind kind, Map<String, Object?> value) async =>
          (await answering(200, {
            'kind': kind.wire,
            'results': [{'rowId': 'a', 'value': value}],
          }).fetchData(kind, words.sublist(0, 1)))['a'];

      expect(await one(LearnDataKind.definition, {'definition': 'Land by a river.'}), (definition: 'Land by a river.'));
      expect((await one(LearnDataKind.clues, {'clues': ['a', 'b', 'c']}) as CluesData).clues, ['a', 'b', 'c']);
      expect(await one(LearnDataKind.sentence, {'sentence': 'We sat on the bank.'}), (sentence: 'We sat on the bank.'));
      expect(await one(LearnDataKind.pattern, {'sentence': 's', 'pattern': 'p', 'usage': 'u'}), (sentence: 's', pattern: 'p', usage: 'u'));
      expect(await one(LearnDataKind.translate, {'source': 'Ми на березі.', 'cue': 'березі', 'model': 'We are on the bank.'}),
          (source: 'Ми на березі.', cue: 'березі', model: 'We are on the bank.'));
      expect(await one(LearnDataKind.synonym, {'definition': 'wrong kind'}), isNull);
      expect(await one(LearnDataKind.clues, {'clues': 'abc'}), isNull);
    });

    test('the wire names are the Worker kinds', () {
      expect([for (final k in LearnDataKind.values) k.wire], ['synonym', 'definition', 'clues', 'sentence', 'pattern', 'translate']);
    });

    test('refusals and failures map to the error the frame shows', () async {
      Future<LearnApiError?> failing(int status, Object body) async {
        try {
          await answering(status, body).fetchData(LearnDataKind.synonym, words);
        } catch (e) {
          return errorOf(e);
        }
        return null;
      }

      expect(await failing(429, {'code': 'day_limit'}), LearnApiError.dayLimit);
      expect(await failing(429, {'error': 'Too many requests, please slow down'}), LearnApiError.rateLimited);
      expect(await failing(502, {'code': 'learn_failed'}), LearnApiError.failed);
      expect(await failing(400, {'code': 'bad_request'}), LearnApiError.failed);
      expect(await failing(503, {'code': 'no_storage'}), LearnApiError.unavailable);
      expect(await failing(200, {'kind': 'synonym'}), LearnApiError.failed);
    });

    test('no answer in time is a timeout; a dropped connection is network', () async {
      final slow = LearnApiService(
        client: MockClient((_) => Completer<http.Response>().future),
        dataTimeout: const Duration(milliseconds: 10),
      );
      await expectLater(slow.fetchData(LearnDataKind.synonym, words),
          throwsA(isA<LearnApiException>().having((e) => e.error, 'error', LearnApiError.timeout)));
      final offline = LearnApiService(client: MockClient((_) => throw http.ClientException('offline')));
      await expectLater(offline.fetchData(LearnDataKind.synonym, words),
          throwsA(isA<LearnApiException>().having((e) => e.error, 'error', LearnApiError.network)));
    });

    test('the time limits are 30 s for data and 15 s for a check', () {
      expect(LearnApiService.dataTimeout, const Duration(seconds: 30));
      expect(LearnApiService.checkTimeout, const Duration(seconds: 15));
    });
  });

  group('check', () {
    const ask = (word: 'walk', translation: 'гуляти', sentence: 'I walked home.', task: LearnCheckTask.own, extra: '');

    test('posts the check and reads the reply', () async {
      final api = answering(200, {'usesWord': true, 'usesTask': true, 'ok': false, 'fixed': 'I walked home!', 'note': 'n'});
      final reply = await api.check(ask);
      expect(reply, (usesWord: true, usesTask: true, ok: false, fixed: 'I walked home!', note: 'n'));
      expect(requests.single.url.path, endsWith('/learn/check'));
      expect(jsonDecode(requests.single.body),
          {'word': 'walk', 'translation': 'гуляти', 'sentence': 'I walked home.', 'task': 'own', 'extra': ''});
    });

    test('errors as for data; an unreadable reply is failed', () async {
      for (final (status, body, error) in [
        (429, {'code': 'day_limit'}, LearnApiError.dayLimit),
        (429, <String, Object>{}, LearnApiError.rateLimited),
        (502, {'code': 'check_failed'}, LearnApiError.failed),
        (200, {'ok': 'yes'}, LearnApiError.failed),
      ]) {
        await expectLater(answering(status, body).check(ask),
            throwsA(isA<LearnApiException>().having((e) => e.error, 'error', error)));
      }
      final slow = LearnApiService(
        client: MockClient((_) => Completer<http.Response>().future),
        checkTimeout: const Duration(milliseconds: 10),
      );
      await expectLater(slow.check(ask), throwsA(isA<LearnApiException>().having((e) => e.error, 'error', LearnApiError.timeout)));
    });
  });

  test('the provider gives the one service', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(learnApiServiceProvider), same(container.read(learnApiServiceProvider)));
  });

  group('judgeCheck (S-21)', () {
    CheckReply reply({bool usesWord = true, bool usesTask = true, bool ok = true, String fixed = '', String note = ''}) =>
        (usesWord: usesWord, usesTask: usesTask, ok: ok, fixed: fixed, note: note);

    test('AC-28: a good sentence with the word is right', () {
      expect(judgeCheck(reply(), sentence: 'I walk home.', word: 'walk', task: LearnCheckTask.own), isA<CheckRight>());
    });

    test('AC-29: a wrong sentence is fixed, with the AI fix and note', () {
      final v = judgeCheck(reply(ok: false, fixed: 'I walked home yesterday.', note: 'Past simple.'),
          sentence: 'I walk home yesterday.', word: 'walk', task: LearnCheckTask.own);
      expect(v, isA<CheckFixed>());
      expect((v as CheckFixed).fixed, 'I walked home yesterday.');
      expect(v.note, 'Past simple.');
    });

    test('AC-31: the AI says ok, but the word is not there: fixed, with the app note', () {
      final v = judgeCheck(reply(), sentence: 'I strolled home.', word: 'walk', task: LearnCheckTask.translate);
      expect(v, isA<CheckFixed>());
      expect((v as CheckFixed).note, 'Use “walk” in your sentence.');
    });

    test('AC-31: "walked" uses "walk" even when the AI says it does not', () {
      expect(judgeCheck(reply(usesWord: false), sentence: 'I walked home.', word: 'walk', task: LearnCheckTask.own), isA<CheckRight>());
    });

    test('AC-32: a "fix" equal to the sentence is right', () {
      for (final fixed in ['i walk home', '  I walk home!  ', 'I walk home.', '']) {
        expect(judgeCheck(reply(ok: false, fixed: fixed, note: 'x'), sentence: 'I walk home.', word: 'walk', task: LearnCheckTask.own),
            isA<CheckRight>(), reason: fixed);
      }
      expect(judgeCheck(reply(ok: false, fixed: 'I walk to home.'), sentence: 'I walk home.', word: 'walk', task: LearnCheckTask.own),
          isA<CheckFixed>());
    });

    test('a sentence that misses the task is fixed', () {
      expect(judgeCheck(reply(usesTask: false, ok: false, fixed: 'x y'), sentence: 'I walk.', word: 'walk', task: LearnCheckTask.pattern),
          isA<CheckFixed>());
    });

    test('AC-33: an explanation with the word is never right; without it, the task decides; no fix shown', () {
      final withWord = judgeCheck(reply(usesWord: false, ok: true, note: 'n'),
          sentence: 'You walk somewhere on foot.', word: 'walk', task: LearnCheckTask.explain);
      expect(withWord, isA<CheckFixed>());
      expect((withWord as CheckFixed).fixed, '');
      expect(judgeCheck(reply(usesWord: false, ok: false, fixed: 'x'), sentence: 'You go somewhere on foot.', word: 'walk', task: LearnCheckTask.explain),
          isA<CheckRight>());
      final missed = judgeCheck(reply(usesWord: false, usesTask: false, ok: false, fixed: 'x', note: 'Explain the meaning.'),
          sentence: 'I like it a lot.', word: 'walk', task: LearnCheckTask.explain);
      expect((missed as CheckFixed).fixed, '');
      expect(missed.note, 'Explain the meaning.');
    });

    // learn-explain-to-friend S-62 (AC-14 – AC-18): the app's rules first, and a not-right
    // explanation always has one note.
    String noteOf(CheckVerdict v) => (v as CheckFixed).note;
    CheckVerdict explain(String text, CheckReply r, {String word = 'shore'}) =>
        judgeCheck(r, sentence: text, word: word, task: LearnCheckTask.explain);

    test('S-62 AC-14, AC-15: English without the word that does the task is right, grammar not judged', () {
      expect(explain('The land along the edge of the sea or a lake.', reply(usesWord: false)), isA<CheckRight>());
      expect(explain('the land wich is near see', reply(usesWord: false, ok: false, fixed: 'x')), isA<CheckRight>());
    });

    test('S-62 AC-16: the word in any case or with -s is refused with its note, even when the check calls it fine', () {
      for (final text in ['The shore is land.', 'Shores are land by the sea.', 'SHORE means land.']) {
        final v = explain(text, reply(usesWord: false));
        expect(noteOf(v), 'Do not use “shore” in your explanation.', reason: text);
        expect((v as CheckFixed).fixed, '');
      }
    });

    test('S-62 AC-17: any Cyrillic letter is refused, even when the check calls it fine', () {
      expect(noteOf(explain('it is берег, where sea meets land', reply(usesWord: false))), 'Explain it in English only.');
      expect(noteOf(explain('the land by the sea є', reply(usesWord: false))), 'Explain it in English only.');
      // The word wins over Cyrillic.
      expect(noteOf(explain('shore is берег', reply(usesWord: false))), 'Do not use “shore” in your explanation.');
    });

    test("S-62 AC-18: a wrong meaning shows the check's note, else the fixed note; never empty", () {
      expect(noteOf(explain('A place where you keep your money.', reply(usesWord: false, usesTask: false, note: 'That is a money bank.'), word: 'bank')),
          'That is a money bank.');
      for (final note in ['', '   ']) {
        expect(noteOf(explain('A place where you keep your money.', reply(usesWord: false, usesTask: false, note: note), word: 'bank')),
            'This does not explain “bank”.');
      }
    });

    test('S-62: the non-explain branches are unchanged by a Cyrillic letter', () {
      expect(judgeCheck(reply(), sentence: 'I walk home, друже.', word: 'walk', task: LearnCheckTask.own), isA<CheckRight>());
    });
  });
}
