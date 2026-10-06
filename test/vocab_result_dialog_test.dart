import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/services/quizlet_cards.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/vocab_result_dialog.dart';

/// words-from-subtitles T9: the results dialog after a photo or a subtitle
/// import (AC-18, AC-20, AC-21).
void main() {
  final words = [
    VocabWord(word: 'reluctant', translation: 'неохочий', description: 'Unwilling.', context: 'I was reluctant to leave.'),
    VocabWord(word: 'tide', translation: 'приплив', description: 'The rise and fall of the sea.'),
  ];

  /// Opens the dialog from a button and returns what it resolved with once Done is tapped.
  Future<List<VocabWord>?> Function() open(
    WidgetTester tester,
    Future<List<VocabWord>?> Function(BuildContext) show,
  ) {
    List<VocabWord>? result;
    var closed = false;
    return () async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await show(context);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return closed ? result : null;
    };
  }

  testWidgets('photo: the label is Definition, and the photo timing lines stay', (tester) async {
    await open(tester, (context) => showVocabResultDialog(
          context,
          words,
          compressDuration: const Duration(milliseconds: 250),
          requestDuration: const Duration(milliseconds: 4100),
          aiDuration: const Duration(milliseconds: 3900),
        ))();
    expect(find.text('Definition: Unwilling.'), findsOneWidget);
    expect(find.textContaining('Description'), findsNothing);
    expect(find.textContaining('Compressing photo: 0.25s'), findsOneWidget);
    expect(find.textContaining('AI processing on server: 3.90s'), findsOneWidget);
    expect(find.text('Vocabulary Found'), findsOneWidget);
  });

  testWidgets('photo: an empty list still says no words were found in this photo', (tester) async {
    await open(tester, (context) => showVocabResultDialog(
          context,
          const [],
          compressDuration: Duration.zero,
          requestDuration: Duration.zero,
        ))();
    expect(find.text('No vocabulary words found in this photo.'), findsOneWidget);
  });

  testWidgets('subtitles: one model · time · cost line and no photo timing line', (tester) async {
    await open(tester, (context) => showSubtitleResultDialog(
          context,
          words,
          infoLine: subtitleInfoLine(
            model: SubtitleModel.haiku45,
            elapsed: const Duration(milliseconds: 18450),
            inputTokens: 31250,
            outputTokens: 2140,
          ),
        ))();
    expect(find.text('Haiku 4.5 · 18.45s · ≈ \$0.042'), findsOneWidget);
    expect(find.textContaining('Compressing photo'), findsNothing);
    expect(find.textContaining('Sending & receiving'), findsNothing);
    expect(find.text('Definition: Unwilling.'), findsOneWidget);
    expect(find.text('Context: I was reluctant to leave.'), findsOneWidget);
  });

  testWidgets('subtitles: removing a word and tapping Done returns the rest in order', (tester) async {
    List<VocabWord>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showSubtitleResultDialog(context, words, infoLine: 'x'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip this word').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result!.map((w) => w.word), ['tide']);
  });

  testWidgets('subtitles: an empty list says so, and Done returns nothing to add', (tester) async {
    List<VocabWord>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showSubtitleResultDialog(context, const [], infoLine: 'Sonnet 5 · 6.12s · ≈ \$0.064'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('No new words above your level in these subtitles.'), findsOneWidget);
    expect(find.text('Sonnet 5 · 6.12s · ≈ \$0.064'), findsOneWidget);
    expect(find.textContaining('photo'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });

  Future<void> openQuizlet(WidgetTester tester, QuizletProposal p,
      void Function(List<VocabWord>?) done) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => done(await showQuizletResultDialog(context, p,
              setName: 'Biology unit 3')),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'quizlet: set name on top, Read X of Y and skipped lines when they apply (AC-02, AC-08)',
      (tester) async {
    await openQuizlet(
        tester,
        QuizletProposal(words: words, skipped: 3, found: 90, stated: 120),
        (_) {});
    expect(find.text('Biology unit 3'), findsOneWidget);
    expect(find.textContaining('Read 90 of 120 cards'), findsOneWidget);
    expect(
        find.textContaining(
            '3 cards skipped: already in the session, repeated or without text'),
        findsOneWidget);
    expect(find.text('reluctant'), findsOneWidget);
    expect(find.textContaining('photo'), findsNothing);
  });

  testWidgets(
      'quizlet: no Read line when all found, no skipped line when none skipped',
      (tester) async {
    await openQuizlet(tester,
        QuizletProposal(words: words, skipped: 0, found: 2, stated: 2), (_) {});
    expect(find.text('Biology unit 3'), findsOneWidget);
    expect(find.textContaining('Read '), findsNothing);
    expect(find.textContaining('skipped'), findsNothing);
  });

  testWidgets('quizlet: one skipped card reads in the singular',
      (tester) async {
    await openQuizlet(
        tester,
        QuizletProposal(words: words, skipped: 1, found: 3, stated: null),
        (_) {});
    expect(find.textContaining('1 card skipped'), findsOneWidget);
    expect(find.textContaining('Read '), findsNothing);
  });

  testWidgets(
      'quizlet: an empty list says No new words with the skipped line, Done returns empty (AC-04b)',
      (tester) async {
    List<VocabWord>? result;
    await openQuizlet(
        tester,
        const QuizletProposal(words: [], skipped: 5, found: 5, stated: 5),
        (r) => result = r);
    expect(find.text('No new words in this set.'), findsOneWidget);
    expect(find.textContaining('5 cards skipped'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });

  testWidgets('quizlet: removing a word and Done returns the rest',
      (tester) async {
    List<VocabWord>? result;
    await openQuizlet(
        tester,
        QuizletProposal(words: words, skipped: 0, found: 2, stated: 2),
        (r) => result = r);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result!.map((w) => w.word), ['tide']);
  });

  test('the cost shows three decimals, and a tiny cost is not shown as zero', () {
    String line(int inTok, int outTok) => subtitleInfoLine(
        model: SubtitleModel.opus55, elapsed: const Duration(seconds: 61), inputTokens: inTok, outputTokens: outTok);
    expect(line(250000, 16000), 'Opus 5.5 · 61.00s · ≈ \$1.320');
    expect(line(100, 10), 'Opus 5.5 · 61.00s · < \$0.001');
  });
}
