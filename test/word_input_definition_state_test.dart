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

/// definition-mode T10: the real input screen carries each row's definition
/// through edits (spec AC-11; spec §8 resolved — a word edit keeps the
/// definition text and drops its stored senses).
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

  late Directory dir;
  late SessionStore store;
  late ProviderContainer container;

  Future<void> pumpScreen(WidgetTester tester, List<WordPair> words) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('definition_state_test');
      store = await SessionStore.open(directory: dir.path);
      final session = Session.create()..words = words;
      await store.put(session);
      await store.setCurrentSessionId(session.sessionId);
    });
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
    ]);
    // Resolve the session outside the fake-async zone: Isar needs real I/O.
    await tester
        .runAsync(() => container.read(wordInputNotifierProvider.future));
    // Not closing the store: Isar would wait for a write begun inside the
    // widget test's fake-async zone, which never finishes. One test per file
    // keeps the open instance from colliding.
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    // In the app the session resolves after the screen mounts, and the
    // screen's ref.listen rebuilds its rows from it. Here it resolved first
    // (Isar needs real I/O), so re-emit it once to drive that same path.
    final notifier = container.read(wordInputNotifierProvider.notifier);
    notifier.setPairs(
        List.of(container.read(wordInputNotifierProvider).value!.words));
    await tester.pump();
    await tester.pump();
  }

  List<WordPair> words() =>
      container.read(wordInputNotifierProvider).value!.words;

  /// Unmounts the screen (its dispose() still reads providers) and disposes
  /// the container, which cancels the notifier's debounced save timer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('editing the word keeps the definition, drops its senses',
      (tester) async {
    await pumpScreen(tester, [
      WordPair(
        word: 'tenacious',
        definition: 'persistent',
        definitionOptionsJson: '{"senses":["persistent","retentive"]}',
        definitionMarkedFilled: true,
      ),
    ]);
    expect(words()[0].definition, 'persistent');

    await tester.enterText(find.byType(TextField).first, 'tenacity');
    await tester.pump();

    expect(words()[0].word, 'tenacity');
    expect(words()[0].definition, 'persistent');
    expect(words()[0].definitionMarkedFilled, isTrue);
    expect(words()[0].definitionOptionsJson, isNull);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Row alignment on remove/reorder is covered at the notifier level
  // (word_input_notifier_test.dart); removing a row here goes through the
  // pronunciation plugin, which this harness cannot drive.
}
