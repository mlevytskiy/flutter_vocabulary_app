import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
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

  test('the cost shows three decimals, and a tiny cost is not shown as zero', () {
    String line(int inTok, int outTok) => subtitleInfoLine(
        model: SubtitleModel.opus55, elapsed: const Duration(seconds: 61), inputTokens: inTok, outputTokens: outTok);
    expect(line(250000, 16000), 'Opus 5.5 · 61.00s · ≈ \$1.320');
    expect(line(100, 10), 'Opus 5.5 · 61.00s · < \$0.001');
  });
}
