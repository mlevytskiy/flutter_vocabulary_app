import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/exam_countdown.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/sentence_check.dart';

/// learn-explain-to-friend S-61: the kit's exam countdown and the optional time
/// limit of the sentence field (AC-08 – AC-13, AC-20 – AC-22; §6 countdown).
class _Api implements LearnApiService {
  final requests = <LearnCheckRequest>[];
  final replies = <Object>[];
  Completer<void>? gate;

  @override
  Future<CheckReply> check(LearnCheckRequest request) async {
    requests.add(request);
    if (gate != null) await gate!.future;
    final next = replies.isEmpty ? (usesWord: false, usesTask: true, ok: true, fixed: '', note: '') : replies.removeAt(0);
    if (next is CheckReply) return next;
    throw next;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

void main() {
  group('ExamCountdown', () {
    test('m:ss text', () {
      expect([for (final s in [90, 89, 60, 30, 1, 0]) countdownText(s)], ['1:30', '1:29', '1:00', '0:30', '0:01', '0:00']);
    });

    testWidgets('counts down once a second and calls onZero exactly once; nothing after dispose', (tester) async {
      var zero = 0;
      await tester.pumpWidget(MaterialApp(home: ExamCountdown(seconds: 3, onZero: () => zero++)));
      expect(find.text('0:03'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:02'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:00'), findsOneWidget);
      expect(zero, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(zero, 1);

      zero = 0;
      await tester.pumpWidget(MaterialApp(home: ExamCountdown(key: const ValueKey('b'), seconds: 2, onZero: () => zero++)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 5));
      expect(zero, 0);
    });
  });

  group('SentenceCheckField with timeLimitSeconds', () {
    late _Api api;
    late List<SentenceResult> done;

    setUp(() {
      api = _Api();
      done = [];
    });

    Future<void> pumpField(WidgetTester tester, {int? limit = 90, SentenceCheckMode mode = SentenceCheckMode.exam}) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [learnApiServiceProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: SentenceCheckField(
              key: const ValueKey('check-r0'),
              word: 'shore',
              translation: 'берег',
              task: LearnCheckTask.explain,
              mode: mode,
              timeLimitSeconds: limit,
              onDone: done.add,
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
    }

    bool readOnly(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).readOnly;

    testWidgets('without a limit there is no countdown (built exercises unchanged)', (tester) async {
      await pumpField(tester, limit: null);
      expect(find.byType(ExamCountdown), findsNothing);
      await tester.pump(const Duration(seconds: 200));
      expect(done, isEmpty);
    });

    testWidgets('AC-08: the countdown shows above the field and counts on while typing and after a refused Send', (tester) async {
      await pumpField(tester);
      expect(find.text('1:30'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(ExamCountdown)).dy, lessThan(tester.getTopLeft(find.byType(TextField)).dy));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:29'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'one');
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('1:00'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(find.text('Write a full sentence'), findsOneWidget);
      expect(readOnly(tester), isFalse);
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('0:01'), findsOneWidget);
      expect(api.requests, isEmpty);
      expect(done, isEmpty);
    });

    testWidgets('AC-10: an over-long Send is refused and the countdown keeps running', (tester) async {
      await pumpField(tester);
      await send(tester, 'word ' * 70);
      expect(find.text('Keep it under three hundred characters'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1:29'), findsOneWidget);
    });

    testWidgets('AC-11: a valid Send stops and hides the countdown; nothing more at zero', (tester) async {
      api.gate = Completer();
      await pumpField(tester);
      await tester.pump(const Duration(seconds: 50));
      expect(find.text('0:40'), findsOneWidget);
      await send(tester, 'The land at the edge of the sea.');
      expect(find.byType(ExamCountdown), findsNothing);
      expect(find.text('Checking…'), findsOneWidget);
      expect(readOnly(tester), isTrue);
      await tester.pump(const Duration(seconds: 60));
      expect(api.requests, hasLength(1));
      expect(find.text('Checking…'), findsOneWidget);
      expect(done, isEmpty);
      api.gate!.complete();
      await tester.pump();
      expect(done.single.outcome, SentenceOutcome.right);
      expect(done.single.timedOut, isFalse);
    });

    testWidgets('AC-12: at zero a valid typed text is sent once as a Send would, and the keyboard closes', (tester) async {
      api.gate = Completer();
      await pumpField(tester);
      await tester.enterText(find.byType(TextField), '  the land at the edge of the sea ');
      await tester.pump(const Duration(seconds: 90));
      await tester.pump();
      expect(api.requests.single.sentence, 'the land at the edge of the sea');
      expect(api.requests.single.task, LearnCheckTask.explain);
      expect(api.requests.single.extra, '');
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
      expect(find.byType(ExamCountdown), findsNothing);
      expect(find.text('Checking…'), findsOneWidget);
      api.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(api.requests, hasLength(1));
      expect(done.single.outcome, SentenceOutcome.right);
      expect(done.single.sentence, 'the land at the edge of the sea');
    });

    for (final (name, text) in [('empty', ''), ('spaces', '   '), ('one word', 'land'), ('over 300', 'word ' * 70)]) {
      testWidgets('AC-13: at zero with $name text nothing is sent; a timed-out skip, read-only, no Skip', (tester) async {
        await pumpField(tester);
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(seconds: 90));
        expect(api.requests, isEmpty);
        expect(done, hasLength(1));
        expect(done.single.outcome, SentenceOutcome.skipped);
        expect(done.single.sentence, '');
        expect(done.single.timedOut, isTrue);
        expect(examLabel(done.single.outcome), WordResultLabel.repeat);
        expect(readOnly(tester), isTrue);
        expect(find.text('Skip'), findsNothing);
        expect(find.byType(ExamCountdown), findsNothing);
      });
    }

    testWidgets('AC-20: Skip before a check stops and hides the countdown', (tester) async {
      await pumpField(tester);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(find.byType(ExamCountdown), findsNothing);
      expect(done.single.outcome, SentenceOutcome.skipped);
      expect(done.single.timedOut, isFalse);
      await tester.pump(const Duration(seconds: 100));
      expect(done, hasLength(1));
    });

    testWidgets('AC-21, AC-22: after a failed check there is no countdown; Retry later resends the same text', (tester) async {
      api.replies.add(LearnApiException(LearnApiError.network, 'x'));
      await pumpField(tester);
      await send(tester, 'The land at the edge of the sea.');
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(ExamCountdown), findsNothing);
      await tester.pump(const Duration(seconds: 300));
      expect(done, isEmpty);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(api.requests.map((r) => r.sentence), ['The land at the edge of the sea.', 'The land at the edge of the sea.']);
      expect(done.single.outcome, SentenceOutcome.right);
    });

    testWidgets('leaving before zero sends nothing', (tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(TextField), 'the land at the edge of the sea');
      await tester.pump(const Duration(seconds: 70));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 60));
      expect(api.requests, isEmpty);
      expect(done, isEmpty);
    });
  });
}
