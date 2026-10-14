import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_result_line.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_phase.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_scaffold.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/result_summary.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_answer_field.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/typed_match.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-kit: the shared frame and widgets (S-06, S-08, S-11; AC-06 – AC-08,
/// AC-10, AC-13, AC-14, AC-28 – AC-30, AC-34, AC-34c).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

void main() {
  /// The frame pushed over a "learn page", so Back and Done can be seen to return.
  Future<void> pumpFrame(WidgetTester tester, ExercisePhase phase,
      {VoidCallback? onRetry, VoidCallback? onNextRound}) async {
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ExerciseScaffold(
                title: 'Quiz',
                phase: phase,
                onRetry: onRetry ?? () {},
                onNextRound: onNextRound ?? () {},
                roundBuilder: (context, round) => Text('round ${round.index + 1} of ${round.count}'),
              ),
            )),
            child: const Text('learn page'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('learn page'));
    // Not pumpAndSettle: the loading spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('ExerciseScaffold (S-06)', () {
    testWidgets('AC-06: loading shows a progress indicator under the title', (tester) async {
      await pumpFrame(tester, const ExerciseLoading());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Quiz'), findsOneWidget);
    });

    testWidgets('a round shows the round body', (tester) async {
      await pumpFrame(tester, const ExerciseRound(0, 2));
      expect(find.text('round 1 of 2'), findsOneWidget);
    });

    testWidgets('AC-07: a failed load shows one error line and Retry, and no round', (tester) async {
      for (final reason in [ExerciseFailure.network, ExerciseFailure.timeout, ExerciseFailure.failed]) {
        var retried = 0;
        await pumpFrame(tester, ExerciseFailed(reason), onRetry: () => retried++);
        expect(find.text(exerciseFailedMessage), findsOneWidget);
        expect(find.textContaining('round'), findsNothing);
        await tester.tap(find.text('Retry'));
        expect(retried, 1, reason: '$reason');
      }
    });

    testWidgets('AC-27: the day limit says so, with Back to the learn page', (tester) async {
      await pumpFrame(tester, const ExerciseFailed(ExerciseFailure.dayLimit));
      expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('learn page'), findsOneWidget);
    });

    testWidgets('AC-34c: too many requests says so, with Retry', (tester) async {
      await pumpFrame(tester, const ExerciseFailed(ExerciseFailure.rateLimited));
      expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets("AC-08: not enough words: the exercise's text, else the default, and Back", (tester) async {
      await pumpFrame(tester, const ExerciseNotEnough());
      expect(find.text('Not enough words for this exercise'), findsOneWidget);
      await pumpFrame(tester, const ExerciseNotEnough('Add three words with translations.'));
      expect(find.text('Add three words with translations.'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('learn page'), findsOneWidget);
    });

    testWidgets('AC-06: the summary lists every word, Next round while rounds remain, Done returns', (tester) async {
      const outcomes = [
        WordOutcome(rowId: 'a', word: 'cat', result: 'Right'),
        WordOutcome(rowId: 'b', word: 'dog', result: 'Missed 1'),
      ];
      var next = 0;
      await pumpFrame(tester, const ExerciseSummary(outcomes, hasNextRound: true), onNextRound: () => next++);
      expect(find.text('cat'), findsOneWidget);
      expect(find.text('Missed 1'), findsOneWidget);
      await tester.tap(find.text('Next round'));
      expect(next, 1);
      expect(find.text('Done'), findsNothing);

      await pumpFrame(tester, const ExerciseSummary(outcomes, hasNextRound: false));
      expect(find.text('Next round'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('learn page'), findsOneWidget);
    });

    test('a load error maps to the line the frame shows', () {
      expect(failureOf(LearnApiException(LearnApiError.dayLimit, '')), ExerciseFailure.dayLimit);
      expect(failureOf(LearnApiException(LearnApiError.rateLimited, '')), ExerciseFailure.rateLimited);
      expect(failureOf(LearnApiException(LearnApiError.timeout, '')), ExerciseFailure.timeout);
      expect(failureOf(LearnApiException(LearnApiError.network, '')), ExerciseFailure.network);
      expect(failureOf(LearnApiException(LearnApiError.unavailable, '')), ExerciseFailure.failed);
      expect(failureOf(StateError('x')), ExerciseFailure.failed);
    });
  });

  group('exam summary pieces (learn-quiz S-55, S-56)', () {
    const outcomes = [
      WordOutcome(rowId: 'a', word: 'cat', result: 'Known'),
      WordOutcome(rowId: 'b', word: 'dog', result: 'Repeat', detail: 'Answer: dog · Yours: dig'),
    ];

    test('examHeading counts the known words', () {
      expect(examHeading(5, 7), '5 of 7 known');
      expect(examHeading(0, 2), '0 of 2 known');
    });

    testWidgets('a detail shows as a second line under its word only', (tester) async {
      await pumpFrame(tester, const ExerciseSummary(outcomes, hasNextRound: false));
      expect(find.text('Answer: dog · Yours: dig'), findsOneWidget);
      final cat = tester.widget<ListTile>(find.byKey(const ValueKey('outcome-a')));
      expect(cat.subtitle, isNull);
      final dog = tester.widget<ListTile>(find.byKey(const ValueKey('outcome-b')));
      expect(dog.subtitle, isNotNull);
    });

    testWidgets('the extra button shows above Done only with a label and a callback', (tester) async {
      var again = 0;
      await pumpFrame(tester, ExerciseSummary(outcomes, hasNextRound: false, againLabel: 'Repeat', onAgain: () => again++));
      expect(find.widgetWithText(ElevatedButton, 'Repeat'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.getTopLeft(find.widgetWithText(ElevatedButton, 'Repeat')).dy, lessThan(tester.getTopLeft(find.text('Done')).dy));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Repeat'));
      expect(again, 1);

      await pumpFrame(tester, const ExerciseSummary(outcomes, hasNextRound: false, againLabel: 'Repeat'));
      expect(find.widgetWithText(ElevatedButton, 'Repeat'), findsNothing);
    });

    testWidgets('the scaffold passes its own extra button to the summary', (tester) async {
      var again = 0;
      await tester.pumpWidget(MaterialApp(
        home: ExerciseScaffold(
          title: 'Quiz',
          phase: const ExerciseSummary(outcomes, hasNextRound: false, againLabel: 'Repeat'),
          onRetry: () {},
          onNextRound: () {},
          onAgain: () => again++,
          roundBuilder: (c, r) => const SizedBox(),
        ),
      ));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Repeat'));
      expect(again, 1);

      await tester.pumpWidget(MaterialApp(
        home: ExerciseScaffold(
          title: 'Quiz',
          phase: const ExerciseSummary(outcomes, hasNextRound: false),
          onRetry: () {},
          onNextRound: () {},
          roundBuilder: (c, r) => const SizedBox(),
        ),
      ));
      expect(find.widgetWithText(ElevatedButton, 'Repeat'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  group('TypedAnswerField (S-11)', () {
    late List<TypedAnswerResult> results;

    Future<void> pumpField(WidgetTester tester, TypedAnswerMode mode, {String expected = 'receive'}) async {
      results = [];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TypedAnswerField(key: UniqueKey(), expected: expected, mode: mode, onSubmit: results.add)),
      ));
      await tester.pump();
    }

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
    }

    testWidgets('AC-13: focused at once, autocorrect and suggestions off, Send submits, empty is not sent', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textInputAction, TextInputAction.send);
      await send(tester, '   ');
      expect(results, isEmpty);
      await send(tester, 'Receive');
      expect(results.single.match, TypedMatch.right);
      expect(results.single.firstTry, isTrue);
    });

    testWidgets('AC-12: almost counts as right and shows the spelling', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await send(tester, 'recieve');
      expect(results.single.match, TypedMatch.almost);
      expect(results.single.firstTry, isTrue);
      expect(find.text('Almost: receive'), findsOneWidget);
    });

    testWidgets('AC-14 practice: a miss shows first letter and count, one more try, then the answer', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await send(tester, 'take');
      expect(results, isEmpty);
      expect(find.text('Starts with “r”, 7 letters'), findsOneWidget);
      await send(tester, 'get');
      expect(results.single.match, TypedMatch.wrong);
      expect(find.text('Answer: receive'), findsOneWidget);
      expect(find.text('Show answer'), findsNothing);
      await send(tester, 'receive');
      expect(results.length, 1, reason: 'final once');
    });

    testWidgets('AC-14 practice: right on the second try is not first try', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await send(tester, 'take');
      await send(tester, 'receive');
      expect(results.single.match, TypedMatch.right);
      expect(results.single.firstTry, isFalse);
    });

    testWidgets('AC-14 practice: Show answer ends the word as missed', (tester) async {
      await pumpField(tester, TypedAnswerMode.practice);
      await tester.tap(find.text('Show answer'));
      await tester.pump();
      expect(results.single.gaveUp, isTrue);
      expect(find.text('Answer: receive'), findsOneWidget);
    });

    testWidgets('AC-14 exam: no hint, no second try, no Show answer, only Skip', (tester) async {
      await pumpField(tester, TypedAnswerMode.exam);
      expect(find.text('Show answer'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
      await send(tester, 'take');
      expect(results.single.match, TypedMatch.wrong);
      expect(find.textContaining('Starts with'), findsNothing);
      expect(find.textContaining('Answer:'), findsNothing);

      await pumpField(tester, TypedAnswerMode.exam);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(results.single.gaveUp, isTrue);
    });
  });

  group('CheckResultLine and the sentence pre-check', () {
    Future<void> pumpLine(WidgetTester tester, Widget line) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: line)));

    testWidgets('AC-28: a right sentence is "Good"', (tester) async {
      await pumpLine(tester, const CheckResultLine.verdict(CheckRight()));
      expect(find.text('Good'), findsOneWidget);
    });

    testWidgets('AC-29: a fixed sentence shows the fix and the note', (tester) async {
      await pumpLine(tester, const CheckResultLine.verdict(CheckFixed(fixed: 'I walked home.', note: 'Past simple.')));
      expect(find.text('I walked home.'), findsOneWidget);
      expect(find.text('Past simple.'), findsOneWidget);
      expect(find.text('Good'), findsNothing);
    });

    testWidgets('AC-34: a failed check shows an error line and Retry; the day limit has no Retry', (tester) async {
      var retried = 0;
      await pumpLine(tester, CheckResultLine.failed(ExerciseFailure.timeout, onRetry: () => retried++));
      expect(find.text(CheckResultLine.checkFailedMessage), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
      await pumpLine(tester, CheckResultLine.failed(ExerciseFailure.dayLimit, onRetry: () {}));
      expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await pumpLine(tester, CheckResultLine.failed(ExerciseFailure.rateLimited, onRetry: () {}));
      expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
    });

    test('AC-30: empty, one word or too long is not sent', () {
      expect(sentenceProblem('', LearnCheckTask.own), 'Write a full sentence');
      expect(sentenceProblem('  Walking ', LearnCheckTask.own), 'Write a full sentence');
      expect(sentenceProblem('I walk.', LearnCheckTask.own), isNull);
      expect(sentenceProblem('I ${'x' * 199}', LearnCheckTask.own), 'Keep it under two hundred characters');
      expect(sentenceProblem('I ${'x' * 198}', LearnCheckTask.own), isNull);
      expect(sentenceProblem('I ${'x' * 250}', LearnCheckTask.explain), isNull);
      expect(sentenceProblem('I ${'x' * 299}', LearnCheckTask.explain), 'Keep it under three hundred characters');
    });
  });

  group('exerciseWordsProvider (S-08, AC-05)', () {
    WordPair w(String id, String word, {String translation = 't'}) =>
        WordPair(word: word, translation: translation, rowId: id);

    Session session() => Session.create()
      ..words = [w('a', 'cat'), w('b', 'dog'), w('c', 'bird'), w('d', 'fish'), w('e', 'blank', translation: '')]
      ..groups = [
        WordGroup()
          ..id = 'g'
          ..name = 'Pets'
          ..rowIds = ['c', 'a', 'gone'],
      ];

    test("the group's words in group order and the session's other words to learn", () async {
      final current = session();
      final history = session()..words.add(w('h', 'horse'));
      final container = ProviderContainer(overrides: [
        wordInputNotifierProvider.overrideWith(() => _FakeInput(current)),
        sessionByIdProvider(history.sessionId).overrideWith((ref) async => history),
      ]);
      addTearDown(container.dispose);

      final words = await container.read(exerciseWordsProvider(null, 'g').future);
      expect(words.group.map((x) => x.word), ['bird', 'cat']);
      expect(words.others.map((x) => x.word), ['dog', 'fish']);

      final past = await container.read(exerciseWordsProvider(history.sessionId, 'g').future);
      expect(past.others.map((x) => x.word), ['dog', 'fish', 'horse']);

      final none = await container.read(exerciseWordsProvider(null, 'missing').future);
      expect(none.group, isEmpty);
    });
  });
}
