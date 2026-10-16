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
import 'package:flutter_vocabulary_app/features/collections/collection_details_sheet.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

import 'seed_collections.dart';

/// collection-tags T10: the Collection details sheet and its wiring (AC-01,
/// 02, 03, 05, 27, 36).
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
  late CollectionStore store;
  late ProviderContainer container;
  CollectionDetails? result;
  var closed = false;

  // Real IO must run outside the widget tester's fake-async zone.
  Future<void> setUpStore(WidgetTester t) => t.runAsync(() async {
        SharedPreferences.setMockInitialValues({});
        dir = Directory.systemTemp
            .createTempSync('collection_details_sheet_test');
        store = await CollectionStore.open(directory: dir.path);
        container = ProviderContainer(overrides: [
          collectionStoreProvider.overrideWith((ref) async => store),
          // no live Isar watches: they keep store.close() waiting
          tagLibraryProvider.overrideWith((ref) => Stream.value([])),
          collectionSummariesProvider.overrideWith((ref) => Stream.value([])),
        ]);
        result = null;
        closed = false;
      });

  Future<void> tearDownStore(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      container.dispose();
      await store.close();

      dir.deleteSync(recursive: true);
    });
  }

  Future<void> openSheet(
    WidgetTester t, {
    DetailsMode mode = DetailsMode.create,
    CollectionDetails? initial,
  }) async {
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCollectionDetailsSheet(context,
                    mode: mode, initial: initial);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  Finder confirm() => find.byKey(const Key('details-confirm'));
  bool enabled(WidgetTester t) =>
      t.widget<FilledButton>(confirm()).onPressed != null;

  Future<void> addTag(WidgetTester t, String kind, String text) async {
    await t.enterText(find.byKey(ValueKey('details-$kind-field')), text);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
  }

  testWidgets('create: title, Create disabled until a name, name only',
      (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    expect(find.text('New collection'), findsOneWidget);
    expect(enabled(t), isFalse);
    await t.enterText(find.byKey(const Key('details-name')), 'Friends S01');
    await t.pump();
    expect(enabled(t), isTrue);
    await t.ensureVisible(confirm());
    await t.pump();
    await t.tap(confirm());
    await t.pumpAndSettle();
    expect(closed, isTrue);
    expect(result!.name, 'Friends S01');
    expect(result!.description, '');
    expect(result!.origin, isEmpty);
    expect(result!.topic, isEmpty);
  });

  testWidgets('invalid name disables the button with the message', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await t.enterText(find.byKey(const Key('details-name')), '   ');
    await t.pump();
    expect(enabled(t), isFalse);
    expect(find.text('A name must be 1 to 60 characters on one line'),
        findsOneWidget);
    await t.enterText(find.byKey(const Key('details-name')), 'x' * 61);
    await t.pump();
    expect(enabled(t), isFalse);
    await t.enterText(find.byKey(const Key('details-name')), 'ok');
    await t.pump();
    expect(enabled(t), isTrue);
  });

  testWidgets('a description over 500 disables the button with the message',
      (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await t.enterText(find.byKey(const Key('details-name')), 'ok');
    await t.enterText(find.byKey(const Key('details-description')), 'd' * 501);
    await t.pump();
    expect(enabled(t), isFalse);
    expect(find.text(descriptionProblemMessage), findsOneWidget);
    await t.enterText(find.byKey(const Key('details-description')), 'd' * 500);
    await t.pump();
    expect(enabled(t), isTrue);
  });

  testWidgets('dismiss with no change closes silently', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await t.tapAt(const Offset(10, 10)); // the barrier
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('dismiss after a change asks; Keep editing keeps the sheet',
      (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await t.enterText(find.byKey(const Key('details-name')), 'Draft');
    await t.pump();
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await t.tap(find.text('Keep editing'));
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byKey(const Key('details-name')), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('dismiss after a change asks; Discard closes with null',
      (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await addTag(t, 'origin', 'Podcast');
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('details-name')), findsNothing);
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('swipe down on the handle after a change asks too', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await t.enterText(find.byKey(const Key('details-name')), 'Draft');
    await t.pump();
    await t.fling(
        find.byKey(const Key('details-handle')), const Offset(0, 300), 1000);
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('create with description and tags returns them', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await t.enterText(find.byKey(const Key('details-name')), 'Kitchen talk');
    await t.enterText(
        find.byKey(const Key('details-description')), 'Season 1 phrases');
    await addTag(t, 'origin', 'Podcast');
    await addTag(t, 'topic', 'Food');
    await t.ensureVisible(confirm());
    await t.pump();
    await t.tap(confirm());
    await t.pumpAndSettle();
    expect(result!.description, 'Season 1 phrases');
    expect(result!.origin, ['Podcast']);
    expect(result!.topic, ['Food']);
  });

  testWidgets('New collection flow: the notifier makes it with the details',
      (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await t.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
      await container
          .read(wordInputNotifierProvider.notifier)
          .newCollectionWithDetails(null,
              name: 'Kitchen talk',
              description: 'Season 1 phrases',
              origin: ['Podcast'],
              topic: ['Food']);
      final current = container.read(wordInputNotifierProvider).value!;
      final stored = (await store.byId(current.collectionId))!;
      expect(stored.name, 'Kitchen talk');
      expect(stored.description, 'Season 1 phrases');
      expect(stored.originTags, ['Podcast']);
      expect(stored.topicTags, ['Food']);
      expect(stored.keep, isTrue);
    });
  });

  testWidgets('edit: Save updates the name and tags through the notifier',
      (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    late WordCollection seeded;
    await t.runAsync(() async {
      seeded = WordCollection.create()
        ..name = 'Kitchen'
        ..words = [WordPair(word: 'apple', translation: 'яблуко')];
      await seedCollection(store, seeded);
      await store.setCurrentCollectionId(seeded.collectionId);
      await container.read(wordInputNotifierProvider.future);
    });
    await openSheet(t,
        mode: DetailsMode.edit,
        initial: (name: 'Kitchen', description: '', origin: [], topic: []));
    expect(find.text('Collection details'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await t.enterText(find.byKey(const Key('details-name')), 'Dining room');
    await addTag(t, 'topic', 'Food');
    await t.ensureVisible(confirm());
    await t.pump();
    await t.tap(confirm());
    await t.pumpAndSettle();
    expect(result!.name, 'Dining room');
    await t.runAsync(() async {
      final saved =
          await container.read(wordInputNotifierProvider.notifier).saveDetails(
                name: result!.name,
                description: result!.description,
                origin: result!.origin,
                topic: result!.topic,
              );
      expect(saved, isTrue);
      final now = container.read(wordInputNotifierProvider).value!;
      expect(now.name, 'Dining room');
      expect(now.topicTags, ['Food']);
      expect((await store.byId(seeded.collectionId))!.name, 'Dining room');
    });
  });
}
