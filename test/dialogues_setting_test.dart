import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/settings/settings_screen.dart';

/// get-words-from-subtitles-improvment T16: the "Get dialogues from subtitles"
/// switch in Settings, off on first launch and kept across restarts (SCR-03).
void main() {
  const label = 'Get dialogues from subtitles';

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  SwitchListTile row(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label));

  testWidgets('is off on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pump(tester);

    await tester.scrollUntilVisible(find.text(label), 200,
        scrollable: find.byType(Scrollable).first);
    expect(row(tester).value, isFalse);
    expect(container.read(dialoguesSettingProvider), isFalse);
  });

  testWidgets('tapping it turns it on and saves it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await pump(tester);

    await tester.scrollUntilVisible(find.text(label), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(row(tester).value, isTrue);
    expect(container.read(dialoguesSettingProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(DialoguesSettingNotifier.prefsKey), isTrue);
  });

  testWidgets('a restart keeps the value', (tester) async {
    SharedPreferences.setMockInitialValues(
        {DialoguesSettingNotifier.prefsKey: true});
    final container = await pump(tester);
    await container.read(dialoguesSettingProvider.notifier).loaded;
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(label), 200,
        scrollable: find.byType(Scrollable).first);
    expect(row(tester).value, isTrue);
    expect(container.read(dialoguesSettingProvider), isTrue);
  });
}
