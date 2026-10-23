import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/theme/app_theme.dart';
import 'package:flutter_vocabulary_app/features/app_settings/app_settings_screen.dart';

/// app-themes: the five themes, the stored choice and the App settings page.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('five themes, one per id, each with its AppDecor', () {
    expect(appThemes, hasLength(5));
    expect({for (final t in appThemes) t.id}, AppThemeId.values.toSet());
    for (final spec in appThemes) {
      final data = spec.build();
      final decor = data.extension<AppDecor>();
      expect(decor, isNotNull, reason: spec.name);
      expect(data.colorScheme.inversePrimary, decor!.topBar, reason: spec.name);
    }
  });

  test(
      'Classic keeps its colours, takes Matcha\'s fonts and near-black text, '
      'and has purples where Matcha has dark greens', () {
    final data = classicTheme();
    final matcha = AppThemeSpec.of(AppThemeId.matcha).build();
    final before = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    expect(data.colorScheme.primary, before.primary);
    expect(data.colorScheme.surface, before.surface);
    expect(data.colorScheme.inversePrimary, classicTopBarColor);
    expect(data.appBarTheme.backgroundColor, classicTopBarColor);
    expect(data.colorScheme.onSurface, matcha.colorScheme.onSurface);
    expect(data.colorScheme.onSurfaceVariant, const Color(0xFF49454E));
    expect(data.textTheme.bodyLarge!.fontFamily, 'Nunito');
    expect(data.textTheme.titleLarge!.fontFamily, 'Comfortaa');
    expect(data.textTheme.bodyLarge!.color, matcha.textTheme.bodyLarge!.color);
    final m = matcha.extension<AppDecor>()!;
    // Owner, 2026-10-18: the dark green text is the Next button's purple.
    expect(AppDecor.classic.rowText, data.colorScheme.primary);
    expect(AppDecor.classic.rowText, classicDarkPurple);
    expect(AppDecor.classic.strongIcon, classicDarkPurple);
    expect(AppDecor.classic.rowText, isNot(m.rowText));
    expect(AppDecor.classic.muted, isNot(m.muted));
    expect(AppDecor.classic.wordRow, const Color(0x57d9c1ff));
    expect(AppDecor.classic.fab, Colors.red);
    expect(AppDecor.classic.fabAlt, const Color(0xff954ef3));
    expect(AppDecor.classic.popup, Colors.black87);
    expect(AppDecor.classic.pic500, const Color(0xff954ef3));
    expect(AppDecor.classic.picOutline, isFalse);
  });

  testWidgets('Classic\'s top-bar title is the size of Matcha\'s',
      (tester) async {
    Future<Size> titleSize(AppThemeId id) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppThemeSpec.of(id).build(),
        home: Scaffold(appBar: AppBar(title: const Text('Trip'))),
      ));
      return tester.getSize(find.text('Trip'));
    }

    expect(await titleSize(AppThemeId.classic),
        await titleSize(AppThemeId.matcha));
  });

  testWidgets(
      'every theme puts the title right after the menu or Back button, as on '
      'Words (owner, 2026-10-18)', (t) async {
    for (final spec in appThemes) {
      await t.pumpWidget(MaterialApp(
        theme: spec.build(),
        home: Scaffold(
          drawer: const Drawer(),
          appBar: AppBar(title: const Text('Title')),
        ),
      ));
      final button = t.getRect(find.byType(DrawerButton));
      expect(button.right, 48, reason: spec.name);
      expect(t.getRect(find.text('Title')).left, 48, reason: spec.name);
    }
  });

  test('the kept themes recolour what Classic hard-coded', () {
    for (final id in [
      AppThemeId.aurora,
      AppThemeId.matcha,
      AppThemeId.amberTerminal,
      AppThemeId.windows95
    ]) {
      final d = AppThemeSpec.of(id).build().extension<AppDecor>()!;
      expect(d.rowIcon, isNot(AppDecor.classic.rowIcon), reason: id.name);
      expect(d.pic500, isNot(AppDecor.classic.pic500), reason: id.name);
      expect(d.popup, isNot(AppDecor.classic.popup), reason: id.name);
      expect(d.addAccent, isNot(AppDecor.classic.addAccent), reason: id.name);
    }
    expect(
        AppThemeSpec.of(AppThemeId.amberTerminal)
            .build()
            .extension<AppDecor>()!
            .picOutline,
        isTrue);
    final w95 =
        AppThemeSpec.of(AppThemeId.windows95).build().extension<AppDecor>()!;
    expect(w95.wordRowRadius, 0);
    expect(w95.wordRowBorder, isA<Border>());
  });

  testWidgets('AppDecor.of falls back to Classic without an app theme',
      (tester) async {
    late AppDecor decor;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      decor = AppDecor.of(context);
      return const SizedBox();
    })));
    expect(decor, same(AppDecor.classic));
  });

  test('the stored theme is read back', () async {
    SharedPreferences.setMockInitialValues(
        {AppThemeNotifier.prefsKey: AppThemeId.aurora.name});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(appThemeProvider), AppThemeId.classic);
    await container.read(appThemeProvider.notifier).loaded;
    expect(container.read(appThemeProvider), AppThemeId.aurora);
  });

  test('an unknown or removed stored name is Classic', () async {
    SharedPreferences.setMockInitialValues(
        {AppThemeNotifier.prefsKey: 'bauhaus'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appThemeProvider.notifier).loaded;
    expect(container.read(appThemeProvider), AppThemeId.classic);
  });

  testWidgets('a tapped theme card switches the theme and is stored',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AppSettingsScreen()),
    ));
    await tester.pumpAndSettle();
    for (final id in AppThemeId.values) {
      expect(find.byKey(AppSettingsScreen.themeKey(id)), findsOneWidget);
    }
    await tester.tap(find.byKey(AppSettingsScreen.themeKey(AppThemeId.matcha)));
    await tester.pumpAndSettle();
    expect(container.read(appThemeProvider), AppThemeId.matcha);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppThemeNotifier.prefsKey), 'matcha');
  });
}
