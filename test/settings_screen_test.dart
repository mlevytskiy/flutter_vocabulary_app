import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
