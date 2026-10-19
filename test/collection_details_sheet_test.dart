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
import 'package:flutter_vocabulary_app/core/theme/app_decor.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_details_sheet.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';

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
    String? aiNameUntil,
    bool aiDescription = false,
  }) async {
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCollectionDetailsSheet(context,
                    mode: mode,
                    initial: initial,
                    aiNameUntil: aiNameUntil,
                    aiDescription: aiDescription);
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

  testWidgets('create: title, the name optional, name only', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    expect(find.text('New collection'), findsOneWidget);
    // collection-naming: an empty name is left to AI, and the sheet says so.
    expect(enabled(t), isTrue);
    expect(find.text('Name (optional)'), findsOneWidget);
    expect(find.byKey(const Key('details-ai-name-note')), findsOneWidget);
    expect(
        find.byKey(const Key('details-ai-description-note')), findsOneWidget);
    await t.enterText(find.byKey(const Key('details-name')), 'Friends S01');
    await t.pumpAndSettle();
    expect(enabled(t), isTrue);
    expect(find.byKey(const Key('details-ai-name-note')), findsNothing);
    await t.enterText(
        find.byKey(const Key('details-description')), 'About friends');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('details-ai-description-note')), findsNothing);
    await t.enterText(find.byKey(const Key('details-description')), '');
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

  testWidgets('create: Create stays on screen above the keyboard', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await t.pumpAndSettle();
    final button = t.getRect(confirm());
    expect(button.bottom, lessThanOrEqualTo(640 - 300));
    expect(button.top, greaterThan(0));
    // Tappable without scrolling first.
    await t.tap(confirm());
    await t.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets(
      'create: the description note sits on the counter line, in '
      'the AI colour, not a tag tint', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    final note = find.byKey(const Key('details-ai-description-note'));
    final counter = find.text('0/$maxDescriptionLength');
    expect((t.getCenter(note).dy - t.getCenter(counter).dy).abs(), lessThan(4));
    expect(t.getRect(note).right, lessThan(t.getRect(counter).left));
    final text =
        t.widget<Text>(find.descendant(of: note, matching: find.byType(Text)));
    final scheme = Theme.of(t.element(note)).colorScheme;
    expect(text.style?.color, AppDecor.classic.aiAccent);
    expect(text.style?.color, isNot(scheme.secondaryContainer));
    expect(text.style?.color, isNot(scheme.tertiaryContainer));
    expect(find.descendant(of: note, matching: find.byType(DecoratedBox)),
        findsNothing);
  });

  testWidgets('create: an empty name hands back a blank one for AI', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
    await t.enterText(find.byKey(const Key('details-name')), '   ');
    await t.pump();
    expect(enabled(t), isTrue);
    expect(find.text('A name must be 1 to 60 characters on one line'),
        findsNothing);
    await t.ensureVisible(confirm());
    await t.pump();
    await t.tap(confirm());
    await t.pumpAndSettle();
    expect(result!.name, '');
  });

  testWidgets('edit: the name stays required', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t,
        mode: DetailsMode.edit,
        initial: (name: 'Trip', description: '', origin: [], topic: []));
    expect(find.byKey(const Key('details-ai-name-note')), findsNothing);
    expect(find.byKey(const Key('details-ai-description-note')), findsNothing);
    await t.enterText(find.byKey(const Key('details-name')), '');
    await t.pump();
    expect(enabled(t), isFalse);
  });

  testWidgets('edit: a name and description nobody gave show the AI notes',
      (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t,
        mode: DetailsMode.edit,
        initial: (name: '', description: '', origin: [], topic: []),
        aiNameUntil: 'Vocabulary 2',
        aiDescription: true);
    expect(find.text('Name (optional)'), findsOneWidget);
    expect(find.text('Leave empty to let AI name it'), findsOneWidget);
    expect(find.text('Leave empty to let AI write it'), findsOneWidget);
    expect(find.byKey(const Key('details-ai-name-note')), findsOneWidget);
    expect(find.textContaining('"Vocabulary 2"'), findsOneWidget);
    expect(
        find.byKey(const Key('details-ai-description-note')), findsOneWidget);
    expect(enabled(t), isTrue);
    await t.enterText(find.byKey(const Key('details-name')), 'Trip');
    await t.pump();
    expect(find.byKey(const Key('details-ai-name-note')), findsNothing);
    await t.enterText(find.byKey(const Key('details-name')), '');
    await t.pump();
    await t.tap(confirm());
    await t.pumpAndSettle();
    expect(result?.name, '');
  });

  testWidgets('invalid name disables the button with the message', (t) async {
    await setUpStore(t);
    addTearDown(() => tearDownStore(t));
    await openSheet(t);
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
      await container.read(wordsNotifierProvider.future);
      await container
          .read(wordsNotifierProvider.notifier)
          .newCollectionWithDetails(null,
              name: 'Kitchen talk',
              description: 'Season 1 phrases',
              origin: ['Podcast'],
              topic: ['Food']);
      final current = container.read(wordsNotifierProvider).value!;
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
      await container.read(wordsNotifierProvider.future);
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
          await container.read(wordsNotifierProvider.notifier).saveDetails(
                name: result!.name,
                description: result!.description,
                origin: result!.origin,
                topic: result!.topic,
              );
      expect(saved, isTrue);
      final now = container.read(wordsNotifierProvider).value!;
      expect(now.name, 'Dining room');
      expect(now.topicTags, ['Food']);
      expect((await store.byId(seeded.collectionId))!.name, 'Dining room');
    });
  });
}
