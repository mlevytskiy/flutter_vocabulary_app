import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_result.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_result_line.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_verdict.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/sentence_check.dart';

/// learn-sentence-patterns S-47 – S-49: the kit's sentence check field, its
/// outcomes and labels, and the bold word in the fixed sentence (AC-06 – AC-12,
/// AC-14 – AC-18, AC-30, AC-31).
class _Api implements LearnApiService {
  final requests = <LearnCheckRequest>[];
  final replies = <Object>[];
  Completer<void>? gate;

  @override
  Future<CheckReply> check(LearnCheckRequest request) async {
    requests.add(request);
    if (gate != null) await gate!.future;
    final next = replies.isEmpty ? _good : replies.removeAt(0);
    if (next is CheckReply) return next;
    throw next;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('unexpected call: ${i.memberName}');
}

const CheckReply _good = (usesWord: true, usesTask: true, ok: true, fixed: '', note: '');
const CheckReply _wrong =
    (usesWord: true, usesTask: true, ok: false, fixed: 'The main conflict was that nobody had time.', note: 'Use "was" and "had".');

/// The bold parts of the one text widget that reads [plain].
List<String?> boldTexts(WidgetTester tester, String plain) {
  final span = tester.widget<Text>(find.text(plain)).textSpan;
  final bold = <String?>[];
  span?.visitChildren((s) {
    if (s is TextSpan && s.style?.fontWeight == FontWeight.bold) bold.add(s.text);
    return true;
  });
  return bold;
}

void main() {
  late _Api api;
  late List<SentenceResult> done;

  Future<void> pumpField(WidgetTester tester, SentenceCheckMode mode, {Widget Function(Widget field)? wrap}) async {
    final field = SentenceCheckField(
      key: const ValueKey('check-r0'),
      word: 'conflict',
      translation: 'конфлікт',
      task: LearnCheckTask.pattern,
      extra: 'The main + [noun] + was that + [sentence]',
      mode: mode,
      onDone: done.add,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [learnApiServiceProvider.overrideWithValue(api)],
      child: MaterialApp(home: Scaffold(body: wrap == null ? field : wrap(field))),
    ));
    await tester.pump();
  }

  TextField textField(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField));

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
  }

  setUp(() {
    api = _Api();
    done = [];
  });

  group('S-48 outcomes and labels', () {
    test('AC-31: practice shows Right / Fixed / Skipped / Skipped', () {
      expect([for (final o in SentenceOutcome.values) practiceLabel(o)], ['Right', 'Fixed', 'Skipped', 'Skipped']);
    });

    test('AC-31: an exam records known / repeat / repeat / no result', () {
      expect([for (final o in SentenceOutcome.values) examLabel(o)],
          [WordResultLabel.known, WordResultLabel.repeat, WordResultLabel.repeat, null]);
      expect([for (final o in SentenceOutcome.values) examSummaryText(o)], ['Known', 'Repeat', 'Repeat', 'Not checked']);
    });

    test('the outcome of a verdict', () {
      expect(SentenceResult.checked('a b', const CheckRight()).outcome, SentenceOutcome.right);
      final fixed = SentenceResult.checked('a b', const CheckFixed(fixed: 'A b.', note: 'n'));
      expect(fixed.outcome, SentenceOutcome.fixed);
      expect(fixed.sentence, 'a b');
    });
  });

  group('S-49 CheckResultLine with the word', () {
    testWidgets('AC-08: the fixed sentence shows the word in bold; without a word it stays plain', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CheckResultLine.verdict(CheckFixed(fixed: 'The main conflict was clear.', note: 'Note.'), word: 'conflict'),
        ),
      ));
      expect(boldTexts(tester, 'The main conflict was clear.'), ['conflict']);
      expect(find.text('Note.'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CheckResultLine.verdict(CheckFixed(fixed: 'The main conflict was clear.', note: 'Note.'))),
      ));
      expect(find.text('The main conflict was clear.'), findsOneWidget);
    });
  });

  group('S-47 SentenceCheckField, practice', () {
    testWidgets('AC-05: keyboard field with no autocorrect or suggestions, Send action, Skip', (tester) async {
      await pumpField(tester, SentenceCheckMode.practice);
      final field = textField(tester);
      expect(field.autofocus, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textInputAction, TextInputAction.send);
      expect(field.maxLines, isNull);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('AC-06: empty, spaces, one word or too long is not sent; the text and the keyboard stay', (tester) async {
      await pumpField(tester, SentenceCheckMode.practice);
      for (final text in ['', '   ', 'conflict']) {
        await send(tester, text);
        expect(find.text('Write a full sentence'), findsOneWidget, reason: text);
        expect(textField(tester).controller!.text, text);
        expect(textField(tester).focusNode!.hasFocus, isTrue);
      }
      await send(tester, 'I ${'x' * 199}');
      expect(find.text('Keep it under two hundred characters'), findsOneWidget);
      expect(find.text('Write a full sentence'), findsNothing);
      expect(api.requests, isEmpty);
      expect(done, isEmpty);
    });

    testWidgets('AC-07: spinner at once, Send and Skip inert, then Good; read-only, no Skip, onDone once', (tester) async {
      api.gate = Completer();
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, '  The main conflict was that nobody had time. ');
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(api.requests, hasLength(1));
      expect(done, isEmpty);
      final r = api.requests.single;
      expect((r.word, r.translation, r.sentence, r.task, r.extra), (
        'conflict',
        'конфлікт',
        'The main conflict was that nobody had time.',
        LearnCheckTask.pattern,
        'The main + [noun] + was that + [sentence]',
      ));

      api.gate!.complete();
      await tester.pump();
      expect(find.text('Checking…'), findsNothing);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(textField(tester).readOnly, isTrue);
      expect(done.single.outcome, SentenceOutcome.right);
      expect(done.single.sentence, 'The main conflict was that nobody had time.');
      expect(done.single.verdict, isA<CheckRight>());
    });

    testWidgets('AC-08, AC-11: a fixed sentence with the word in bold and the note; no second check', (tester) async {
      api.replies.add(_wrong);
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict were that nobody have time.');
      await tester.pump();
      expect(boldTexts(tester, 'The main conflict was that nobody had time.'), ['conflict']);
      expect(find.text('Use "was" and "had".'), findsOneWidget);
      expect(done.single.outcome, SentenceOutcome.fixed);
      expect(textField(tester).readOnly, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(api.requests, hasLength(1));
      expect(done, hasLength(1));
    });

    testWidgets('AC-10: the AI says ok but the word is missing: fixed with the app note', (tester) async {
      api.replies.add((usesWord: false, usesTask: true, ok: true, fixed: '', note: ''));
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main dispute was that nobody had time.');
      await tester.pump();
      expect(find.text('Use “conflict” in your sentence.'), findsOneWidget);
      expect(done.single.outcome, SentenceOutcome.fixed);
    });

    testWidgets('AC-10: the AI says wrong but its fix equals the sentence: Good', (tester) async {
      api.replies.add((usesWord: true, usesTask: true, ok: false, fixed: 'the main conflict was that nobody had time', note: 'x'));
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict was that nobody had time.');
      await tester.pump();
      expect(find.text('Good'), findsOneWidget);
      expect(done.single.outcome, SentenceOutcome.right);
    });

    testWidgets('AC-09: an inflected form counts as the word', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [learnApiServiceProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: SentenceCheckField(
              word: 'walk',
              translation: 'ходити',
              task: LearnCheckTask.pattern,
              extra: 'In the end, + we + [verb in Past Simple]',
              mode: SentenceCheckMode.practice,
              onDone: done.add,
            ),
          ),
        ),
      ));
      await send(tester, 'In the end, we walked home.');
      await tester.pump();
      expect(done.single.outcome, SentenceOutcome.right);
      expect(api.requests.single.extra, 'In the end, + we + [verb in Past Simple]');
    });

    testWidgets('AC-12: Skip before sending ends as skipped with no call', (tester) async {
      await pumpField(tester, SentenceCheckMode.practice);
      await tester.enterText(find.byType(TextField), 'Some text');
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(api.requests, isEmpty);
      expect(done.single.outcome, SentenceOutcome.skipped);
      expect(done.single.sentence, '');
      expect(done.single.verdict, isNull);
      expect(find.text('Skip'), findsNothing);
      expect(textField(tester).readOnly, isTrue);
    });

    testWidgets('AC-14, AC-15: a failed check keeps the text; edited text is pre-checked and sent on Retry', (tester) async {
      api.replies.add(Exception('offline'));
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict was that nobody had time.');
      await tester.pump();
      expect(find.text(CheckResultLine.checkFailedMessage), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Good'), findsNothing);
      expect(textField(tester).controller!.text, 'The main conflict was that nobody had time.');
      expect(textField(tester).readOnly, isFalse);
      expect(done, isEmpty);

      await tester.enterText(find.byType(TextField), 'conflict');
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Write a full sentence'), findsOneWidget);
      expect(api.requests, hasLength(1));

      await tester.enterText(find.byType(TextField), 'The main conflict was that we were late.');
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(api.requests.last.sentence, 'The main conflict was that we were late.');
      expect(find.text('Good'), findsOneWidget);
      expect(find.text(CheckResultLine.checkFailedMessage), findsNothing);
      expect(done.single.outcome, SentenceOutcome.right);
    });

    testWidgets('AC-15: Send after a failure also retries', (tester) async {
      api.replies.add(Exception('offline'));
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict was that nobody had time.');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      await tester.pump();
      expect(api.requests, hasLength(2));
      expect(done.single.outcome, SentenceOutcome.right);
    });

    testWidgets('AC-16: Skip after a failed check ends as not checked with the sent text', (tester) async {
      api.replies.add(Exception('offline'));
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict was that nobody had time.');
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(done.single.outcome, SentenceOutcome.notChecked);
      expect(done.single.sentence, 'The main conflict was that nobody had time.');
      expect(practiceLabel(done.single.outcome), 'Skipped');
      expect(find.text(CheckResultLine.checkFailedMessage), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(api.requests, hasLength(1));
    });

    testWidgets('AC-17: the day limit has no Retry and Skip still ends the word; too frequent has Retry', (tester) async {
      api.replies.add(LearnApiException(LearnApiError.dayLimit, 'day'));
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict was that nobody had time.');
      await tester.pump();
      expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(textField(tester).controller!.text, 'The main conflict was that nobody had time.');
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(practiceLabel(done.single.outcome), 'Skipped');

      done.clear();
      api.replies.add(LearnApiException(LearnApiError.rateLimited, 'fast'));
      await tester.pumpWidget(const SizedBox());
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict was that nobody had time.');
      await tester.pump();
      expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('AC-18: an answer after the field is gone changes nothing and throws nothing', (tester) async {
      api.gate = Completer();
      await pumpField(tester, SentenceCheckMode.practice);
      await send(tester, 'The main conflict was that nobody had time.');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      api.gate!.complete();
      await tester.pump();
      expect(done, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('S-47 SentenceCheckField, exam', () {
    testWidgets('AC-30: after a failure the sent text stays locked and Retry resends exactly it', (tester) async {
      api.replies.add(Exception('offline'));
      await pumpField(tester, SentenceCheckMode.exam);
      await send(tester, ' The main conflict was that nobody had time. ');
      await tester.pump();
      expect(find.text(CheckResultLine.checkFailedMessage), findsOneWidget);
      expect(textField(tester).readOnly, isTrue);
      expect(find.text('Skip'), findsOneWidget);
      textField(tester).controller!.text = 'Something else entirely here.';
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(api.requests.map((r) => r.sentence), ['The main conflict was that nobody had time.', 'The main conflict was that nobody had time.']);
      expect(find.text('Good'), findsOneWidget);
      expect(done.single.outcome, SentenceOutcome.right);
    });

    testWidgets('AC-30: pre-check, Skip and the result line as in practice', (tester) async {
      await pumpField(tester, SentenceCheckMode.exam);
      await send(tester, 'conflict');
      expect(find.text('Write a full sentence'), findsOneWidget);
      expect(textField(tester).readOnly, isFalse);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(done.single.outcome, SentenceOutcome.skipped);
      expect(examLabel(done.single.outcome), WordResultLabel.repeat);
      expect(api.requests, isEmpty);
    });

    testWidgets('AC-31: the same sentence and reply get the same verdict in both modes', (tester) async {
      final outcomes = <SentenceCheckMode, SentenceOutcome>{};
      for (final mode in SentenceCheckMode.values) {
        done.clear();
        api.replies.add(_wrong);
        await tester.pumpWidget(const SizedBox());
        await pumpField(tester, mode);
        await send(tester, 'The main conflict were that nobody have time.');
        await tester.pump();
        outcomes[mode] = done.single.outcome;
        expect(find.text('The main conflict was that nobody had time.'), findsOneWidget);
      }
      expect(outcomes.values.toSet(), {SentenceOutcome.fixed});
    });
  });
}
