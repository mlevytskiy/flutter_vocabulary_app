import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_item.dart';

/// definition-mode T11: translation mode must look exactly as before
/// (spec AC-02). The expected rectangles below were recorded from the
/// pre-feature `WordRowItem` (commit bcef61f) on a 400-px-wide card.
void main() {
  Future<void> pumpRow(WidgetTester tester, Widget row) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, child: row),
        ),
      ),
    ));
    await tester.pump();
  }

  WordRowItem translationRow({
    required TextEditingController word,
    required TextEditingController translation,
    bool isDragMode = false,
    WordDetailMode mode = WordDetailMode.translation,
    TextEditingController? definition,
    bool shouldShowWordIcon = false,
    bool shouldShowDefinitionIcon = false,
    VoidCallback? onFillDefinition,
  }) =>
      WordRowItem(
        index: 0,
        detailMode: mode,
        definitionController: definition ?? TextEditingController(),
        definitionFocusNode: FocusNode(),
        shouldShowDefinitionIcon: shouldShowDefinitionIcon,
        onFillDefinition: onFillDefinition ?? () {},
        isDragMode: isDragMode,
        wordController: word,
        translationController: translation,
        wordFocusNode: FocusNode(),
        translationFocusNode: FocusNode(),
        isLoadingWordTranslation: false,
        isLoadingTranslation: false,
        shouldShowWordIcon: shouldShowWordIcon,
        shouldShowTranslationIcon: true,
        shouldShowPronunciation: true,
        popupController: CustomPopupMenuController(),
        onLoadTranslations: () async => null,
        onOpenTranslationOptions: () {},
        onCloseTranslationOptions: () {},
        onRemove: () {},
        onFillWordWithAI: () {},
        onFillWithAI: () {},
        onSelectTranslation: (_) {},
        onSpeak: (_) {},
      );

  Finder fieldLabelled(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label);

  Rect rectOfField(WidgetTester tester, String label) =>
      tester.getRect(fieldLabelled(label));

  String describe(WidgetTester tester) {
    final card = tester.getRect(find.byType(WordRowItem));
    final word = rectOfField(tester, 'Word');
    final translation = rectOfField(tester, 'Translation');
    final dots = tester.getRect(find.byType(TranslationDotsButton));
    final flag = tester.getRect(find.byIcon(Icons.close));
    final bolt = tester.getRect(find.byIcon(Icons.electric_bolt));
    String r(Rect x) =>
        '${x.left.toStringAsFixed(1)},${x.top.toStringAsFixed(1)},'
        '${x.width.toStringAsFixed(1)}x${x.height.toStringAsFixed(1)}';
    return 'card=${r(card)} word=${r(word)} translation=${r(translation)} '
        'dots=${r(dots)} close=${r(flag)} bolt=${r(bolt)}';
  }

  testWidgets('translation layout is unchanged — short texts', (tester) async {
    await pumpRow(
        tester,
        translationRow(
          word: TextEditingController(text: 'claim'),
          translation: TextEditingController(text: 'заява'),
        ));
    // ignore: avoid_print
    print('LAYOUT short ${describe(tester)}');
    expect(describe(tester), kShortLayout);
  });

  testWidgets('translation layout is unchanged — long texts, drag mode',
      (tester) async {
    await pumpRow(
        tester,
        translationRow(
          word: TextEditingController(text: 'circumstances beyond control'),
          translation: TextEditingController(
              text: 'обставини, що не залежать від нас і нашої волі'),
          isDragMode: true,
        ));
    // ignore: avoid_print
    print('LAYOUT long ${describe(tester)}');
    expect(describe(tester), kLongLayout);
  });

  testWidgets('definition mode: word on top, definition under it, full width',
      (tester) async {
    await pumpRow(
        tester,
        translationRow(
          word: TextEditingController(text: 'tenacious'),
          translation: TextEditingController(text: 'наполегливий'),
          definition: TextEditingController(text: 'persistent'),
          mode: WordDetailMode.definition,
          shouldShowWordIcon: true,
        ));

    expect(fieldLabelled('Translation'), findsNothing);
    expect(find.byType(TranslationDotsButton), findsNothing);
    final word = rectOfField(tester, 'Word');
    final definition = rectOfField(tester, 'Definition');
    expect(definition.top, greaterThan(word.bottom));
    expect(definition.left, word.left);
    expect(definition.width, word.width);
    // Full width: wider than the translation-mode half-width field (171 px).
    expect(word.width, greaterThan(300));
    // No Word lightning: there is no translation to translate from.
    expect(find.byTooltip('AI Translate (to Word)'), findsNothing);
  });

  testWidgets('both mode: today\'s row with the definition underneath',
      (tester) async {
    await pumpRow(
        tester,
        translationRow(
          word: TextEditingController(text: 'claim'),
          translation: TextEditingController(text: 'заява'),
          definition: TextEditingController(text: 'to ask for as a right'),
          mode: WordDetailMode.both,
        ));

    final word = rectOfField(tester, 'Word');
    final translation = rectOfField(tester, 'Translation');
    final definition = rectOfField(tester, 'Definition');
    // The top line is exactly the translation-mode row.
    expect(word, const Rect.fromLTWH(8, 35, 171, 56));
    expect(translation.left, 195);
    expect(find.byType(TranslationDotsButton), findsOneWidget);
    expect(definition.top, greaterThan(translation.bottom));
    expect(definition.left, word.left);
    expect(definition.right, translation.right);
  });

  testWidgets('translation mode has no definition field', (tester) async {
    await pumpRow(
        tester,
        translationRow(
          word: TextEditingController(text: 'claim'),
          translation: TextEditingController(text: 'заява'),
          definition: TextEditingController(text: 'hidden but kept'),
        ));
    expect(fieldLabelled('Definition'), findsNothing);
  });

  testWidgets('the definition lightning is tappable in both layouts',
      (tester) async {
    for (final mode in [WordDetailMode.definition, WordDetailMode.both]) {
      var taps = 0;
      await pumpRow(
          tester,
          translationRow(
            word: TextEditingController(text: 'claim'),
            translation: TextEditingController(text: 'заява'),
            mode: mode,
            shouldShowDefinitionIcon: true,
            onFillDefinition: () => taps++,
          ));
      await tester.tap(find.byTooltip('Look up definition'));
      expect(taps, 1, reason: '$mode');
    }
  });

  testWidgets('the Definition hint is lighter than typed text', (tester) async {
    await pumpRow(
        tester,
        translationRow(
          word: TextEditingController(text: 'claim'),
          translation: TextEditingController(),
          mode: WordDetailMode.definition,
        ));
    final field = tester.widget<TextField>(fieldLabelled('Definition'));
    final hint = field.decoration!.hintStyle!.color!;
    final text = field.style!.color ??
        Theme.of(tester.element(fieldLabelled('Definition')))
            .colorScheme
            .onSurface;
    expect(hint.a, lessThan(0.6));
    expect(hint.a, lessThan(text.a));
  });

  testWidgets('the Definition field starts at 1 line and grows to 4',
      (tester) async {
    for (final mode in [WordDetailMode.definition, WordDetailMode.both]) {
      await pumpRow(
          tester,
          translationRow(
            word: TextEditingController(text: 'claim'),
            translation: TextEditingController(),
            mode: mode,
          ));
      final field = tester.widget<TextField>(fieldLabelled('Definition'));
      expect(field.minLines, 1, reason: '$mode');
      expect(field.maxLines, 4, reason: '$mode');
    }
  });
}

// Recorded from the pre-feature widget; see the header comment.
const kShortLayout = 'card=0.0,0.0,400.0x800.0 word=8.0,35.0,171.0x56.0 '
    'translation=195.0,35.0,171.0x80.0 dots=370.0,63.0,22.0x24.0 '
    'close=370.0,8.0,18.0x18.0 bolt=326.0,47.0,28.0x28.0';
const kLongLayout = 'card=0.0,0.0,400.0x800.0 word=48.0,35.0,151.0x200.0 '
    'translation=215.0,35.0,151.0x200.0 dots=370.0,123.0,22.0x24.0 '
    'close=370.0,8.0,18.0x18.0 bolt=326.0,47.0,28.0x28.0';
