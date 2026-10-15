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
import 'package:flutter_vocabulary_app/features/learn/translate_sentences/translate_sentences_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/pronunciation_buttons.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'dart:math';

/// learn-translate-sentences: the screen (AC-01, AC-04 – AC-07, AC-09 – AC-20,
/// AC-22, AC-24, AC-25, AC-27, AC-28; §6 call counts and feedback timing).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

class _Api implements LearnApiService {
  Object? error;
  final calls = <List<LearnWord>>[];
  final checks = <LearnCheckRequest>[];
  final replies = <Object>[];
  Completer<void>? checkGate;

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: (source: 'Ми довго сиділи на ${w.translation}і.', cue: '${w.translation}і', model: 'We sat by the ${w.word} for a long time.') as T,
    };
  }

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
    expect(exerciseId, 'translate-sentences');
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
                builder: (_) => exerciseScreen('translate-sentences', sessionId, 'g'),
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

  TranslateState state() => container.read(translateSentencesProvider(openedFor, 'g')).requireValue;

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

  /// All bold text in the Text.rich with [key].
  List<String> boldIn(WidgetTester tester, String key) {
    final t = tester.widget<RichText>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(RichText)).first);
    final out = <String>[];
    t.text.visitChildren((s) {
      if (s is TextSpan && s.style?.fontWeight == FontWeight.bold && s.text != null) out.add(s.text!);
      return true;
    });
    return out;
  }

  testWidgets('AC-01, AC-09: title, counter, prompt, source with only the cue bold, field, Skip; nothing else', (tester) async {
    await pump(tester, _session(8));
    final card = state().card!;
    expect(find.widgetWithText(AppBar, 'Translate sentences'), findsOneWidget);
    expect(find.text('Word 1 of 4'), findsOneWidget);
    expect(find.text('Translate into English.'), findsOneWidget);
    expect(find.byKey(const ValueKey('translate-source')), findsOneWidget);
    expect(boldIn(tester, 'translate-source'), [card.cue]);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.textInputAction, TextInputAction.send);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.textContaining(card.word), findsNothing);
    expect(find.textContaining('Model translation'), findsNothing);
    expect(find.byType(PronunciationButtons), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(api.calls, hasLength(1));
    expect(api.checks, isEmpty);
  });

  testWidgets('AC-10, AC-11: an invalid text sends nothing', (tester) async {
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

  testWidgets('AC-12, AC-16, §6: Checking…, then Good, model translation with the word in bold, Next; record at once',
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
    expect(find.text('Model translation:'), findsOneWidget);
    expect(boldIn(tester, 'translate-model'), [card.word]);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    final r = api.checks.single;
    expect((r.word, r.translation, r.task, r.extra), (card.word, card.translation, LearnCheckTask.translate, card.source));
    expect(sink.records.single.label, WordResultLabel.known);
  });

  testWidgets('AC-13: correct English without the word is repeat with the note and the model translation', (tester) async {
    await pump(tester, _session(3));
    final card = state().card!;
    await send(tester, 'We sat on the beach for a long time.');
    expect(find.text('Use “${card.word}” in your sentence.'), findsOneWidget);
    expect(boldIn(tester, 'translate-model'), [card.word]);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-14: a fixed sentence with the word in bold, note, then the model translation', (tester) async {
    api.replies.add((usesWord: true, usesTask: false, ok: false, fixed: 'We sat by the word0.', note: 'Fix the verb.'));
    await pump(tester, _session(3));
    await send(tester, 'We sitted by the word0.');
    expect(find.text('Fix the verb.'), findsOneWidget);
    expect(find.text('Model translation:'), findsOneWidget);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-17: Skip sends no check, shows the model translation and Next; repeat', (tester) async {
    await pump(tester, _session(3));
    await tapText(tester, 'Skip');
    expect(api.checks, isEmpty);
    expect(find.text('Model translation:'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(find.text('Next'), findsOneWidget);
    expect(sink.records.single.label, WordResultLabel.repeat);
  });

  testWidgets('AC-18, AC-19: a failed check keeps the text, shows Retry and no model; Retry resends the same text',
      (tester) async {
    api.replies.add(LearnApiException(LearnApiError.network, 'x'));
    await pump(tester, _session(3));
    await send(tester, 'We sat by the shore long.');
    expect(find.text('Could not check the sentence. Check the connection and try again.'), findsOneWidget);
    expect(find.text('Model translation:'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(sink.records, isEmpty);
    await tapText(tester, 'Retry');
    await tester.pump();
    expect(api.checks.map((c) => c.sentence), ['We sat by the shore long.', 'We sat by the shore long.']);
    expect(find.text('Model translation:'), findsOneWidget);
    expect(sink.records, hasLength(1));
  });

  testWidgets('AC-20, AC-21: the day limit keeps Skip and no Retry; Skip is not checked, no word result', (tester) async {
    api.replies.add(LearnApiException(LearnApiError.dayLimit, 'x'));
    await pump(tester, _session(3));
    await send(tester, 'We sat by the shore long.');
    expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tapText(tester, 'Skip');
    expect(find.text('Model translation:'), findsOneWidget);
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

  testWidgets('AC-27, AC-28: the summary of a 6-word group in two rounds; Next round, then Done', (tester) async {
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
    expect(find.text('Repeat'), findsNothing);
    await tapText(tester, 'Next round');
    expect(find.text('Word 1 of 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
    }
    await tester.pumpAndSettle();
    expect(find.text('0 of 3 known'), findsOneWidget);
    expect(find.textContaining('· Skipped'), findsNWidgets(3));
    expect(find.text('Next round'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    await tapText(tester, 'Done');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
    expect(sink.records, hasLength(6));
  });

  testWidgets('AC-24: leaving mid-check ignores the late answer; reopening starts at word 1', (tester) async {
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

  testWidgets('AC-04, AC-05: under 3 usable words shows Not enough and Back; no call below 3 candidates', (tester) async {
    await pump(tester, _session(2));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(api.calls, isEmpty);
    await tapText(tester, 'Back');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-06, AC-07: a failed load shows the error and Retry; the day limit has Back only', (tester) async {
    api.error = LearnApiException(LearnApiError.network, 'x');
    await pump(tester, _session(3));
    expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    api.error = null;
    await tapText(tester, 'Retry');
    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 3'), findsOneWidget);
    expect(api.calls, hasLength(2));
  });

  testWidgets('AC-07: the day limit while loading: Back, no Retry, no word result', (tester) async {
    api.error = LearnApiException(LearnApiError.dayLimit, 'x');
    await pump(tester, _session(3));
    expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Back'), findsOneWidget);
    expect(sink.records, isEmpty);
  });

  testWidgets('AC-25: a History session is used; results go to it; the session is unchanged', (tester) async {
    final s = _session(3);
    final before = s.words.map((w) => w.word).toList();
    await pump(tester, s, sessionId: 'hist');
    await tapText(tester, 'Skip');
    expect(sink.records.single.sessionId, 'hist');
    expect(s.words.map((w) => w.word).toList(), before);
    expect(s.groups.single.rowIds, ['r0', 'r1', 'r2']);
  });
}
