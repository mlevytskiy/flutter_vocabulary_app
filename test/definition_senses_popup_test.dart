import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/definition_dots_button.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_item.dart';

/// definition-mode T13: the definition dots popup lists the dictionary's
/// senses and a tap picks one (spec AC-08).
void main() {
  late int lookups;
  late List<String> selected;

  Future<void> pumpRow(WidgetTester tester,
      {required WordDetailMode mode, List<String>? senses}) async {
    lookups = 0;
    selected = [];
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final popup = CustomPopupMenuController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: WordRowItem(
              index: 0,
              detailMode: mode,
              definitionController: TextEditingController(text: 'persistent'),
              definitionFocusNode: FocusNode(),
              onFillDefinition: () {},
              definitionSenses: senses,
              definitionPopupController: popup,
              onLoadDefinitionSenses: () async {
                lookups++;
                return ['loaded sense'];
              },
              onSelectDefinition: selected.add,
              onCloseDefinitionOptions: popup.hideMenu,
              isDragMode: false,
              wordController: TextEditingController(text: 'tenacious'),
              translationController: TextEditingController(text: 'x'),
              wordFocusNode: FocusNode(),
              translationFocusNode: FocusNode(),
              isLoadingWordTranslation: false,
              isLoadingTranslation: false,
              shouldShowWordIcon: false,
              shouldShowTranslationIcon: false,
              shouldShowPronunciation: false,
              popupController: CustomPopupMenuController(),
              onLoadTranslations: () async => null,
              onOpenTranslationOptions: () {},
              onCloseTranslationOptions: () {},
              onRemove: () {},
              onFillWordWithAI: () {},
              onFillWithAI: () {},
              onSelectTranslation: (_) {},
              onSpeak: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('stored senses open without a lookup; a tap picks one',
      (tester) async {
    await pumpRow(tester,
        mode: WordDetailMode.definition, senses: ['persistent', 'retentive']);

    expect(find.byType(DefinitionDotsButton), findsOneWidget);
    await tester.tap(find.byType(DefinitionDotsButton));
    await tester.pumpAndSettle();

    expect(find.text('retentive'), findsOneWidget);
    await tester.tap(find.text('retentive'));
    await tester.pumpAndSettle();

    expect(selected, ['retentive']);
    expect(lookups, 0);
  });

  testWidgets('with no senses, the popup loads them once', (tester) async {
    await pumpRow(tester, mode: WordDetailMode.both);

    await tester.tap(find.byType(DefinitionDotsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Load definitions'));
    await tester.pumpAndSettle();

    expect(lookups, 1);
    expect(find.text('loaded sense'), findsOneWidget);
  });

  testWidgets('translation mode has no definition dots', (tester) async {
    await pumpRow(tester, mode: WordDetailMode.translation, senses: ['a']);
    expect(find.byType(DefinitionDotsButton), findsNothing);
  });
}
