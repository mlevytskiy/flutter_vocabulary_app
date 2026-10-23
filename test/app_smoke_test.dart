@Tags(['smoke'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/app.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/features/app_menu/app_drawer.dart';
import 'package:flutter_vocabulary_app/features/app_settings/app_settings_screen.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_screen.dart';
import 'package:flutter_vocabulary_app/features/settings/settings_screen.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

import 'seed_collections.dart';

/// The app smoke test (docs/testing.md): the real `App` with its router and
/// providers starts on Collections and reaches every screen -- through the
/// side menu Words and App settings, from Words the words table and Settings.
/// It checks the wiring,
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

  testWidgets('the app starts on Collections and reaches every screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'translation'});
    // The store stays open: closing an Isar the screens watched under the fake
    // clock never returns (see switch_collection_test.dart).
    late CollectionStore store;
    late WordCollection now;
    late WordCollection past;
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('app_smoke_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      store = await CollectionStore.open(directory: dir.path);
      now = WordCollection.create()
        ..words = [WordPair(word: 'apple', translation: 'яблуко')];
      final pastAt = DateTime(2026, 9, 1, 12);
      past = WordCollection.create()
        ..updatedAt = pastAt
        ..lastLocalModifiedAt = pastAt
        ..words = [WordPair(word: 'tea', translation: 'чай')];
      await seedCollection(store, now);
      await seedCollection(store, past);
      await store.setCurrentCollectionId(now.collectionId);
    });
    // Isar's watch and reads never complete under the test's fake clock, so
    // the Collections level is the stored sessions as one emission.
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      // Isar's watch never completes under the fake clock either.
      collectionLevelProvider(null).overrideWith(
          (ref) => Stream.value([LevelItem.collection(now), LevelItem.collection(past)])),
      collectionFoldersProvider.overrideWith((ref) => Stream.value([])),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordsProvider.future);
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
    });

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const App(),
    ));
    await tester.pump();
    await tester.pump();

    // Collections is the start screen: the menu button, no Back; no
    // new-user trial line.
    expect(find.byType(CollectionsScreen), findsOneWidget);
    expect(find.byTooltip('Recycle bin'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byKey(TrialFrame.lineKey), findsNothing);

    // The side menu: Collections, Words, App settings, in that order.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    double top(Key key) => tester.getTopLeft(find.byKey(key)).dy;
    expect(top(AppDrawer.collectionsKey), lessThan(top(AppDrawer.wordsKey)));
    expect(top(AppDrawer.wordsKey), lessThan(top(AppDrawer.appSettingsKey)));
    expect(find.text('History'), findsNothing);
    expect(find.text('Main'), findsNothing);

    // Words: the current session, with the menu button, not Back.
    await tester.tap(find.byKey(AppDrawer.wordsKey));
    await tester.pumpAndSettle();
    expect(find.byType(WordsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(container.read(wordsProvider).value!.words.first.word,
        'apple');
    // The rows show the collection's words, not an empty placeholder row.
    final appleRow = find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == 'apple');
    expect(appleRow, findsOneWidget);
    // Opens without the keyboard: no row has focus (owner, 2026-10-18).
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));

    // Next -> the words table of the current session.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(WordsTableScreen), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('яблуко'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WordsScreen), findsOneWidget);

    // The settings button -> Settings.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WordsScreen), findsOneWidget);

    // Back on Words goes to Collections, the start screen.
    final wordsState = tester.state(find.byType(WordsScreen));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsOneWidget);

    // Back to Words through the side menu: the drawer slides shut over
    // Collections first, then the same Words screen shows again (the menu
    // screens stay alive in one shell), its rows still there.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppDrawer.wordsKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.byType(CollectionsScreen), findsOneWidget);
    expect(find.byType(WordsScreen), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(WordsScreen), findsOneWidget);
    expect(tester.state(find.byType(WordsScreen)), same(wordsState));
    expect(appleRow, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsOneWidget);

    // The side menu -> App settings, with the menu button; Back -> Collections.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppDrawer.appSettingsKey));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CollectionsScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
