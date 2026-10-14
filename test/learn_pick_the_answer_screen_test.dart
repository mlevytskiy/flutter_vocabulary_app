import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/learn/pick_the_answer/pick_the_answer_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-pick-the-answer: the screen (AC-01, AC-04 – AC-07, AC-12, AC-14 – AC-20).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

class _NoNetwork implements LearnApiService {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('the exercise asked the server: ${i.memberName}');
}

Session _session(int count, {int extra = 0, Map<String, String> definitions = const {}}) {
  final words = [
    for (var i = 0; i < count + extra; i++)
      WordPair(
        word: 'word$i',
        translation: 'слово$i',
        definition: definitions['word$i'] ?? '',
        rowId: 'r$i',
      ),
  ];
  return Session.create()
    ..words = words
    ..groups = [
      WordGroup()
        ..id = 'g'
        ..name = 'G'
        ..rowIds = [for (var i = 0; i < count; i++) 'r$i'],
    ];
}

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, Session session,
      {String? sessionId, List<Override> extra = const []}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      exerciseRandomProvider.overrideWithValue(Random(3)),
      learnApiServiceProvider.overrideWithValue(_NoNetwork()),
      wordInputNotifierProvider.overrideWith(() => _FakeInput(session)),
      sessionByIdProvider('hist').overrideWith((ref) async => session),
      ...extra,
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => exerciseScreen('pick-the-answer', sessionId, 'g'),
              )),
              child: const Text('learn page'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    return container;
  }

  Color? colorOf(WidgetTester tester, int i) =>
      tester.widget<ElevatedButton>(find.byKey(ValueKey('option-$i'))).style?.backgroundColor?.resolve({});

  Future<void> tapRight(WidgetTester tester, ProviderContainer c, {String? sessionId}) async {
    final s = c.read(pickTheAnswerProvider(sessionId, 'g')).requireValue;
    await tester.tap(find.byKey(ValueKey('option-${s.question!.rightIndex}')));
    await tester.pump();
  }

  testWidgets('AC-01, AC-03: title, counter, line, first word and four options', (tester) async {
    await pump(tester, _session(5));
    expect(find.text('Pick the right answer'), findsOneWidget);
    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(find.text('Pick the translation'), findsOneWidget);
    expect(find.text('word0'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(4));
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('AC-05, AC-07: a right tap turns green, locks the options, shows Next; Next shows question 2 as Pick the word (AC-03)', (tester) async {
    final c = await pump(tester, _session(5));
    await tapRight(tester, c);
    final s = c.read(pickTheAnswerProvider(null, 'g')).requireValue;
    expect(colorOf(tester, s.question!.rightIndex), Colors.green);
    expect([for (var i = 0; i < 4; i++) colorOf(tester, i)].where((x) => x == Colors.red), isEmpty);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Question 2 of 5'), findsOneWidget);
    expect(find.text('Pick the word'), findsOneWidget);
    expect(find.text('слово1'), findsOneWidget, reason: 'AC-04: no definition, so the translation');
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('AC-06: a wrong tap is red, the right one green, a later tap changes nothing', (tester) async {
    final c = await pump(tester, _session(5));
    final right = c.read(pickTheAnswerProvider(null, 'g')).requireValue.question!.rightIndex;
    final wrong = (right + 1) % 4;
    await tester.tap(find.byKey(ValueKey('option-$wrong')));
    await tester.pump();
    expect(colorOf(tester, wrong), Colors.red);
    expect(colorOf(tester, right), Colors.green);
    await tester.tap(find.byKey(ValueKey('option-$right')));
    await tester.pump();
    expect(colorOf(tester, wrong), Colors.red);
    expect(c.read(pickTheAnswerProvider(null, 'g')).requireValue.results, [false]);
  });

  testWidgets('AC-04: the definition shows with the word masked', (tester) async {
    final c = await pump(tester, _session(5, definitions: {'word1': 'A word1 is a thing'}));
    await tapRight(tester, c);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('A ___ is a thing'), findsOneWidget);
  });

  testWidgets('AC-07, AC-15: the last Next opens the summary with Right/Missed and Done returns to the learn page', (tester) async {
    final c = await pump(tester, _session(5));
    for (var i = 0; i < 5; i++) {
      if (i == 1) {
        final right = c.read(pickTheAnswerProvider(null, 'g')).requireValue.question!.rightIndex;
        await tester.tap(find.byKey(ValueKey('option-${(right + 1) % 4}')));
        await tester.pump();
      } else {
        await tapRight(tester, c);
      }
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.text('Right'), findsNWidgets(4));
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('word0'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-12: fewer than 3 usable words show only the message and Back', (tester) async {
    await pump(tester, _session(2));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-14: a read error shows the failed line and Retry; Retry starts round 1', (tester) async {
    var fail = true;
    await pump(tester, _session(5), extra: [
      exerciseWordsProvider(null, 'g').overrideWith((ref) async {
        if (fail) throw StateError('cannot read');
        return (
          group: [for (var i = 0; i < 5; i++) WordPair(word: 'word$i', translation: 'слово$i', rowId: 'r$i')],
          others: <WordPair>[],
        );
      }),
    ]);
    expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 5'), findsOneWidget);
  });

  testWidgets('AC-16, AC-17: Back mid-round keeps nothing; a History session is used and unchanged', (tester) async {
    final hist = _session(5);
    final before = hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList();
    final updated = hist.updatedAt;
    final c = await pump(tester, hist, sessionId: 'hist');
    expect(find.text('Question 1 of 5'), findsOneWidget);
    await tapRight(tester, c, sessionId: 'hist');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(hist.words.map((w) => '${w.word}|${w.translation}|${w.definition}|${w.rowId}').toList(), before);
    expect(hist.updatedAt, updated);
  });

  testWidgets('AC-18: no learnApiService call (the override throws on any)', (tester) async {
    final c = await pump(tester, _session(13));
    for (var i = 0; i < 7; i++) {
      await tapRight(tester, c);
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.text('Next round'), findsOneWidget);
    await tester.tap(find.text('Next round'));
    await tester.pump();
    expect(find.text('Question 1 of 6'), findsOneWidget);
    expect(find.text('Pick the translation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-20: a long definition wraps, the screen scrolls', (tester) async {
    final long = 'This is a very long definition that runs over several lines and more. ' * 4;
    final c = await pump(tester, _session(5, definitions: {'word1': long.trim()}));
    await tapRight(tester, c);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
