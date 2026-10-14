import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/subtitle_progress_dialog.dart';

/// The subtitle import's progress dialog: the picked words with their context
/// lines, swipeable, translations as skeletons until they arrive, then filled
/// and scrolled on to the last card.
void main() {
  late Completer<List<VocabWord>> translation;
  late Completer<SubtitlePickedWords> picking;
  SubtitleProgressOutcome? outcome;

  const words = ['harbour', 'fog', 'tide'];
  const contexts = {'harbour': 'Into the harbour.', 'fog': 'The fog is thick.', 'tide': 'The tide turns.'};
  List<VocabWord> translated(List<String> ws) =>
      [for (final w in ws) VocabWord(word: w, translation: 'т-$w', context: contexts[w])];

  Future<void> open(WidgetTester tester, {bool read = true, String? title, String? imageUrl}) async {
    translation = Completer();
    picking = Completer();
    if (read) picking.complete((words: words, contexts: contexts));
    outcome = null;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => outcome = await showSubtitleProgressDialog(
            context,
            fileName: 'film.srt',
            title: title,
            imageUrl: imageUrl,
            picked: picking.future,
            translated: translation.future,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  int page(WidgetTester tester) =>
      tester.widget<PageView>(find.byKey(const Key('subtitle-cards'))).controller!.page!.round();

  testWidgets('at once: the file name, the first word with its context line and a skeleton translation', (tester) async {
    await open(tester);
    expect(find.text('Translating the words…'), findsOneWidget);
    expect(find.text('film.srt'), findsOneWidget);
    expect(find.text('harbour'), findsOneWidget);
    expect(find.text('“Into the harbour.”'), findsOneWidget);
    expect(find.byKey(const Key('subtitle-card-skeleton')), findsWidgets);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('while the file is still being read: skeleton cards, then the picked words', (tester) async {
    await open(tester, read: false, title: 'Harbour Lights (2024)');
    expect(find.text('Reading the subtitles…'), findsOneWidget);
    expect(find.text('Harbour Lights (2024)'), findsOneWidget);
    expect(find.text('film.srt'), findsOneWidget);
    expect(find.byKey(const Key('subtitle-card-loading')), findsWidgets);
    expect(find.text('harbour'), findsNothing);
    picking.complete((words: words, contexts: contexts));
    await tester.pump();
    expect(find.text('Translating the words…'), findsOneWidget);
    expect(find.text('harbour'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('a failure while reading closes it with the error', (tester) async {
    await open(tester, read: false);
    picking.completeError(StateError('no words'));
    translation.completeError(StateError('no words'));
    await tester.pumpAndSettle();
    expect(outcome, isA<SubtitleProgressFailed>());
  });

  testWidgets('the words can be swiped before the translations arrive', (tester) async {
    await open(tester);
    await tester.drag(find.byKey(const Key('subtitle-cards')), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(page(tester), 1);
    expect(find.text('“The fog is thick.”'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('the translations fill the cards and the pager goes on from the current card to the last, then it closes', (tester) async {
    await open(tester);
    await tester.drag(find.byKey(const Key('subtitle-cards')), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 500));
    translation.complete(translated(words));
    await tester.pump();
    await tester.pump();
    expect(find.text('Translated'), findsOneWidget);
    expect(find.text('т-fog'), findsOneWidget);
    expect(find.byKey(const Key('subtitle-card-skeleton')), findsNothing);
    await tester.pump(subtitleCardsScrollFor ~/ 2);
    expect(outcome, isNull, reason: 'still scrolling');
    await tester.pump(subtitleCardsScrollFor);
    await tester.pumpAndSettle();
    expect(outcome, isA<SubtitleProgressDone>());
    expect((outcome! as SubtitleProgressDone).words.map((w) => w.word), words);
    expect(find.text('Translated'), findsNothing);
  });

  testWidgets('fewer words back than shown: the cards are the translator\'s words', (tester) async {
    await open(tester);
    translation.complete(translated(['harbour']));
    await tester.pump();
    await tester.pump();
    expect(find.text('1 / 1'), findsOneWidget);
    await tester.pump(subtitleCardsScrollFor);
    await tester.pumpAndSettle();
    expect((outcome! as SubtitleProgressDone).words.single.word, 'harbour');
  });

  testWidgets('no word back: it closes at once with none', (tester) async {
    await open(tester);
    translation.complete([]);
    await tester.pumpAndSettle();
    expect((outcome! as SubtitleProgressDone).words, isEmpty);
  });

  testWidgets('a failure closes it at once with the error', (tester) async {
    await open(tester);
    translation.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(outcome, isA<SubtitleProgressFailed>());
    expect((outcome! as SubtitleProgressFailed).error, isA<StateError>());
  });

  testWidgets('Cancel and Back end it as a cancel; the barrier does not, and a late translation is ignored', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(5, 5)); // the barrier
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Translating the words…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(outcome, isA<SubtitleProgressCancelled>());
    translation.complete(translated(words));
    await tester.pumpAndSettle();
    expect(outcome, isA<SubtitleProgressCancelled>());

    await open(tester);
    await tester.binding.handlePopRoute(); // Android back
    await tester.pumpAndSettle();
    expect(outcome, isA<SubtitleProgressCancelled>());
  });
}
