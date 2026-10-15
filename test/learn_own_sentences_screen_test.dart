import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/exam_result_sink.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/own_sentences/own_sentences_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'dart:math';

/// learn-own-sentences: the screen (AC-01, AC-04 – AC-23, AC-26, AC-27, AC-29,
/// AC-30; §6 call counts and feedback timing).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

class _Api implements LearnApiService {
  final checks = <LearnCheckRequest>[];
  final replies = <Object>[];
  Completer<void>? checkGate;

  @override
  Future<CheckReply> check(LearnCheckRequest request) async {
    checks.add(request);
    if (checkGate != null) await checkGate!.future;
    final next = replies.isEmpty ? (usesWord: true, usesTask: true, ok: true, fixed: '', note: '') : replies.removeAt(0);
    if (next is CheckReply) return next;
    throw next;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

class _Sink implements ExamResultSink {
  final records = <({String? sessionId, String rowId, WordResultLabel label})>[];

  @override
  Future<void> record({
    required String? sessionId,
    required String rowId,
    required String exerciseId,
    required WordResultLabel label,
  }) {
    expect(exerciseId, 'own-sentences');
    records.add((sessionId: sessionId, rowId: rowId, label: label));
    return Completer<void>().future;
  }

  @override
  Map<String, WordResult> latest(Session session) => const {};
}

Session _session(int count) {
  final words = [
    for (var i = 0; i < count; i++) WordPair(word: 'word$i', translation: 'берег$i', rowId: 'r$i'),
  ];
  return Session.create()
    ..words = words
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

  Future<void> pump(WidgetTester tester, Session session, {String? sessionId}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    openedFor = sessionId;
    container = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      examResultSinkProvider.overrideWithValue(sink),
      exerciseRandomProvider.overrideWithValue(Random(3)),
      wordInputNotifierProvider.overrideWith(() => _FakeInput(session)),
      sessionByIdProvider('hist').overrideWith((ref) async => session),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => exerciseScreen('own-sentences', sessionId, 'g'),
              )),
              child: const Text('learn page'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
  }

  OwnState state() => container.read(ownSentencesProvider(openedFor, 'g')).requireValue;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pump();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('AC-01, AC-07: title, counter, word, prompt, field, Skip; no hint of any kind; no Worker call', (tester) async {
    await pump(tester, _session(8));
    final card = state().card!;
    expect(find.widgetWithText(AppBar, 'Make your own sentences'), findsOneWidget);
    expect(find.text('Word 1 of 4'), findsOneWidget);
    expect(find.text(card.word), findsOneWidget);
    expect(find.text('Write a sentence with “${card.word}”.'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.textInputAction, TextInputAction.send);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.textContaining(card.translation), findsNothing);
    expect(find.textContaining('def'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(api.checks, isEmpty);
  });

  testWidgets('AC-08, AC-09: an invalid text sends nothing', (tester) async {
    await pump(tester, _session(3));
    await send(tester, '   ');
    expect(find.text('Write a full sentence'), findsOneWidget);
    await send(tester, 'one');
    expect(find.text('Write a full sentence'), findsOneWidget);
    await send(tester, 'word ' * 50);
    expect(find.text('Keep it under two hundred characters'), findsOneWidget);
    expect(api.checks, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets('AC-10, AC-17, §6: Checking…, then Good, Next; the check gets task own with no extra; record at once',
      (tester) async {
    api.checkGate = Completer();
    await pump(tester, _session(3));
    final card = state().card!;
    await tester.enterText(find.byType(TextField), 'We sat on the ${card.word} for a long time.');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text('Checking…'), findsOneWidget);
    api.checkGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    final r = api.checks.single;
    expect((r.word, r.translation, r.task, r.extra), (card.word, card.translation, LearnCheckTask.own, ''));
    expect(sink.records.single.label, WordResultLabel.known);
  });

  testWidgets('AC-11: the word in another case or with -s counts', (tester) async {
    await pump(tester, _session(3));
    final card = state().card!;
    await send(tester, 'Both ${card.word.toUpperCase()}s were wet.');
    expect(find.text('Good'), findsOneWidget);
    expect(sink.records.single.label, WordResultLabel.known);
  });

  testWidgets('AC-12: a fixed sentence with the word in bold and the note; repeat', (tester) async {
    api.replies.add((usesWord: true, usesTask: true, ok: false, fixed: 'We walked to the word0.', note: 'Fix the verb.'));
    await pump(tester, _session(3));
    final card = state().card!;
    await send(tester, 'We walk to the ${card.word}.');
    expect(find.text('Fix the verb.'), findsOneWidget);
    expect(find.textContaining('We walked to the'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-13, AC-15: correct English without the word (or only in another form) is repeat with the note', (tester) async {
    await pump(tester, _session(3));
    final card = state().card!;
    await send(tester, 'We sat on the beach.');
    expect(find.text('Use “${card.word}” in your sentence.'), findsOneWidget);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-14: a sentence in another sense is fixed with a note; the translation stays hidden', (tester) async {
    api.replies.add((usesWord: false, usesTask: true, ok: false, fixed: 'We sat by the river.', note: 'Wrong sense.'));
    await pump(tester, _session(3));
    final card = state().card!;
    await send(tester, 'I keep money in the ${card.word}.');
    expect(find.text('Wrong sense.'), findsOneWidget);
    expect(find.textContaining(card.translation), findsNothing);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-16: a "fix" equal to the sentence is Good and known', (tester) async {
    await pump(tester, _session(3));
    final card = state().card!;
    api.replies.add((usesWord: true, usesTask: true, ok: false, fixed: 'WE SAT BY THE ${card.word.toUpperCase()}', note: 'n'));
    await send(tester, 'We sat by the ${card.word}.');
    expect(find.text('Good'), findsOneWidget);
    expect(sink.records.single.label, WordResultLabel.known);
  });

  testWidgets('AC-18: Skip sends no check, shows Skipped and Next; repeat', (tester) async {
    await pump(tester, _session(3));
    await tapText(tester, 'Skip');
    expect(api.checks, isEmpty);
    expect(find.text('Skipped'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.text('Next'), findsOneWidget);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-19, AC-20: a failed check keeps the text locked, shows Retry; Retry resends the same text', (tester) async {
    api.replies.add(LearnApiException(LearnApiError.network, 'x'));
    await pump(tester, _session(3));
    await send(tester, 'We sat by the shore long.');
    expect(find.text('Could not check the sentence. Check the connection and try again.'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(sink.records, isEmpty);
    await tapText(tester, 'Retry');
    await tester.pump();
    expect(api.checks.map((c) => c.sentence), ['We sat by the shore long.', 'We sat by the shore long.']);
    expect(find.text('Next'), findsOneWidget);
    expect(sink.records, hasLength(1));
  });

  testWidgets('AC-21: too many requests shows its line and Retry', (tester) async {
    api.replies.add(LearnApiException(LearnApiError.rateLimited, 'x'));
    await pump(tester, _session(3));
    await send(tester, 'We sat by the shore long.');
    expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('AC-22, AC-23: the day limit keeps Skip and no Retry; Skip is not checked, no word result', (tester) async {
    api.replies.add(LearnApiException(LearnApiError.dayLimit, 'x'));
    await pump(tester, _session(3));
    await send(tester, 'We sat by the shore long.');
    expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tapText(tester, 'Skip');
    expect(find.text('Not checked'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(sink.records, isEmpty);
    for (var i = 0; i < 2; i++) {
      await tapText(tester, 'Next');
      await tapText(tester, 'Skip');
    }
    await tapText(tester, 'Next');
    await tester.pumpAndSettle();
    expect(find.text('Not checked'), findsOneWidget);
    expect(find.text('Repeat'), findsNWidgets(2));
    expect(sink.records, hasLength(2));
  });

  testWidgets('AC-29, AC-30: the summary of a 6-word group in two rounds; Next round, then Done only', (tester) async {
    await pump(tester, _session(6));
    expect(find.text('Word 1 of 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await send(tester, 'We sat by the ${state().card!.word} long.');
      await tapText(tester, 'Next');
    }
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 known'), findsOneWidget);
    expect(find.textContaining('Yours: We sat by the'), findsNWidgets(3));
    expect(find.text('Next round'), findsOneWidget);
    await tapText(tester, 'Next round');
    expect(find.text('Word 1 of 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
    }
    await tester.pumpAndSettle();
    expect(find.text('0 of 3 known'), findsOneWidget);
    expect(find.text('Skipped'), findsNWidgets(3));
    expect(find.text('Next round'), findsNothing);
    expect(find.textContaining('Repeat'), findsNWidgets(3)); // result labels only, no button
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tapText(tester, 'Done');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
    expect(sink.records, hasLength(6));
  });

  testWidgets('AC-26: leaving mid-check ignores the late answer; reopening starts at word 1', (tester) async {
    api.checkGate = Completer();
    await pump(tester, _session(3));
    await tapText(tester, 'Skip');
    await tapText(tester, 'Next');
    await tester.enterText(find.byType(TextField), 'We sat by the shore long.');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    api.checkGate!.complete();
    await tester.pumpAndSettle();
    expect(sink.records, hasLength(1));
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 3'), findsOneWidget);
  });

  testWidgets('AC-04: under 3 usable words shows Not enough and Back', (tester) async {
    await pump(tester, _session(2));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    await tapText(tester, 'Back');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-05: a word without a translation is never asked', (tester) async {
    final s = _session(4);
    s.words[1].translation = '';
    await pump(tester, s);
    expect(find.text('Word 1 of 3'), findsOneWidget);
    expect({for (final c in state().cards) c.rowId}, {'r0', 'r2', 'r3'});
  });

  testWidgets('AC-27: a History session is used; results go to it; the session is unchanged', (tester) async {
    final s = _session(3);
    final before = s.words.map((w) => w.word).toList();
    await pump(tester, s, sessionId: 'hist');
    await tapText(tester, 'Skip');
    expect(sink.records.single.sessionId, 'hist');
    expect(s.words.map((w) => w.word).toList(), before);
    expect(s.groups.single.rowIds, ['r0', 'r1', 'r2']);
  });
}
