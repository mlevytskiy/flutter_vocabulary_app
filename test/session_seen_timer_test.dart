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

/// Owner, 2026-10-16: while the app is open the main screen records the
/// current session as seen every 15 s, and once more on going to the
/// background, so a launch soon after carries on in it.
class _CountingInput extends WordInputNotifier {
  int seen = 0;

  @override
  Future<void> markSeen() async => seen++;
}

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

  testWidgets('seen every 15 s while open, on pause, and again on resume',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    late Directory dir;
    late SessionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('session_seen_timer_test');
      store = await SessionStore.open(directory: dir.path);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    final input = _CountingInput();
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      wordInputNotifierProvider.overrideWith(() => input),
    ]);
    addTearDown(container.dispose);
    await tester
        .runAsync(() => container.read(wordInputNotifierProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    await tester.pump();
    expect(input.seen, 0);

    await tester.pump(WordInputNotifier.seenEvery);
    expect(input.seen, 1);
    await tester.pump(WordInputNotifier.seenEvery);
    expect(input.seen, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(input.seen, 3, reason: 'once more on going to the background');
    await tester.pump(const Duration(minutes: 1));
    expect(input.seen, 3, reason: 'nothing in the background');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(input.seen, 4, reason: 'back in the app');
    await tester.pump(WordInputNotifier.seenEvery);
    expect(input.seen, 5);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(WordInputNotifier.seenEvery);
    expect(input.seen, 5, reason: 'the timer goes with the screen');
  });
}
