import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_scaffold.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/question_builder.dart';
import 'package:flutter_vocabulary_app/features/learn/quiz/quiz_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/pronunciation_buttons.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-quiz: the screen (AC-01, AC-03, AC-04, AC-08 – AC-18, AC-21,
/// AC-23 – AC-26; §6 tap-to-Next and feedback leak).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

class _Api implements LearnApiService {
  Object? error;
  final noSentence = <String>{};
  final calls = <List<LearnWord>>[];

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words) w.rowId: noSentence.contains(w.word) ? null : (sentence: 'We ${w.word} it on the day.') as T,
    };
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

/// Records every call; [record] never completes (nothing may wait for it, §6).
class _Sink implements ExamResultSink {
  final records = <({String? collectionId, String rowId, WordResultLabel label})>[];

  @override
  Future<void> record({
    required String? collectionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) {
    expect(exerciseId, 'quiz');
    records.add((collectionId: collectionId, rowId: rowId, label: label));
    return Completer<void>().future;
  }

  @override
  Map<String, WordResult> latest(WordCollection collection) => const {};
}

WordCollection _collection(int count, {List<String>? names}) {
  final words = [
    for (var i = 0; i < count; i++)
      WordPair(word: names != null ? names[i] : 'word$i', translation: 'слово$i', rowId: 'r$i'),
  ];
  return WordCollection.create()
    ..words = [...words, for (var i = 0; i < 3; i++) WordPair(word: 'other$i', translation: 'інше$i', rowId: 'o$i')]
    ..groups = [
      WordGroup()
        ..id = 'g'
        ..name = 'G'
        ..rowIds = [for (final w in words) w.rowId],
    ];
}

void main() {
  late _Api api;
  late _Sink sink;
  late ProviderContainer container;
  String? openedFor;

  setUp(() {
    api = _Api();
    sink = _Sink();
  });

  Future<void> openQuiz(WidgetTester tester) async {
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, WordCollection collection, {String? collectionId}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    openedFor = collectionId;
    container = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      examResultSinkProvider.overrideWithValue(sink),
      exerciseRandomProvider.overrideWithValue(Random(3)),
      wordInputNotifierProvider.overrideWith(() => _FakeInput(collection)),
      collectionByIdProvider('hist').overrideWith((ref) async => collection),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => exerciseScreen('quiz', collectionId, 'g'),
              )),
              child: const Text('learn page'),
            ),
          ),
        ),
      ),
    ));
    await openQuiz(tester);
  }

  QuizState state() => container.read(quizProvider(openedFor, 'g')).requireValue;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
  }

  /// Answers the shown question right (or wrong), then taps Next.
  Future<void> answer(WidgetTester tester, {bool right = true}) async {
    final q = state().question!;
    if (q.choice != null) {
      final i = right ? q.choice!.rightIndex : (q.choice!.rightIndex + 1) % 4;
      await tester.ensureVisible(find.byKey(ValueKey('option-$i')));
      await tester.tap(find.byKey(ValueKey('option-$i')));
      await tester.pump();
    } else {
      await send(tester, right ? q.gap!.answer : 'nothing like it');
    }
    await tapText(tester, 'Next');
  }

  void expectNoVerdict() {
    for (final t in ['Right', 'Missed', 'Known', 'Repeat', 'Good']) {
      expect(find.text(t), findsNothing, reason: t);
    }
    expect(find.textContaining('Answer:'), findsNothing);
    expect(find.textContaining('Almost'), findsNothing);
    expect(find.textContaining('Starts with'), findsNothing);
    expect(find.text('Show answer'), findsNothing);
  }

  Color? optionColor(WidgetTester tester, int i) => tester
      .widget<ElevatedButton>(find.byKey(ValueKey('option-$i')))
      .style
      ?.backgroundColor
      ?.resolve(const {});

  testWidgets('AC-01, AC-11: title, counter, kind A question with four options and Skip; no keyboard, no speaker',
      (tester) async {
    await pump(tester, _collection(9));
    final q = state().question!;
    expect(find.widgetWithText(AppBar, 'Quiz'), findsOneWidget);
    expect(find.text('Question 1 of 7'), findsOneWidget);
    expect(find.text('Pick the translation'), findsOneWidget);
    expect(find.text(q.choice!.prompt), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('option-$i')), findsOneWidget);
      expect(optionColor(tester, i), isNull);
    }
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(PronunciationButtons), findsNothing);
    expect(find.text('Gap questions are unavailable'), findsNothing);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('AC-12: a tap marks only the picked option, never the right one; Skip goes, Next shows', (tester) async {
    await pump(tester, _collection(9));
    final q = state().question!.choice!;
    final wrong = (q.rightIndex + 1) % 4;
    await tester.tap(find.byKey(ValueKey('option-$wrong')));
    // §6: one frame after the tap, with a save that never completes.
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    final picked = optionColor(tester, wrong);
    expect(picked, isNotNull);
    expect(picked, isNot(Colors.red));
    expect(picked, isNot(Colors.green));
    expect(optionColor(tester, q.rightIndex), isNull);
    await tester.tap(find.byKey(ValueKey('option-${q.rightIndex}')));
    await tester.pump();
    expect(optionColor(tester, q.rightIndex), isNull);
    expect(sink.records.single.label, WordResultLabel.repeat);
    expectNoVerdict();
  });

  testWidgets('AC-11: kind B shows "Pick the word" and the masked meaning', (tester) async {
    await pump(tester, _collection(9));
    await answer(tester);
    await answer(tester);
    expect(find.text('Question 3 of 7'), findsOneWidget);
    expect(state().question!.kind, QuestionKind.meaningToWord);
    expect(find.text('Pick the word'), findsOneWidget);
    expect(find.text(state().question!.choice!.prompt), findsOneWidget);
  });

  group('gap questions', () {
    // One shared meaning: no kind B question, so every question is a gap (S-54).
    WordCollection receive() {
      final s = _collection(5, names: ['receive', 'tide', 'bay', 'cloud', 'stone']);
      for (final w in s.words) {
        w.definition = 'the same thing';
      }
      return s;
    }

    late int before;

    /// Answers until the "receive" gap shows; [before] = the results so far.
    Future<void> toGap(WidgetTester tester) async {
      await pump(tester, receive());
      while (state().question!.gap!.answer != 'receive') {
        await answer(tester);
      }
      before = sink.records.length;
    }

    testWidgets('AC-13: instruction, masked sentence, cue, exam field with Send and Skip; no hint', (tester) async {
      await toGap(tester);
      expect(find.text('Question ${before + 1} of 5'), findsOneWidget);
      expect(find.text('Type the missing word'), findsOneWidget);
      expect(find.text('We ___ it on the day.'), findsOneWidget);
      expect(find.text('слово0'), findsOneWidget);
      expect(find.textContaining('receive'), findsNothing);
      expect(find.byKey(const ValueKey('option-0')), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textInputAction, TextInputAction.send);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.byType(PronunciationButtons), findsNothing);
      expectNoVerdict();
    });

    testWidgets('AC-14: a wrong answer is final: read-only, no verdict, Next; repeat', (tester) async {
      await toGap(tester);
      await send(tester, 'accept');
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('We ___ it on the day.'), findsOneWidget);
      expectNoVerdict();
      expect(sink.records.last.label, WordResultLabel.repeat);
      expect(sink.records, hasLength(before + 1));
    });

    for (final (typed, label) in [
      ('recieve', WordResultLabel.known),
      (' Receive ', WordResultLabel.known),
      ('receiv', WordResultLabel.known),
      ('receives', WordResultLabel.repeat),
    ]) {
      testWidgets('AC-15: "$typed" is $label, with no verdict shown', (tester) async {
        await toGap(tester);
        await send(tester, typed);
        expectNoVerdict();
        expect(sink.records.last.label, label);
      });
    }

    testWidgets('AC-16: an empty or blank Send is not an answer', (tester) async {
      await toGap(tester);
      await send(tester, '   ');
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(sink.records, hasLength(before));
    });

    testWidgets('AC-17: Skip on a gap is final and repeat', (tester) async {
      await toGap(tester);
      await tapText(tester, 'Skip');
      expect(find.text('Next'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(sink.records.last.label, WordResultLabel.repeat);
    });
  });

  testWidgets('AC-17: Skip on a choice question is final; options do nothing after it', (tester) async {
    await pump(tester, _collection(9));
    await tapText(tester, 'Skip');
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('option-0')));
    await tester.pump();
    expect(optionColor(tester, 0), isNull);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-18, AC-23: Next moves on with no way back; the summary lists results and details', (tester) async {
    await pump(tester, _collection(7));
    final asked = state().questions;
    await tapText(tester, 'Skip'); // 1: choice, skipped
    await tapText(tester, 'Next');
    expect(find.text('Question 2 of 7'), findsOneWidget);
    await send(tester, 'accept'); // 2: gap, wrong
    await tapText(tester, 'Next');
    for (var i = 2; i < 7; i++) {
      expect(find.text('Question ${i + 1} of 7'), findsOneWidget);
      await answer(tester);
    }
    expect(find.text('5 of 7 known'), findsOneWidget);
    for (final q in asked) {
      expect(find.byKey(ValueKey('outcome-${q.rowId}')), findsOneWidget);
    }
    final ys = [for (final q in asked) tester.getTopLeft(find.byKey(ValueKey('outcome-${q.rowId}'))).dy];
    expect(ys, [...ys]..sort());
    final c = asked[0].choice!;
    expect(find.text('Answer: ${c.options[c.rightIndex]} · Skipped'), findsOneWidget);
    expect(find.text('Answer: ${asked[1].gap!.answer} · Yours: accept'), findsOneWidget);
    expect(find.text('Known'), findsNWidgets(5));
    expect(find.widgetWithText(ElevatedButton, 'Repeat'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Next round'), findsNothing);
    expect(sink.records, hasLength(7));
  });

  testWidgets('AC-24: all known: only Done, which returns to the learn page', (tester) async {
    await pump(tester, _collection(3));
    for (var i = 0; i < 3; i++) {
      await answer(tester);
    }
    expect(find.text('3 of 3 known'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Repeat'), findsNothing);
    await tapText(tester, 'Done');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
    expect(sink.records, hasLength(3));
  });

  testWidgets('AC-25, AC-26: Repeat asks only the repeat words at once, no call, no loading', (tester) async {
    await pump(tester, _collection(7));
    for (var i = 0; i < 7; i++) {
      await answer(tester, right: i != 2 && i != 5);
    }
    final calls = api.calls.length;
    await tester.tap(find.widgetWithText(ElevatedButton, 'Repeat'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    await answer(tester, right: false);
    expect(find.text('Question 2 of 2'), findsOneWidget);
    await answer(tester);
    expect(find.text('1 of 2 known'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Repeat'), findsOneWidget);
    expect(api.calls.length, calls);
    expect(sink.records, hasLength(9));
  });

  testWidgets('AC-08, AC-26: gaps unavailable: choice only, the line on every question, no Retry', (tester) async {
    api.error = LearnApiException(LearnApiError.dayLimit, '');
    await pump(tester, _collection(4));
    for (var i = 0; i < 4; i++) {
      expect(find.text('Gap questions are unavailable'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.text(exerciseDayLimitMessage), findsNothing);
      await answer(tester, right: false);
    }
    await tester.tap(find.widgetWithText(ElevatedButton, 'Repeat'));
    await tester.pump();
    expect(find.text('Gap questions are unavailable'), findsOneWidget);
  });

  testWidgets('AC-03: under 3 words: the not-enough line and Back, no Worker call', (tester) async {
    await pump(tester, _collection(2));
    expect(find.text(notEnoughWordsMessage), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(api.calls, isEmpty);
    await tapText(tester, 'Back');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-08: gaps unavailable and under 3 choice words: not enough', (tester) async {
    api.error = LearnApiException(LearnApiError.network, '');
    final s = _collection(3)..words.removeWhere((w) => w.rowId.startsWith('o'));
    await pump(tester, s);
    expect(find.text(notEnoughWordsMessage), findsOneWidget);
  });

  testWidgets('AC-10, AC-21: a History quiz records for that session; Back keeps what was answered', (tester) async {
    await pump(tester, _collection(9), collectionId: 'hist');
    for (var i = 0; i < 3; i++) {
      await answer(tester);
    }
    expect(api.calls.single.map((w) => w.rowId), everyElement(startsWith('r')));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
    expect(sink.records, hasLength(3));
    expect(sink.records.every((r) => r.collectionId == 'hist'), isTrue);
    await openQuiz(tester);
    expect(find.text('Question 1 of 7'), findsOneWidget);
    expect(sink.records, hasLength(3));
  });
}
