import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// The settings button sits on the same horizontal line as the speed dial's
/// plus button, also on a phone with a bottom safe area (the home indicator).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  testWidgets('settings and plus buttons share a baseline above the home bar',
      (tester) async {
    // An iPhone-like screen: 390x844 pt, 3x, 34 pt home-indicator inset.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(bottom: 102);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    late Directory dir;
    late SessionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('settings_fab_test');
      store = await SessionStore.open(directory: dir.path);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
    ]);
    await tester
        .runAsync(() => container.read(wordInputNotifierProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    await tester.pump();

    final settings = tester.getRect(find.byTooltip('Settings'));
    final plus = tester.getRect(find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(FloatingActionButton)));
    expect(settings.center.dy, moreOrLessEquals(plus.center.dy, epsilon: 0.5));

    // Keyboard up: the platform reports the keyboard as a view inset and the
    // bottom safe-area padding as 0. Both buttons must still share a line.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pump();
    final settingsUp = tester.getRect(find.byTooltip('Settings'));
    final plusUp = tester.getRect(find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(FloatingActionButton)));
    expect(
        settingsUp.center.dy, moreOrLessEquals(plusUp.center.dy, epsilon: 0.5));

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
