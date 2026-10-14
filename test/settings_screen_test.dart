import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/settings/settings_screen.dart';

/// definition-mode T3: three word detail mode choices in Settings, translation
/// selected on a fresh install (spec AC-01).
void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  RadioListTile<WordDetailMode> tile(WidgetTester tester, String label) =>
      tester.widget<RadioListTile<WordDetailMode>>(find.ancestor(
        of: find.text(label),
        matching: find.byType(RadioListTile<WordDetailMode>),
      ));

  testWidgets('shows three choices with Translation selected', (tester) async {
    await pump(tester);

    expect(find.byType(RadioListTile<WordDetailMode>), findsNWidgets(3));
    expect(find.text('Translation'), findsOneWidget);
    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('Translation + definition'), findsOneWidget);

    final group = tester.widget<RadioGroup<WordDetailMode>>(
        find.byType(RadioGroup<WordDetailMode>));
    expect(group.groupValue, WordDetailMode.translation);
    expect(tile(tester, 'Definition').value, WordDetailMode.definition);
  });

  testWidgets('tapping Definition changes the mode', (tester) async {
    final container = await pump(tester);

    await tester.tap(find.text('Definition'));
    await tester.pumpAndSettle();

    expect(container.read(wordDetailModeProvider), WordDetailMode.definition);
  });

  testWidgets('the drag-and-drop switch is still there', (tester) async {
    await pump(tester);
    expect(find.text('Drag and Drop мод'), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Drag and Drop мод'), findsOneWidget);
  });

  /// words-from-subtitles T8: the import values, the Update with each import
  /// switch and the model (ux-flows SCR-06; sad §6 F2; AC-05, AC-05b, AC-09, AC-21).
  group('subtitle import', () {
    Future<ProviderContainer> pumpTall(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = await pump(tester);
      await container.read(subtitleImportPrefsProvider.notifier).loaded;
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('shows the first-launch values', (tester) async {
      await pumpTall(tester);
      expect(find.text('Subtitle import'), findsOneWidget);
      expect(find.text('Understand this film'), findsNothing, reason: 'the purpose option is gone');
      expect(find.text('Frequent words for the future'), findsNothing);
      expect(tester.widget<DropdownButton<EnglishLevel>>(find.byType(DropdownButton<EnglishLevel>)).value, EnglishLevel.b2);
      expect(find.widgetWithText(TextField, '20'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Update with each import')).value, isTrue);
      expect(tester.widget<DropdownButton<SubtitleModel>>(find.byKey(const Key('subtitle-ai-model'))).value, SubtitleModel.sonnet5);
      expect(tester.widget<DropdownButton<SubtitleModel>>(find.byKey(const Key('subtitle-opencode-model'))).value, SubtitleModel.glm53Flash);
    });

    testWidgets('each change is saved through the notifier', (tester) async {
      final container = await pumpTall(tester);

      await tester.tap(find.byType(DropdownButton<EnglishLevel>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C1').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('subtitle-maximum')), '35');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Update with each import'));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Rank words repeated close together higher')).value,
          isTrue, reason: 'on by default');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Rank words repeated close together higher'));
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Remove names')).value, isTrue,
          reason: 'on by default');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Remove names'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subtitle-ai-model')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Haiku 4.5').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('subtitle-opencode-model')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kimi K3').last);
      await tester.pumpAndSettle();

      expect(tester.widget<DropdownButton<SubtitleTranslator>>(find.byType(DropdownButton<SubtitleTranslator>)).value,
          SubtitleTranslator.google, reason: 'Google Translate is the default');
      await tester.tap(find.byType(DropdownButton<SubtitleTranslator>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI').last);
      await tester.pumpAndSettle();

      expect(container.read(subtitleImportPrefsProvider), const SubtitleImportPrefs(
        level: EnglishLevel.c1,
        maximum: 35,
        updateEachImport: false,
        model: SubtitleModel.haiku45,
        translator: SubtitleTranslator.ai,
        opencodeModel: SubtitleModel.kimiK3,
        boostCloseRepeats: false,
        removeNames: false,
      ));
    });

    testWidgets('the four Anthropic models and the five OpenCode models are listed apart', (tester) async {
      await pumpTall(tester);
      await tester.tap(find.byKey(const Key('subtitle-ai-model')));
      await tester.pumpAndSettle();
      for (final label in ['Sonnet 5', 'Sonnet 5.5', 'Haiku 4.5', 'Opus 5.5']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Kimi K3'), findsNothing);
      await tester.tap(find.text('Sonnet 5').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subtitle-opencode-model')));
      await tester.pumpAndSettle();
      for (final label in ['GLM 5.3 Flash', 'DeepSeek V4.1 Flash', 'MiniMax M3', 'DeepSeek V4 Pro', 'Kimi K3']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('a maximum of 0 or 101 is not saved and says it must be from 1 to 100', (tester) async {
      final container = await pumpTall(tester);
      for (final value in ['0', '101', '']) {
        await tester.enterText(find.byKey(const Key('subtitle-maximum')), value);
        await tester.pumpAndSettle();
        expect(find.text('The maximum must be from 1 to 100'), findsOneWidget, reason: value);
        expect(container.read(subtitleImportPrefsProvider).maximum, 20, reason: value);
      }
      expect((await SharedPreferences.getInstance()).getInt('subtitle_maximum'), isNull);

      await tester.enterText(find.byKey(const Key('subtitle-maximum')), '100');
      await tester.pumpAndSettle();
      expect(find.text('The maximum must be from 1 to 100'), findsNothing);
      expect(container.read(subtitleImportPrefsProvider).maximum, 100);
    });
  });
}
