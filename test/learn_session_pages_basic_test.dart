import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/pick_the_answer/pick_the_answer_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/quiz/quiz_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/remember_or_not/remember_or_not_pages.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';
import 'package:flutter_vocabulary_app/features/learn/session/page_input.dart';

/// learn-redesign T8 (ADR-0003; AC-08, AC-10, AC-15): the page sources and
/// page bodies of Pick the right answer, Remember or not and Quiz.

/// Answers "We <word> it on the day." for every word not in [noSentence].
class _Api implements LearnApiService {
  final noSentence = <String>{};

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async => {
        for (final w in words) w.rowId: noSentence.contains(w.word) ? null : (sentence: 'We ${w.word} it on the day.') as T,
      };

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected: ${i.memberName}');
}

class _Sink implements ExamResultSink {
  final records = <String>[];

  @override
  Future<void> record({
    required String? collectionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) async =>
      records.add(rowId);

  @override
  Map<String, WordResult> latest(WordCollection collection) => const {};
}

WordPair _w(int i, {String? word, String? translation, String definition = ''}) =>
    WordPair(word: word ?? 'word$i', translation: translation ?? 'слово$i', definition: definition, rowId: 'r$i');

final _others = [for (var i = 0; i < 3; i++) _w(100 + i, word: 'other$i', translation: 'інше$i')];

PageInput _input(List<WordPair> words, {LearnApiService? api}) => PageInput(
      words: words,
      others: _others,
      dialogues: const [],
      api: api ?? _Api(),
      random: Random(3),
    );

Future<void> _pumpPage(WidgetTester tester, ExercisePage page, PageAnswer answer, {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: Builder(builder: (context) => page.body(context, answer)))),
    ),
  ));
}

void main() {
  group('page sources', () {
    test('Pick the right answer: one step-1 page per usable word', () async {
      // word3 has no translation: no question of either kind.
      final words = [_w(0), _w(1), _w(2), _w(3, translation: '')];
      final pages = await pickTheAnswerPages(_input(words));
      expect([for (final p in pages) p.rowIds], [
        ['r0'],
        ['r1'],
        ['r2'],
      ]);
      expect(pages.every((p) => p.step == 1 && p.exerciseId == 'pick-the-answer'), isTrue);
      expect(pages.first.exerciseName, 'Pick the right answer');
    });

    test('Remember or not: one step-2 page per usable word', () async {
      // word2's translation is only the word itself: masked, it keeps no letter.
      final words = [_w(0), _w(1), _w(2, translation: 'word2')];
      final pages = await rememberOrNotPages(_input(words));
      expect([for (final p in pages) p.rowIds], [
        ['r0'],
        ['r1'],
      ]);
      expect(pages.every((p) => p.step == 2 && p.exerciseId == 'remember-or-not'), isTrue);
      expect(pages.first.exerciseName, 'Remember or not');
    });

    test('Quiz: one step-3 page per usable word, past seven words too', () async {
      final words = [for (var i = 0; i < 9; i++) _w(i)];
      final pages = await quizPages(_input(words));
      expect({for (final p in pages) ...p.rowIds}, {for (final w in words) w.rowId});
      expect(pages, hasLength(9));
      expect(pages.every((p) => p.step == 3 && p.exerciseId == 'quiz' && p.rowIds.length == 1), isTrue);
      expect(pages.first.exerciseName, 'Quiz');
    });
  });

  group('page bodies', () {
    testWidgets('Remember or not: "I didn\'t" reports a miss through done()', (tester) async {
      final pages = await rememberOrNotPages(_input([_w(0), _w(1), _w(2)]));
      final answer = PageAnswer();
      await _pumpPage(tester, pages.first, answer);
      await tester.tap(find.text('Flip'));
      await tester.pump();
      await tester.tap(find.text("I didn't"));
      await tester.pump();
      expect(answer.isDone, isTrue);
      expect(answer.results, {'r0': false});
    });

    testWidgets('Remember or not: "I knew it" reports a right through done()', (tester) async {
      final pages = await rememberOrNotPages(_input([_w(0), _w(1), _w(2)]));
      final answer = PageAnswer();
      await _pumpPage(tester, pages.first, answer);
      await tester.tap(find.text('Flip'));
      await tester.pump();
      await tester.tap(find.text('I knew it'));
      await tester.pump();
      expect(answer.results, {'r0': true});
    });

    testWidgets('Pick the right answer: the first tap is final and reported through done()', (tester) async {
      final pages = await pickTheAnswerPages(_input([_w(0), _w(1), _w(2)]));
      final answer = PageAnswer();
      await _pumpPage(tester, pages.first, answer);
      await tester.tap(find.text('слово0'));
      await tester.pump();
      expect(answer.results, {'r0': true});
    });

    testWidgets('Quiz: a typed answer makes the page ready, the check matches it, no word result is written (AC-15)',
        (tester) async {
      final sink = _Sink();
      final words = [for (var i = 0; i < 3; i++) _w(i)];
      final pages = await quizPages(_input(words));
      final overrides = [examResultSinkProvider.overrideWithValue(sink)];
      // Position 2 of a layout is a gap question when one exists.
      final gapPage = pages[1];
      final answer = PageAnswer();
      await _pumpPage(tester, gapPage, answer, overrides: overrides);
      expect(answer.isReady, isFalse);
      await tester.enterText(find.byType(TextField), gapPage.rowIds.single.replaceFirst('r', 'word'));
      await tester.pump();
      expect(answer.isReady, isTrue);
      expect(await answer.runCheck(), {gapPage.rowIds.single: true});
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(answer.isReady, isFalse);

      // A choice page answered by a tap.
      final choiceAnswer = PageAnswer();
      await _pumpPage(tester, pages.first, choiceAnswer, overrides: overrides);
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pump();
      expect(choiceAnswer.isDone, isTrue);
      expect(sink.records, isEmpty);
    });
  });
}
