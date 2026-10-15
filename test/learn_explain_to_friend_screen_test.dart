import 'dart:async';
import 'dart:math';

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
import 'package:flutter_vocabulary_app/features/learn/explain_to_friend/explain_to_friend_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exam_countdown.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_random.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exercise_words.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-explain-to-friend: the screen in both modes (AC-01, AC-02, AC-04 –
/// AC-30, AC-33, AC-34, AC-36 – AC-38; §6 call counts, countdown, timing).
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
    final next = replies.isEmpty ? (usesWord: false, usesTask: true, ok: true, fixed: '', note: '') : replies.removeAt(0);
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
    expect(exerciseId, 'explain-to-friend');
    records.add((sessionId: sessionId, rowId: rowId, label: label));
    return Completer<void>().future; // never completes: the screen never waits for it
  }

  @override
  Map<String, WordResult> latest(Session session) => const {};
}

const _typeText = 'Type it in English in 90 seconds. The AI checks it.';
const _friendText = 'Say it aloud in 30 seconds. The person next to you decides. Results are not saved.';
const _checkFailed = 'Could not check the sentence. Check the connection and try again.';

Session _session(int count, {List<String>? names}) {
  final words = [
    for (var i = 0; i < count; i++)
      WordPair(word: names?[i] ?? 'word$i', translation: 'берег$i', rowId: 'r$i')..definition = 'def$i',
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

  Future<void> pump(WidgetTester tester, Session session, {String? sessionId, Future<List<WordPair>> Function()? read}) async {
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
      if (read != null)
        exerciseWordsProvider(sessionId, 'g').overrideWith((ref) async => (group: await read(), others: const <WordPair>[])),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => exerciseScreen('explain-to-friend', sessionId, 'g'),
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

  ExplainState state() => container.read(explainToFriendProvider(openedFor, 'g')).requireValue;

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

  bool readOnly(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).readOnly;

  Future<void> leave(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
  }

  group('opening and mode', () {
    testWidgets('AC-01: the title and the mode question, Type first; no word yet; no Worker call', (tester) async {
      await pump(tester, _session(8));
      expect(find.widgetWithText(AppBar, 'Explain it to a friend'), findsOneWidget);
      expect(find.text('How will you explain the words?'), findsOneWidget);
      expect(find.text(_typeText), findsOneWidget);
      expect(find.text(_friendText), findsOneWidget);
      expect(tester.getTopLeft(find.text('Type')).dy, lessThan(tester.getTopLeft(find.text('With a friend')).dy));
      expect(find.widgetWithText(FilledButton, 'Type'), findsOneWidget);
      expect(find.textContaining(RegExp(r'word\d')), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(api.checks, isEmpty);
      expect(sink.records, isEmpty);
    });

    for (final mode in ['Type', 'With a friend']) {
      testWidgets('AC-02: $mode starts "Word 1 of 4"; round 2 is the same mode without the question', (tester) async {
        await pump(tester, _session(8));
        await tapText(tester, mode);
        expect(find.text('Word 1 of 4'), findsOneWidget);
        expect(find.text('How will you explain the words?'), findsNothing);
        for (var i = 0; i < 4; i++) {
          await tapText(tester, 'Skip');
          await tapText(tester, 'Next');
        }
        await tester.pumpAndSettle();
        await tapText(tester, 'Next round');
        expect(find.text('Word 1 of 4'), findsOneWidget);
        expect(find.text('How will you explain the words?'), findsNothing);
        expect(find.byType(TextField), mode == 'Type' ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('AC-04: under 3 usable words shows only Not enough and Back, no mode question', (tester) async {
      await pump(tester, _session(2));
      expect(find.text('Not enough words for this exercise'), findsOneWidget);
      expect(find.text('How will you explain the words?'), findsNothing);
      await tapText(tester, 'Back');
      await tester.pumpAndSettle();
      expect(find.text('learn page'), findsOneWidget);
      expect(api.checks, isEmpty);
    });

    testWidgets('AC-05: a word without a translation is never asked', (tester) async {
      final s = _session(4);
      s.words[1].translation = '';
      await pump(tester, s);
      await tapText(tester, 'With a friend');
      expect(find.text('Word 1 of 3'), findsOneWidget);
      expect({for (final c in state().cards) c.rowId}, {'r0', 'r2', 'r3'});
    });

    testWidgets('AC-06: a failed read shows the load line and Retry; Retry then shows the mode question', (tester) async {
      var fail = true;
      final s = _session(3);
      await pump(tester, s, read: () async {
        if (fail) throw StateError('read failed');
        return s.words;
      });
      expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
      expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsNothing);
      fail = false;
      await tapText(tester, 'Retry');
      await tester.pumpAndSettle();
      expect(find.text('How will you explain the words?'), findsOneWidget);
    });
  });

  group('Type', () {
    testWidgets('AC-07, §6: counter, word, prompt, 1:30, field with Send, Skip; no hint of any kind', (tester) async {
      await pump(tester, _session(8));
      await tapText(tester, 'Type');
      final card = state().card!;
      expect(find.text('Word 1 of 4'), findsOneWidget);
      expect(find.text(card.word), findsOneWidget);
      expect(find.text('Explain “${card.word}” in English. Do not use the word or a translation.'), findsOneWidget);
      expect(find.text('1:30'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textInputAction, TextInputAction.send);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.textContaining(card.translation), findsNothing);
      expect(find.textContaining('def'), findsNothing);
      expect(find.byType(Text), findsNWidgets(6)); // title, counter, word, prompt, countdown, Skip
      expect(api.checks, isEmpty);
    });

    testWidgets('AC-08, AC-09: the countdown counts on while typing and after a refused Send', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:29'), findsOneWidget);
      await send(tester, 'one');
      expect(find.text('Write a full sentence'), findsOneWidget);
      expect(readOnly(tester), isFalse);
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('1:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('0:01'), findsOneWidget);
      expect(api.checks, isEmpty);
    });

    testWidgets('AC-10: over 300 characters is refused and the countdown runs', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await send(tester, 'word ' * 70);
      expect(find.text('Keep it under three hundred characters'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:29'), findsOneWidget);
      expect(api.checks, isEmpty);
    });

    testWidgets('AC-11, AC-14, §6: Send at 0:40 stops the countdown; Checking…, then Good and Next; task explain, no extra; known',
        (tester) async {
      api.checkGate = Completer();
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      final card = state().card!;
      await tester.pump(const Duration(seconds: 50));
      expect(find.text('0:40'), findsOneWidget);
      await send(tester, 'The land along the edge of the sea or a lake.');
      expect(find.byType(ExamCountdown), findsNothing);
      expect(find.text('Checking…'), findsOneWidget);
      expect(readOnly(tester), isTrue);
      await tester.pump(const Duration(seconds: 40));
      expect(find.text('Time is up'), findsNothing);
      expect(api.checks, hasLength(1));
      api.checkGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      final r = api.checks.single;
      expect((r.word, r.translation, r.sentence, r.task, r.extra),
          (card.word, card.translation, 'The land along the edge of the sea or a lake.', LearnCheckTask.explain, ''));
      expect(sink.records.single.label, WordResultLabel.known);
    });

    testWidgets('AC-12: at zero the typed text is sent once and the keyboard closes', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await tester.enterText(find.byType(TextField), 'the land at the edge of the sea');
      await tester.pump(const Duration(seconds: 90));
      await tester.pump();
      expect(api.checks.single.sentence, 'the land at the edge of the sea');
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
      expect(find.text('Good'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      expect(api.checks, hasLength(1));
      expect(sink.records.single.label, WordResultLabel.known);
    });

    for (final (name, text) in [('empty', ''), ('one word', 'land'), ('over 300', 'word ' * 70)]) {
      testWidgets('AC-13: at zero with $name text: nothing sent, read-only, no Skip, Time is up, Next, repeat', (tester) async {
        await pump(tester, _session(3));
        await tapText(tester, 'Type');
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(seconds: 90));
        expect(api.checks, isEmpty);
        expect(readOnly(tester), isTrue);
        expect(find.text('Skip'), findsNothing);
        expect(find.text('Time is up'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(sink.records.single.label, WordResultLabel.repeat);
      });
    }

    testWidgets('AC-15: grammar errors are Good with no corrected text', (tester) async {
      api.replies.add((usesWord: false, usesTask: true, ok: false, fixed: 'The land which is near the sea.', note: 'Spelling.'));
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await send(tester, 'the land wich is near see');
      expect(find.text('Good'), findsOneWidget);
      expect(find.textContaining('which'), findsNothing);
      expect(sink.records.single.label, WordResultLabel.known);
    });

    testWidgets('AC-16: the word in any case is refused with its note, even when the check calls it fine', (tester) async {
      await pump(tester, _session(3, names: ['shore', 'borrow', 'allow']));
      await tapText(tester, 'Type');
      final word = state().card!.word;
      await send(tester, '${word.toUpperCase()}S are things.');
      expect(find.text('Do not use “$word” in your explanation.'), findsOneWidget);
      expect(find.text('Good'), findsNothing);
      expect(sink.records.single.label, WordResultLabel.repeat);
    });

    testWidgets('AC-17: Ukrainian letters are refused', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await send(tester, 'it is берег, where sea meets land');
      expect(find.text('Explain it in English only.'), findsOneWidget);
      expect(sink.records.single.label, WordResultLabel.repeat);
    });

    testWidgets("AC-18: a wrong meaning shows the check's note, or the fixed note when it has none", (tester) async {
      api.replies
        ..add((usesWord: false, usesTask: false, ok: false, fixed: '', note: 'That is a money bank; explain the side of a river.'))
        ..add((usesWord: false, usesTask: false, ok: false, fixed: '', note: ''));
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await send(tester, 'A place where you keep your money.');
      expect(find.text('That is a money bank; explain the side of a river.'), findsOneWidget);
      await tapText(tester, 'Next');
      final word = state().card!.word;
      await send(tester, 'A place where you keep your money.');
      expect(find.text('This does not explain “$word”.'), findsOneWidget);
      expect(sink.records.map((r) => r.label), [WordResultLabel.repeat, WordResultLabel.repeat]);
    });

    testWidgets('AC-19: a checked word cannot be sent again; only Next moves on', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await send(tester, 'The land by the sea.');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(api.checks, hasLength(1));
      expect(readOnly(tester), isTrue);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('AC-20: Skip sends nothing, hides the countdown, Skipped and Next; repeat', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await tapText(tester, 'Skip');
      expect(api.checks, isEmpty);
      expect(find.byType(ExamCountdown), findsNothing);
      expect(readOnly(tester), isTrue);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(sink.records.single.label, WordResultLabel.repeat);
    });

    testWidgets('AC-21, AC-22: a failed check: error, Retry, Skip, no countdown; Retry later resends exactly it', (tester) async {
      api.replies.add(LearnApiException(LearnApiError.network, 'x'));
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await send(tester, 'The land by the sea.');
      expect(find.text(_checkFailed), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.byType(ExamCountdown), findsNothing);
      expect(readOnly(tester), isTrue);
      expect(sink.records, isEmpty);
      await tester.pump(const Duration(seconds: 200));
      await tapText(tester, 'Retry');
      await tester.pump();
      expect(api.checks.map((c) => c.sentence), ['The land by the sea.', 'The land by the sea.']);
      expect(find.text('Good'), findsOneWidget);
      expect(sink.records, hasLength(1));
    });

    testWidgets('AC-23: too many requests at zero shows its line and Retry resends', (tester) async {
      api.replies.add(LearnApiException(LearnApiError.rateLimited, 'x'));
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await tester.enterText(find.byType(TextField), 'The land by the sea.');
      await tester.pump(const Duration(seconds: 90));
      await tester.pump();
      expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
      expect(readOnly(tester), isTrue);
      await tapText(tester, 'Retry');
      await tester.pump();
      expect(api.checks.map((c) => c.sentence), ['The land by the sea.', 'The land by the sea.']);
    });

    testWidgets('AC-24, AC-25: the day limit: no Retry, Skip is Not checked with no result; the next send shows it again',
        (tester) async {
      api.replies
        ..add(LearnApiException(LearnApiError.dayLimit, 'x'))
        ..add(LearnApiException(LearnApiError.dayLimit, 'x'));
      await pump(tester, _session(3));
      await tapText(tester, 'Type');
      await send(tester, 'The land by the sea.');
      expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      await tapText(tester, 'Skip');
      expect(find.text('Not checked'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(sink.records, isEmpty);
      await tapText(tester, 'Next');
      await send(tester, 'The land by the sea.');
      expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    });

    testWidgets('AC-33: leaving with text typed and a check running records nothing more; nothing at zero; reopening asks again',
        (tester) async {
      await pump(tester, _session(4));
      await tapText(tester, 'Type');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
      await send(tester, 'The land by the sea.');
      await tapText(tester, 'Next');
      // Third card: a check still running.
      api.checkGate = Completer();
      await send(tester, 'The land by the sea.');
      await leave(tester);
      api.checkGate!.complete();
      await tester.pump(const Duration(seconds: 120));
      expect(sink.records, hasLength(2));
      expect(api.checks, hasLength(2));
      // Reopen, type, leave before zero.
      api.checkGate = null;
      await tester.tap(find.text('learn page'));
      await tester.pumpAndSettle();
      expect(find.text('How will you explain the words?'), findsOneWidget);
      await tapText(tester, 'Type');
      expect(find.text('Word 1 of 4'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'The land by the sea.');
      await tester.pump(const Duration(seconds: 70));
      await leave(tester);
      await tester.pump(const Duration(seconds: 60));
      expect(api.checks, hasLength(2));
      expect(sink.records, hasLength(2));
    });

    testWidgets('AC-34: a History session is used; results go to it; the session is unchanged', (tester) async {
      final s = _session(3);
      final before = s.words.map((w) => w.word).toList();
      await pump(tester, s, sessionId: 'hist');
      await tapText(tester, 'Type');
      await send(tester, 'The land by the sea.');
      expect(api.checks.single.word, state().card!.word);
      expect(sink.records.single.sessionId, 'hist');
      expect(s.words.map((w) => w.word).toList(), before);
      expect(s.groups.single.rowIds, ['r0', 'r1', 'r2']);
    });

    testWidgets('AC-36, AC-38: the Type summary with details, then Done only', (tester) async {
      api.replies
        ..add((usesWord: false, usesTask: true, ok: true, fixed: '', note: ''))
        ..add((usesWord: false, usesTask: false, ok: false, fixed: '', note: 'Not it.'))
        ..add(LearnApiException(LearnApiError.network, 'x'));
      await pump(tester, _session(5));
      await tapText(tester, 'Type');
      await send(tester, 'Land by the sea.');
      await tapText(tester, 'Next');
      await send(tester, 'To get money for a while.');
      await tapText(tester, 'Next');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
      await tester.pump(const Duration(seconds: 90));
      await tapText(tester, 'Next');
      await send(tester, 'Take it fast.');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
      await tester.pumpAndSettle();
      expect(find.text('1 of 5 known'), findsOneWidget);
      for (final t in ['Yours: Land by the sea.', 'Yours: To get money for a while.', 'Skipped', 'Time up', 'Yours: Take it fast.']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Not checked'), findsOneWidget);
      expect(find.text('Repeat'), findsNWidgets(3));
      expect(find.text('Next round'), findsNothing);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(sink.records, hasLength(4));
      await tapText(tester, 'Done');
      await tester.pumpAndSettle();
      expect(find.text('learn page'), findsOneWidget);
      expect(sink.records, hasLength(4));
    });
  });

  group('With a friend', () {
    testWidgets('AC-26: counter, word, aloud prompt, 0:30, Done and Skip; no field, translation or definition', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'With a friend');
      final card = state().card!;
      expect(find.text('Word 1 of 3'), findsOneWidget);
      expect(find.text(card.word), findsOneWidget);
      expect(find.text('Explain “${card.word}” aloud to the person next to you. Do not say the word or a translation.'), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining(card.translation), findsNothing);
      expect(find.textContaining('def'), findsNothing);
    });

    testWidgets('AC-27, AC-28: at zero the question shows; Understood is final and known; a second tap changes nothing',
        (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'With a friend');
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(ExamCountdown), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Did they understand?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Did they understand?'), findsOneWidget);
      await tapText(tester, 'Understood');
      expect(find.text('Understood'), findsOneWidget);
      expect(find.text('Not yet'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
      expect(state().result!.known, isTrue);
      await tester.tap(find.text('Understood'));
      await tester.pump();
      expect(state().result!.friend, FriendAnswer.understood);
    });

    testWidgets('AC-27, AC-28: Done early asks; Not yet is repeat', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'With a friend');
      await tester.pump(const Duration(seconds: 5));
      await tapText(tester, 'Done');
      expect(find.text('Did they understand?'), findsOneWidget);
      expect(find.byType(ExamCountdown), findsNothing);
      await tapText(tester, 'Not yet');
      expect(find.text('Not yet'), findsOneWidget);
      expect(find.text('Understood'), findsNothing);
      expect(state().result!.known, isFalse);
    });

    testWidgets('AC-29: Skip before the tap shows Skipped and Next', (tester) async {
      await pump(tester, _session(3));
      await tapText(tester, 'With a friend');
      await tapText(tester, 'Skip');
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Did they understand?'), findsNothing);
      await tester.pump(const Duration(seconds: 40));
      expect(find.text('Did they understand?'), findsNothing);
    });

    testWidgets('AC-30, AC-37, AC-38: a full friend exam: summary, no Worker call, no result saved', (tester) async {
      await pump(tester, _session(6));
      await tapText(tester, 'With a friend');
      await tapText(tester, 'Done');
      await tapText(tester, 'Understood');
      await tapText(tester, 'Next');
      await tester.pump(const Duration(seconds: 30));
      await tapText(tester, 'Not yet');
      await tapText(tester, 'Next');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 known'), findsOneWidget);
      expect(find.text('Known'), findsOneWidget);
      expect(find.text('Repeat'), findsNWidgets(2));
      expect(find.text('Understood'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
      await tapText(tester, 'Next round');
      expect(find.text('Word 1 of 3'), findsOneWidget);
      expect(find.text('0:30'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tapText(tester, 'Skip');
        await tapText(tester, 'Next');
      }
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Next round'), findsNothing);
      expect(api.checks, isEmpty);
      expect(sink.records, isEmpty);
    });
  });
}
