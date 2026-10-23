import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/features/learn/fill_the_gaps/fill_the_gaps_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_input.dart';
import 'package:flutter_vocabulary_app/features/learn/sentence_patterns/sentence_patterns_pages.dart';

/// learn-redesign T10: Fill the gaps and Sentence patterns as page sources
/// and page bodies (ADR-0003; AC-08 step 2, AC-10 Check via ready(), AC-11
/// a data failure throws, never a half page).
class _Api implements LearnApiService {
  Object? error;
  CheckReply reply = (usesWord: true, usesTask: true, ok: true, fixed: '', note: '');

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: (kind.wire == 'pattern'
            ? (sentence: 'The main ${w.word} was that we were late.', pattern: 'The main + [noun]', usage: 'explain')
            : (sentence: 'We ${w.word} it on the day.')) as T,
    };
  }

  @override
  Future<CheckReply> check(LearnCheckRequest request) async => reply;

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

class _Speech implements PronunciationService {
  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

WordPair _w(int i, {String? translation}) => WordPair(word: 'word$i', translation: translation ?? 'слово$i', rowId: 'r$i');

PageInput _input(_Api api, List<WordPair> words) =>
    PageInput(words: words, others: const [], dialogues: const [], api: api, random: Random(1));

/// The four words r0..r3 and one without a translation (not usable).
final _words = [for (var i = 0; i < 4; i++) _w(i), _w(4, translation: ' ')];

Future<void> _pump(WidgetTester tester, _Api api, ExercisePage page, PageAnswer answer) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      pronunciationServiceProvider.overrideWithValue(_Speech()),
    ],
    child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => page.body(context, answer)))),
  ));
  await tester.pump();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

void main() {
  group('Fill the gaps pages', () {
    test('one step-2 page per usable word', () async {
      final pages = await fillTheGapsPages(_input(_Api(), _words));
      expect(pages.map((p) => p.rowIds), [
        ['r0'],
        ['r1'],
        ['r2'],
        ['r3'],
      ]);
      expect(pages.every((p) => p.step == 2), isTrue);
      expect(pages.every((p) => p.exerciseId == 'fill-the-gaps' && p.exerciseName == 'Fill the gaps'), isTrue);
    });

    test('AC-11: a data failure throws LearnApiException, no page', () async {
      final api = _Api()..error = LearnApiException(LearnApiError.network, 'offline');
      expect(fillTheGapsPages(_input(api, _words)), throwsA(isA<LearnApiException>()));
    });

    testWidgets('AC-10: a right first answer makes the page ready; Check says right', (tester) async {
      final api = _Api();
      final page = (await fillTheGapsPages(_input(api, _words))).first;
      final answer = PageAnswer();
      await _pump(tester, api, page, answer);
      expect(answer.isReady, isFalse);
      await _send(tester, 'word0');
      expect(answer.isReady, isTrue);
      expect(await answer.runCheck(), {'r0': true});
    });

    testWidgets('AC-10: right only on the second try counts wrong', (tester) async {
      final api = _Api();
      final page = (await fillTheGapsPages(_input(api, _words))).first;
      final answer = PageAnswer();
      await _pump(tester, api, page, answer);
      await _send(tester, 'nothing');
      expect(answer.isReady, isFalse);
      await _send(tester, 'word0');
      expect(answer.isReady, isTrue);
      expect(await answer.runCheck(), {'r0': false});
    });
  });

  group('Sentence patterns pages', () {
    test('one step-2 page per usable word', () async {
      final pages = await sentencePatternsPages(_input(_Api(), _words));
      expect(pages.map((p) => p.rowIds.single), ['r0', 'r1', 'r2', 'r3']);
      expect(pages.every((p) => p.step == 2), isTrue);
      expect(pages.every((p) => p.exerciseId == 'sentence-patterns' && p.exerciseName == 'Sentence patterns'), isTrue);
    });

    test('AC-11: a data failure throws LearnApiException, no page', () async {
      final api = _Api()..error = LearnApiException(LearnApiError.timeout, 'slow');
      expect(sentencePatternsPages(_input(api, _words)), throwsA(isA<LearnApiException>()));
    });

    Future<PageAnswer> write(WidgetTester tester, _Api api) async {
      final page = (await sentencePatternsPages(_input(api, _words))).first;
      final answer = PageAnswer();
      await _pump(tester, api, page, answer);
      await tester.tap(find.text('My turn'));
      await tester.pumpAndSettle();
      expect(answer.isReady, isFalse);
      await _send(tester, 'The main word0 was that the bus was very late today.');
      return answer;
    }

    testWidgets('AC-10: a sentence checked right makes Check say right', (tester) async {
      final answer = await write(tester, _Api());
      expect(answer.isReady, isTrue);
      expect(await answer.runCheck(), {'r0': true});
    });

    testWidgets('AC-10: a fixed sentence makes Check say wrong', (tester) async {
      final api = _Api()..reply = (usesWord: true, usesTask: true, ok: false, fixed: 'Fixed.', note: 'Grammar');
      final answer = await write(tester, api);
      expect(answer.isReady, isTrue);
      expect(await answer.runCheck(), {'r0': false});
    });
  });
}
