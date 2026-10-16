import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/pronunciation_service.dart';
import 'package:flutter_vocabulary_app/features/learn/exercise_screens.dart';
import 'package:flutter_vocabulary_app/features/learn/kit/check_result_line.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/pronunciation_buttons.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// learn-sentence-patterns: the screen (AC-01, AC-02, AC-04 – AC-08, AC-12 –
/// AC-14, AC-16, AC-18, AC-19, AC-22 – AC-28; §6 call counts).
class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;

  @override
  Future<WordCollection> build() async => collection;
}

/// Counts every call; a pattern card "The main <word> was that we were late."
/// for every word; checks answer "Good" unless told otherwise.
class _Api implements LearnApiService {
  Object? error;
  final calls = <List<LearnWord>>[];
  final checks = <LearnCheckRequest>[];
  final replies = <Object>[];
  Completer<void>? checkGate;
  String Function(String word) sentenceOf = (w) => 'The main $w was that we were late.';

  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async {
    calls.add(words);
    if (error != null) throw error!;
    return {
      for (final w in words)
        w.rowId: (sentence: sentenceOf(w.word), pattern: 'The main + [noun] + was that + [sentence]', usage: 'explain a reason') as T,
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

class _FakeSpeech implements PronunciationService {
  final spoken = <(String, Accent)>[];
  int stops = 0;
  Object? failWith;

  @override
  Future<void> speak(String word, {required Accent accent}) async {
    if (failWith != null) throw failWith!;
    spoken.add((word, accent));
  }

  @override
  Future<void> stop() async => stops++;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

WordCollection _collection(int count, {List<String>? names, List<String>? translations}) {
  final words = [
    for (var i = 0; i < count; i++)
      WordPair(
        word: names != null ? names[i] : 'word$i',
        translation: translations != null ? translations[i] : 'слово$i',
        rowId: 'r$i',
      ),
  ];
  return WordCollection.create()
    ..words = words
    ..groups = [
      WordGroup()
        ..id = 'g'
        ..name = 'G'
        ..rowIds = [for (final w in words) w.rowId],
    ];
}

const _good = 'The main word0 was that nobody had time.';

void main() {
  late _Api api;
  late _FakeSpeech speech;

  Future<ProviderContainer> pump(WidgetTester tester, WordCollection collection, {String? collectionId}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      learnApiServiceProvider.overrideWithValue(api),
      pronunciationServiceProvider.overrideWithValue(speech),
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
                builder: (_) => exerciseScreen('sentence-patterns', collectionId, 'g'),
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

  Future<void> writeAndSend(WidgetTester tester, String text) async {
    await tapText(tester, 'My turn');
    await send(tester, text);
  }

  setUp(() {
    api = _Api();
    speech = _FakeSpeech();
  });

  testWidgets('AC-01: title, counter, card, pattern, usage, translation, speakers and My turn; no field', (tester) async {
    await pump(tester, _collection(5));
    expect(find.text('Sentence patterns'), findsOneWidget);
    expect(find.text('Word 1 of 5'), findsOneWidget);
    expect(find.text('The main word0 was that we were late.'), findsOneWidget);
    expect(find.text('Pattern: The main + [noun] + was that + [sentence]'), findsOneWidget);
    expect(find.text('Use it to: explain a reason'), findsOneWidget);
    expect(find.text('слово0'), findsOneWidget);
    expect(find.byType(PronunciationButtons), findsOneWidget);
    expect(find.text('My turn'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(api.checks, isEmpty);
  });

  testWidgets('AC-02: only the word (any form) is bold; markup characters stay plain', (tester) async {
    api.sentenceOf = (w) => w == 'walk' ? 'In the end, we **walked** home.' : 'The main $w was that two teams wanted different things.';
    await pump(tester, _collection(3, names: ['conflict', 'walk', 'tide']));
    List<String?> bold(String plain) {
      final bold = <String?>[];
      tester.widget<Text>(find.text(plain)).textSpan!.visitChildren((s) {
        if (s is TextSpan && s.style?.fontWeight == FontWeight.bold) bold.add(s.text);
        return true;
      });
      return bold;
    }

    expect(bold('The main conflict was that two teams wanted different things.'), ['conflict']);
    await tapText(tester, 'My turn');
    await tapText(tester, 'Skip');
    await tapText(tester, 'Next');
    expect(bold('In the end, we **walked** home.'), ['walked']);
  });

  testWidgets('AC-04: the speakers read the sentence; Next and leaving stop it; an error shows briefly', (tester) async {
    await pump(tester, _collection(3));
    await tester.tap(find.byTooltip('US pronunciation'));
    await tester.pump();
    await tester.tap(find.byTooltip('UK pronunciation'));
    await tester.pump();
    expect(speech.spoken, [
      ('The main word0 was that we were late.', Accent.us),
      ('The main word0 was that we were late.', Accent.uk),
    ]);
    final before = speech.stops;
    await tapText(tester, 'My turn');
    await tapText(tester, 'Skip');
    await tapText(tester, 'Next');
    expect(speech.stops, greaterThan(before));

    speech.failWith = PronunciationException('Could not play pronunciation: no voice');
    await tester.tap(find.byTooltip('US pronunciation'));
    await tester.pump();
    expect(find.text('Could not play pronunciation: no voice'), findsOneWidget);
    expect(find.text('Word 2 of 3'), findsOneWidget);

    final beforeLeave = speech.stops;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(speech.stops, greaterThan(beforeLeave));
  });

  testWidgets('AC-05: My turn shows the prompt and the field under the card; My turn disappears', (tester) async {
    await pump(tester, _collection(3, names: ['conflict', 'tide', 'bay']));
    await tapText(tester, 'My turn');
    expect(find.text('Write your own sentence with “conflict” and this pattern.'), findsOneWidget);
    expect(find.text('The main conflict was that we were late.'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect((field.autofocus, field.autocorrect, field.enableSuggestions, field.textInputAction),
        (true, false, false, TextInputAction.send));
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('My turn'), findsNothing);
  });

  testWidgets('AC-06, §6: an invalid text sends nothing', (tester) async {
    await pump(tester, _collection(3));
    await writeAndSend(tester, 'word0');
    expect(find.text('Write a full sentence'), findsOneWidget);
    expect(api.checks, isEmpty);
  });

  testWidgets('AC-07, §6: the spinner at once, then Good and Next; one check with the pattern; Right in the summary', (tester) async {
    api.checkGate = Completer();
    await pump(tester, _collection(3));
    await tapText(tester, 'My turn');
    await tester.enterText(find.byType(TextField), _good);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text('Checking…'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    api.checkGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
    final r = api.checks.single;
    expect((r.word, r.translation, r.sentence, r.task, r.extra),
        ('word0', 'слово0', _good, LearnCheckTask.pattern, 'The main + [noun] + was that + [sentence]'));
    await tapText(tester, 'Next');
    for (var i = 1; i < 3; i++) {
      await tapText(tester, 'My turn');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
    }
    await tester.pumpAndSettle();
    expect(find.text('Right'), findsOneWidget);
    expect(api.checks, hasLength(1));
    expect(api.calls, hasLength(1));
  });

  testWidgets('AC-08: a fixed sentence with the word in bold and the note; Fixed in the summary', (tester) async {
    api.replies.add((usesWord: true, usesTask: false, ok: false, fixed: 'The main word0 was that we had a fight.', note: 'Use the pattern.'));
    await pump(tester, _collection(3));
    await writeAndSend(tester, 'We had a word0 yesterday.');
    expect(find.text('The main word0 was that we had a fight.'), findsOneWidget);
    expect(find.text('Use the pattern.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tapText(tester, 'Next');
    for (var i = 1; i < 3; i++) {
      await tapText(tester, 'My turn');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Next');
    }
    await tester.pumpAndSettle();
    expect(find.text('Fixed'), findsOneWidget);
  });

  testWidgets('AC-12, AC-13: Skip shows Skipped and Next; Next shows the next card with My turn', (tester) async {
    await pump(tester, _collection(5));
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'My turn');
      await tester.enterText(find.byType(TextField), 'some text here');
      await tapText(tester, 'Skip');
      expect(find.text('Skipped'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tapText(tester, 'Next');
    }
    expect(find.text('Word 4 of 5'), findsOneWidget);
    expect(find.text('My turn'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(api.checks, isEmpty);
  });

  testWidgets('AC-14, AC-16, AC-26: a failure keeps the text; Skip then ends as Skipped; the summary in group order', (tester) async {
    await pump(tester, _collection(5));
    // Good.
    await writeAndSend(tester, _good);
    await tapText(tester, 'Next');
    // Fixed.
    api.replies.add((usesWord: true, usesTask: true, ok: false, fixed: 'The main word1 was that it rained.', note: 'n'));
    await writeAndSend(tester, 'The main word1 were that it rain.');
    await tapText(tester, 'Next');
    // Skipped before sending.
    await tapText(tester, 'My turn');
    await tapText(tester, 'Skip');
    await tapText(tester, 'Next');
    // Skipped after a failed check.
    api.replies.add(Exception('offline'));
    await writeAndSend(tester, 'The main word3 was that we left.');
    expect(find.text(CheckResultLine.checkFailedMessage), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'The main word3 was that we left.');
    await tapText(tester, 'Skip');
    expect(find.text('Skipped'), findsOneWidget);
    await tapText(tester, 'Next');
    // Good after one Retry.
    api.replies.add(Exception('offline'));
    await writeAndSend(tester, 'The main word4 was that we left.');
    await tapText(tester, 'Retry');
    await tester.pump();
    expect(find.text('Good'), findsOneWidget);
    await tapText(tester, 'Next');
    await tester.pumpAndSettle();

    final results = [for (var i = 0; i < 5; i++) tester.widget<ListTile>(find.byKey(ValueKey('outcome-r$i'))).trailing as Text];
    expect(results.map((t) => t.data), ['Right', 'Fixed', 'Skipped', 'Skipped', 'Right']);
    expect(find.textContaining('Score'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(api.checks, hasLength(5));
    await tapText(tester, 'Done');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-18: leaving with a check in flight: the late answer changes nothing; reopening starts over', (tester) async {
    api.checkGate = Completer();
    await pump(tester, _collection(3));
    await tapText(tester, 'My turn');
    await tester.enterText(find.byType(TextField), _good);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    api.checkGate!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    api.checkGate = null;
    await tester.tap(find.text('learn page'));
    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 3'), findsOneWidget);
    expect(find.text('My turn'), findsOneWidget);
  });

  testWidgets('AC-19: one data call for exactly the words with translations; no check on open', (tester) async {
    await pump(tester, _collection(6));
    expect(api.calls.single, [for (var i = 0; i < 6; i++) (rowId: 'r$i', word: 'word$i', translation: 'слово$i')]);
    expect(api.checks, isEmpty);
  });

  testWidgets('AC-22: under 3 words with a translation: Not enough and Back, no call', (tester) async {
    await pump(tester, _collection(4, translations: ['a', 'b', '', ' ']));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('AC-23: under 3 usable patterns: Not enough; Back returns to the learn page', (tester) async {
    api.sentenceOf = (w) => w == 'word0' ? 'The main $w was that we were late.' : 'No word here.';
    await pump(tester, _collection(4));
    expect(find.text('Not enough words for this exercise'), findsOneWidget);
    await tapText(tester, 'Back');
    await tester.pumpAndSettle();
    expect(find.text('learn page'), findsOneWidget);
  });

  testWidgets('AC-24: a failed load shows the error and Retry; Retry loads word 1', (tester) async {
    api.error = LearnApiException(LearnApiError.network, 'offline');
    await pump(tester, _collection(3));
    expect(find.text('Could not load the exercise. Check the connection and try again.'), findsOneWidget);
    api.error = null;
    await tapText(tester, 'Retry');
    await tester.pumpAndSettle();
    expect(find.text('Word 1 of 3'), findsOneWidget);
    expect(api.calls, hasLength(2));
  });

  testWidgets('AC-25: the day limit shows with Back; too frequent with Retry', (tester) async {
    api.error = LearnApiException(LearnApiError.dayLimit, 'day');
    await pump(tester, _collection(3));
    expect(find.text("Today's exercise limit is reached. Try again tomorrow."), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('AC-25: too many requests shows Retry', (tester) async {
    api.error = LearnApiException(LearnApiError.rateLimited, 'fast');
    await pump(tester, _collection(3));
    expect(find.text('Too many requests. Wait a moment and try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('AC-27, AC-28: a History session is used and stays unchanged', (tester) async {
    final history = _collection(3, names: ['alpha', 'beta', 'gamma']);
    String snapshot() => [
          for (final w in history.words) (w.word, w.translation, w.definition, w.rowId),
          for (final g in history.groups) (g.id, g.rowIds.join(',')),
          history.lastLocalModifiedAt,
        ].toString();
    final before = snapshot();
    await pump(tester, history, collectionId: 'hist');
    expect(api.calls.single.map((w) => w.word), ['alpha', 'beta', 'gamma']);
    for (var i = 0; i < 3; i++) {
      await writeAndSend(tester, 'The main ${['alpha', 'beta', 'gamma'][i]} was that we won.');
      await tapText(tester, 'Next');
    }
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    expect(snapshot(), before);
  });
}
