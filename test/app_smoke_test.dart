@Tags(['smoke'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/app.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/history/history_screen.dart';
import 'package:flutter_vocabulary_app/features/settings/settings_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// The app smoke test (docs/testing.md): the real `App` with its router and
/// providers starts on a stored session and reaches every screen -- the words
/// table, History, a past session's table and Settings. It checks the wiring,
/// not the behaviour of each screen; that is the other test files' job.
void main() {
  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  testWidgets('the app starts on the current session and reaches every screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'translation'});
    // The store stays open: closing an Isar the screens watched under the fake
    // clock never returns (see switch_session_test.dart).
    late SessionStore store;
    late Session now;
    late Session past;
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('app_smoke_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      store = await SessionStore.open(directory: dir.path);
      now = Session.create()
        ..words = [WordPair(word: 'apple', translation: 'яблуко')];
      final pastAt = DateTime(2026, 9, 1, 12);
      past = Session.create()
        ..updatedAt = pastAt
        ..lastLocalModifiedAt = pastAt
        ..words = [WordPair(word: 'tea', translation: 'чай')];
      await store.put(now);
      await store.put(past);
      await store.setCurrentSessionId(now.sessionId);
    });
    // Isar's watch and reads never complete under the test's fake clock, so
    // the History list is the stored sessions as one emission, and the past
    // session is read up front in the real zone and kept.
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      nonEmptySessionsProvider.overrideWith((ref) => Stream.value([now, past])),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.listen(sessionByIdProvider(past.sessionId), (_, __) {});
      await container.read(sessionByIdProvider(past.sessionId).future);
      await container.read(wordInputNotifierProvider.future);
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const App(),
    ));
    await tester.pump();
    await tester.pump();

    // The main screen, on the current session.
    expect(find.byType(WordInputScreen), findsOneWidget);
    expect(container.read(wordInputNotifierProvider).value!.words.first.word,
        'apple');

    // Next -> the words table of the current session.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(WordsTableScreen), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('яблуко'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WordInputScreen), findsOneWidget);

    // The side menu -> History -> the past session's table.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('1 word'), findsNWidgets(2));
    await tester.tap(find.text('01.09.2026 12:00'));
    await tester.pumpAndSettle();
    expect(find.byType(WordsTableScreen), findsOneWidget);
    expect(find.text('tea'), findsOneWidget);
    expect(find.text('чай'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The settings button -> Settings.
    expect(find.byType(WordInputScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WordInputScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
