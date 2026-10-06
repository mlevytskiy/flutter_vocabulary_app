import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/translation_result.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';
import 'package:flutter_vocabulary_app/features/word_input/quizlet_import_flow.dart';
import 'package:flutter_vocabulary_app/features/word_input/quizlet_read_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/quizlet_link_dialog.dart';

/// Stands in for the web view: the test decides when the page loads and what
/// the reader script returns.
class FakePageDriver implements QuizletPageDriver {
  void Function()? _finished;
  void Function(String reason)? _failed;
  Object? Function() reply = () => '';

  void finishLoading() => _finished!();
  void failLoading(String reason) => _failed!(reason);

  @override
  void open(
    Uri url, {
    required void Function() onPageFinished,
    required void Function(String reason) onLoadError,
  }) {
    _finished = onPageFinished;
    _failed = onLoadError;
  }

  @override
  Future<Object?> runReader() async => reply();

  @override
  Widget buildView() => const ColoredBox(color: Colors.grey);

  @override
  void stop() {}
}

/// Translations the test answers one by one, counting how many run at once.
class FakeTranslate extends GoogleTranslateService {
  final calls = <String>[];
  final pending = <String, Completer<WordTranslation>>{};
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<WordTranslation> translateWord(String word,
      {required String to, String from = 'en'}) async {
    calls.add('$from>$to:$word');
    inFlight++;
    maxInFlight = math.max(maxInFlight, inFlight);
    final c = Completer<WordTranslation>();
    pending[word] = c;
    try {
      return await c.future;
    } finally {
      inFlight--;
    }
  }

  void answer(String word, String best) => pending.remove(word)!.complete(
      WordTranslation(result: TranslationResult(text: best), best: best));

  void fail(String word) =>
      pending.remove(word)!.completeError(TranslationException('offline'));

  /// Answers every waiting term with "т-<term>" until none is left.
  Future<void> answerAll(WidgetTester tester) async {
    while (pending.isNotEmpty) {
      for (final w in pending.keys.toList()) {
        answer(w, 'т-$w');
      }
      await tester.pump();
    }
  }
}

String page({String name = 'Animals', required List<List<String>> cards}) =>
    jsonEncode({
      'setId': '123456',
      'name': name,
      'heading': 'Terms in this set (${cards.length})',
      'embedded': null,
      'visible': cards,
      'robot': '',
    });

const pasted =
    'Check out this set: https://quizlet.com/ua/123456/animals-flash-cards/?x=1';

/// import-from-quizlet T12: one Quizlet import, link to kept words (sad §6
/// F2, F3); AC-02, AC-03, AC-04, AC-04b, AC-07, AC-07b, AC-16.
void main() {
  late FakePageDriver driver;
  late FakeTranslate translate;
  late List<(List<VocabWord>, QuizletImportedSet)> added;
  late String sessionId;
  late List<String> session;

  Future<void> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    driver = FakePageDriver();
    translate = FakeTranslate();
    added = [];
    sessionId = 'session-A';
    session = ['tide'];
    await tester.pumpWidget(ProviderScope(
      overrides: [googleTranslateServiceProvider.overrideWithValue(translate)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => runQuizletImport(
                context: context,
                ref: ref,
                currentSessionId: () => sessionId,
                sessionWords: () => session,
                addWords: (words, set) => added.add((words, set)),
                driverFactory: (_) => driver,
              ),
              child: const Text('import'),
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Pastes the link, taps Start, lets the page load with [cards].
  Future<void> startImport(WidgetTester tester,
      {List<List<String>>? cards}) async {
    await tester.tap(find.text('import'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('quizlet-link')), pasted);
    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(find.text('Reading the Quizlet set…'), findsOneWidget);
    if (cards != null) {
      driver.reply = () => page(cards: cards);
      driver.finishLoading();
      await settle(tester);
    }
  }

  const reading = 'Reading the Quizlet set…';

  testWidgets(
      'happy path: the set is read, terms translated en>uk, the results '
      'dialog shows the set; Done adds the kept words and the set (AC-02, AC-03)',
      (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'a small animal'],
      ['dog', 'a loyal animal'],
      ['fox', 'a red animal'],
    ]);
    expect(translate.calls, ['en>uk:cat', 'en>uk:dog', 'en>uk:fox']);
    expect(find.text(reading), findsOneWidget,
        reason: 'the progress dialog stays while translating');

    await translate.answerAll(tester);
    await settle(tester);
    expect(find.text(reading), findsNothing);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('Translation: т-cat'), findsOneWidget);
    expect(find.text('Definition: a small animal'), findsOneWidget);

    await tester.tap(find.byTooltip('Skip this word').at(1));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    final (words, set) = added.single;
    expect(words.map((w) => w.word), ['cat', 'fox']);
    expect(words.map((w) => w.translation), ['т-cat', 'т-fox']);
    expect(words.map((w) => w.description), ['a small animal', 'a red animal']);
    expect(set.id, '123456');
    expect(set.name, 'Animals');
    expect(set.url, 'https://quizlet.com/123456/animals-flash-cards/');
  });

  testWidgets(
      'translates at most 6 terms at a time; a failed or echoed term is left '
      'empty', (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      for (var i = 0; i < 10; i++) ['w$i', 'b$i'],
    ]);
    expect(translate.calls, hasLength(6));
    expect(translate.maxInFlight, 6);

    translate.fail('w0');
    translate.answer('w1', 'w1'); // an echo is not a translation
    await tester.pump();
    expect(translate.calls, hasLength(8));
    expect(translate.maxInFlight, 6);
    await translate.answerAll(tester);
    await settle(tester);
    expect(translate.maxInFlight, 6);

    await tester.tap(find.text('Done'));
    await settle(tester);
    final words = added.single.$1;
    expect(words.map((w) => w.word), [for (var i = 0; i < 10; i++) 'w$i']);
    expect(words[0].translation, '');
    expect(words[1].translation, '');
    expect(words[2].translation, 'т-w2');
  });

  testWidgets(
      'the session words are left out; no new words: the dialog says so and '
      'Done adds nothing (AC-04b)', (tester) async {
    await pumpHost(tester);
    session = ['Cat', 'dog'];
    await startImport(tester, cards: [
      ['cat.', 'x'],
      ['dog', 'y'],
    ]);
    expect(translate.calls, isEmpty);
    await settle(tester);
    expect(find.text('No new words in this set.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(added, isEmpty);
  });

  testWidgets('removing every word and Done adds nothing (AC-04)',
      (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'x'],
    ]);
    await translate.answerAll(tester);
    await settle(tester);
    await tester.tap(find.byTooltip('Skip this word'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(added, isEmpty);
  });

  testWidgets('closing the results dialog adds nothing (AC-04)',
      (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'x'],
    ]);
    await translate.answerAll(tester);
    await settle(tester);
    expect(find.text('Done'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // the barrier
    await settle(tester);
    expect(find.text('Done'), findsNothing);
    expect(added, isEmpty);
  });

  testWidgets(
      'the session changed before the results dialog: words dropped, no '
      'dialog (AC-16)', (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'x'],
    ]);
    sessionId = 'session-B';
    await translate.answerAll(tester);
    await settle(tester);
    expect(find.text(reading), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(added, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the session changed while the results dialog was open (AC-16)',
      (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'x'],
    ]);
    await translate.answerAll(tester);
    await settle(tester);
    sessionId = 'session-B';
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(added, isEmpty);
  });

  testWidgets(
      'a read failure closes the progress dialog with the AC-07 message and '
      'adds nothing', (tester) async {
    await pumpHost(tester);
    await startImport(tester);
    driver.failLoading('hostLookup');
    await settle(tester);
    expect(find.text(reading), findsNothing);
    expect(find.text(QuizletImportMessages.readFailed), findsOneWidget);
    expect(QuizletImportMessages.readFailed,
        "The cards of this set couldn't be read. Try again.");
    expect(translate.calls, isEmpty);
    expect(added, isEmpty);
  });

  testWidgets('Cancel while reading: back quietly, nothing added (AC-07b)',
      (tester) async {
    await pumpHost(tester);
    await startImport(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text(reading), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(added, isEmpty);
  });

  testWidgets(
      'Cancel while translating: back quietly, no further term is '
      'translated, no results dialog (AC-07b)', (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      for (var i = 0; i < 10; i++) ['w$i', 'b$i'],
    ]);
    expect(translate.calls, hasLength(6));
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text(reading), findsNothing);

    await translate.answerAll(tester);
    await settle(tester);
    expect(translate.calls, hasLength(6), reason: 'translation stopped');
    expect(find.text('Done'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(added, isEmpty);
  });

  testWidgets('Back while translating also cancels (AC-07b)', (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'x'],
    ]);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await settle(tester);
    expect(find.text(reading), findsNothing);
    await translate.answerAll(tester);
    await settle(tester);
    expect(find.text('Done'), findsNothing);
    expect(added, isEmpty);
  });
}
