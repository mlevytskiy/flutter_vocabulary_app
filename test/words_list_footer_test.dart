import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words/words_screen.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/word_row_item.dart';

import 'seed_collections.dart';

/// Words list footer (owner, 2026-11-03): scrolled to the end, the last row
/// (the blank one for a new word) sits above the round buttons.
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

  testWidgets('scrolled to the end, the last row is clear of the round buttons',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    late Directory dir;
    late CollectionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('words_list_footer_test');
      store = await CollectionStore.open(directory: dir.path);
      final collection = WordCollection.create()
        ..words = [for (var i = 0; i < 30; i++) WordPair(word: 'word$i', translation: 'т$i')];
      await seedCollection(store, collection);
      await store.setCurrentCollectionId(collection.collectionId);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    await tester.runAsync(() => container.read(wordsProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordsScreen()),
    ));
    await tester.pump();
    await tester.pump();

    final list = find.descendant(
        of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(list).position;
    // The extent grows as lazily built rows are measured: jump until it holds.
    for (var i = 0; i < 10 && position.pixels < position.maxScrollExtent - 0.5 || i == 0; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
    }
    final lastRow = find.byType(WordRowItem).last;
    final plus = tester.getRect(find.ancestor(
        of: find.byIcon(Icons.add), matching: find.byType(FloatingActionButton)));
    expect(tester.getRect(lastRow).bottom, lessThanOrEqualTo(plus.top),
        reason: 'the blank row for a new word is not under the round buttons');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a Word field tapped behind the settings button scrolls above it',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    late Directory dir;
    late CollectionStore store;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('words_field_scroll_test');
      store = await CollectionStore.open(directory: dir.path);
      final collection = WordCollection.create()
        ..words = [for (var i = 0; i < 30; i++) WordPair(word: 'word$i', translation: 'т$i')];
      await seedCollection(store, collection);
      await store.setCurrentCollectionId(collection.collectionId);
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
    });
    final container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
    ]);
    await tester.runAsync(() => container.read(wordsProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordsScreen()),
    ));
    await tester.pump();
    await tester.pump();

    final settings = tester.getRect(find.byTooltip('Settings'));
    // A Word field (left half) whose bottom part is behind the settings button.
    final behind = find.byWidgetPredicate((w) {
      if (w is! TextField || w.decoration?.labelText != 'Word') return false;
      return true;
    }).evaluate().where((e) {
      final box = e.renderObject! as RenderBox;
      final r = box.localToGlobal(Offset.zero) & box.size;
      return r.top < settings.top && r.bottom > settings.top;
    }).toList();
    expect(behind, isNotEmpty, reason: 'the test needs a field behind the button');
    final word = (behind.first.widget as TextField).controller!.text;
    final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Word' && w.controller?.text == word);

    await tester.tap(field);
    await tester.pumpAndSettle();

    expect(tester.getRect(field).bottom, lessThanOrEqualTo(settings.top),
        reason: 'the focused Word field is not behind the settings button');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
