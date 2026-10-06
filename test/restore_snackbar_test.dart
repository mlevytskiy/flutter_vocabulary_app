import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// The launch rule: a previous session gone cold (over 5 minutes) is offered
/// back by the RESTORE snackbar as soon as the app starts.
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

  testWidgets('a cold previous session shows the RESTORE snackbar at start',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    late Directory dir;
    late SessionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('restore_snackbar_test');
      store = await SessionStore.open(directory: dir.path);
      final prev = Session.create()
        ..words = [WordPair(word: 'harbour', translation: 'гавань')]
        ..lastLocalModifiedAt =
            DateTime.now().subtract(const Duration(minutes: 30));
      await store.put(prev);
      await store.setCurrentSessionId(prev.sessionId);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
    ]);
    addTearDown(container.dispose);
    // The screen is the first to read the session, as in the app; the store
    // works on the real clock.
    await tester.runAsync(() async {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WordInputScreen()),
      ));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (container.read(wordInputNotifierProvider).hasValue) break;
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('We kept the words you typed before'), findsOneWidget);
    expect(find.text('RESTORE'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 60)));
}
