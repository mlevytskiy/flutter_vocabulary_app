import 'dart:convert';

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

/// The import machine-translates nothing: any call is counted.
class FakeTranslate extends GoogleTranslateService {
  int calls = 0;

  @override
  Future<WordTranslation> translateWord(String word,
      {required String to, String from = 'en'}) async {
    calls++;
    return WordTranslation(
        result: TranslationResult(text: 'т-$word'), best: 'т-$word');
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

/// import-from-quizlet T12, T19: one Quizlet import, link to kept words (sad
/// §6 F2, F3); AC-02, AC-03, AC-04, AC-04b, AC-07, AC-07b, AC-16. Each card's
/// back side goes into the field it fits; nothing is machine-translated.
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
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => runQuizletImport(
                context: context,
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

  Future<void> pumpBriefly(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Lets dialogs open and close, and the progress dialog's cards have their
  /// skeleton second and two-second scroll.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Pastes the link, taps Start, lets the page load with [cards]; returns
  /// with the progress dialog still showing its cards.
  Future<void> startImport(WidgetTester tester,
      {List<List<String>>? cards}) async {
    await tester.tap(find.text('import'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('quizlet-link')), pasted);
    await tester.tap(find.text('Start'));
    await pumpBriefly(tester);
    expect(find.text('Reading the Quizlet set…'), findsOneWidget);
    if (cards != null) {
      driver.reply = () => page(cards: cards);
      driver.finishLoading();
      await pumpBriefly(tester);
    }
  }

  const reading = 'Reading the Quizlet set…';

  testWidgets(
      'happy path: an English back is the definition, a Ukrainian back the '
      'translation, nothing machine-translated; Done adds the kept words and '
      'the set (AC-02, AC-03)', (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'a small animal'],
      ['dog', 'пес'],
      ['fox', 'a red animal'],
    ]);
    expect(find.text(reading), findsOneWidget,
        reason: 'the progress dialog shows the cards first');
    await settle(tester);
    expect(find.text(reading), findsNothing);
    expect(translate.calls, 0);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('Definition: a small animal'), findsOneWidget);
    expect(find.text('Translation: пес'), findsOneWidget);
    // An empty field has no line in the results dialog.
    expect(find.textContaining('Translation:'), findsOneWidget);
    expect(find.textContaining('Definition:'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Skip this word').at(2));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    final (words, set) = added.single;
    expect(words.map((w) => w.word), ['cat', 'dog']);
    expect(words.map((w) => w.translation ?? ''), ['', 'пес']);
    expect(words.map((w) => w.description ?? ''), ['a small animal', '']);
    expect(set.id, '123456');
    expect(set.name, 'Animals');
    expect(set.url, 'https://quizlet.com/123456/animals-flash-cards/');
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
      'Cancel while the cards show: back quietly, no results dialog (AC-07b)',
      (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'x'],
      ['dog', 'y'],
    ]);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text(reading), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(added, isEmpty);
  });

  testWidgets('Back while the cards show also cancels (AC-07b)',
      (tester) async {
    await pumpHost(tester);
    await startImport(tester, cards: [
      ['cat', 'x'],
    ]);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await settle(tester);
    expect(find.text(reading), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(added, isEmpty);
  });
}
