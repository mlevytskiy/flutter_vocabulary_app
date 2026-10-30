import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/fill_the_gaps/fill_the_gaps_page_body.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/gap_question.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/match_board.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_answer_field.dart';
import 'package:flutter_vocabulary_app/features/learn/session/exercise_page.dart';

/// self-check-cards T4 (AC-01, Q-3): page results say right / wrong / hinted
/// per row id; a right second try after the "Starts with …" line is hinted,
/// "Show answer" is wrong; old bool callers see the same right/wrong.
void main() {
  group('TypedAnswerField page result (Q-3)', () {
    late List<TypedAnswerResult> results;

    Future<void> pumpField(WidgetTester tester, TypedAnswerMode mode) async {
      results = [];
      await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: TypedAnswerField(key: UniqueKey(), expected: 'receive', mode: mode, onSubmit: results.add)),
      ));
      await tester.pump();
    }

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
    }

    testWidgets('right on the first try is right', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await send(tester, 'receive');
      expect(results.single.hinted, isFalse);
      expect(results.single.pageResult, PageResult.right);
    });

    testWidgets('right on the second try, after the Starts with line, is hinted', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await send(tester, 'take');
      expect(find.textContaining('Starts with'), findsOneWidget);
      await send(tester, 'recieve');
      expect(results.single.hinted, isTrue);
      expect(results.single.pageResult, PageResult.hinted);
    });

    testWidgets('wrong twice is wrong', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await send(tester, 'take');
      await send(tester, 'get');
      expect(results.single.pageResult, PageResult.wrong);
    });

    testWidgets('Show answer is wrong, also after the hint', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await tester.tap(find.text('Show answer'));
      await tester.pump();
      expect(results.single.pageResult, PageResult.wrong);

      await pumpField(tester, TypedAnswerMode.practice);
      await send(tester, 'take');
      await tester.tap(find.text('Show answer'));
      await tester.pump();
      expect(results.single.hinted, isFalse);
      expect(results.single.pageResult, PageResult.wrong);
    });

    testWidgets('exam: right is right, Skip is wrong', (tester) async {
      await pumpField(tester, TypedAnswerMode.exam);
      await send(tester, 'receive');
      expect(results.single.pageResult, PageResult.right);
      await pumpField(tester, TypedAnswerMode.exam);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(results.single.pageResult, PageResult.wrong);
    });
  });

  group('PageAnswer', () {
    test('old bool ready: the check gives right/wrong, with and without hints', () async {
      final answer = PageAnswer()..ready(() async => {'a': true, 'b': false});
      expect(await answer.runCheck(), {'a': true, 'b': false});
      expect(await answer.runCheckResults(), {'a': PageResult.right, 'b': PageResult.wrong});
    });

    test('old bool done: results and pageResults', () {
      final answer = PageAnswer()..done({'a': true, 'b': false});
      expect(answer.selfChecking, isTrue);
      expect(answer.results, {'a': true, 'b': false});
      expect(answer.pageResults, {'a': PageResult.right, 'b': PageResult.wrong});
    });

    test('a hinted row counts as right in the bool view unless the body says otherwise', () async {
      final answer = PageAnswer()
        ..readyResults(() async => {'a': PageResult.hinted, 'b': PageResult.right, 'c': PageResult.wrong});
      expect(await answer.runCheck(), {'a': true, 'b': true, 'c': false});
      expect(await answer.runCheckResults(), {'a': PageResult.hinted, 'b': PageResult.right, 'c': PageResult.wrong});

      answer.readyResults(() async => {'a': PageResult.hinted}, hintedCountsRight: false);
      expect(await answer.runCheck(), {'a': false});

      answer.doneResults({'a': PageResult.hinted});
      expect(answer.results, {'a': true});
      expect(answer.pageResults, {'a': PageResult.hinted});

      answer.reset();
      expect(answer.results, isNull);
      expect(answer.pageResults, isNull);
      expect(await answer.runCheckResults(), isEmpty);
    });
  });

  group('Fill the gaps page', () {
    testWidgets('a right second try reports hinted and stays not right for the ladder (fill-the-gaps AC-10)',
        (tester) async {
      final answer = PageAnswer();
      const q = GapQuestion(
          rowId: 'r1',
          answer: 'receive',
          sentence: 'I receive letters.',
          masked: 'I ___ letters.',
          cue: 'отримувати',
          source: GapSource.worker);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FillTheGapsPageBody(
            question: q,
            onAnswered: (r) => answer.readyResults(() async => {q.rowId: r.pageResult}, hintedCountsRight: false),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'take');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'receive');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(await answer.runCheckResults(), {'r1': PageResult.hinted});
      expect(await answer.runCheck(), {'r1': false});
    });
  });

  group('Match board page', () {
    testWidgets('a word paired without a miss is right, one with a miss is wrong, none hinted', (tester) async {
      final answer = PageAnswer();
      late bool Function(String, String) pair;
      const items = [MatchItem(id: 'a', text: 'A'), MatchItem(id: 'b', text: 'B'), MatchItem(id: 'c', text: 'C')];
      await tester.pumpWidget(MaterialApp(
        home: MatchBoardPage(
          left: items,
          right: items,
          answer: answer,
          builder: (context, links, onPair) {
            pair = onPair;
            return const SizedBox();
          },
        ),
      ));
      expect(pair('a', 'a'), isTrue);
      expect(pair('b', 'c'), isFalse);
      expect(pair('b', 'b'), isTrue);
      expect(answer.isDone, isFalse);
      expect(pair('c', 'c'), isTrue);
      expect(answer.pageResults, {'a': PageResult.right, 'b': PageResult.wrong, 'c': PageResult.right});
      expect(answer.results, {'a': true, 'b': false, 'c': true});
    });
  });
}
