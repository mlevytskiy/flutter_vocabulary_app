import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/features/collections/collection_drag.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_results_view.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

/// collection-tags T13 (SCR-05; AC-14, AC-19, AC-22, AC-23, AC-24, AC-27,
/// AC-39): search mode and the flat results of the Collections screen.

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.collection);
  final WordCollection collection;
  final opened = <String>[];

  @override
  Future<WordCollection> build() async => collection;

  @override
  Future<bool> open(String id) async {
    opened.add(id);
    return true;
  }
}

CollectionFolder _folder(String id, String name, String? parent) =>
    CollectionFolder()
      ..folderId = id
      ..name = name
      ..parentId = parent;

WordCollection _coll(String name, int words) => WordCollection.create()
  ..name = name
  ..words = [
    for (var i = 0; i < words; i++) WordPair(word: 'w$i', translation: 't$i')
  ];

CollectionSummary _summary(
  String id,
  String name, {
  String description = '',
  List<String> origin = const [],
  List<String> topic = const [],
  String path = 'Top level',
  int index = 0,
}) =>
    CollectionSummary(
      id: id,
      name: name,
      description: description,
      originTags: origin,
      topicTags: topic,
      sourceOriginKeys: const {},
      sourceTopicKeys: const {},
      folderPath: path,
      treeIndex: index,
      created: DateTime(2026, 10, 1),
      edited: DateTime(2026, 10, 1),
    );

void main() {
  final films = _folder('f1', 'Films', null);
  final podcasts = _folder('f2', 'Podcasts', 'f1');
  final current = _coll('Phrasal verbs', 3);
  final summaries = [
    _summary('k', 'Kitchen talk',
        description: 'From the cooking podcast',
        origin: ['Podcast'],
        topic: ['Food'],
        path: 'Films / Podcasts',
        index: 0),
    _summary('c', 'Cooking club', path: 'Top level', index: 1),
    _summary('d', 'Dark S1', origin: ['Netflix'], path: 'Films', index: 2),
    _summary('o', 'Food court', origin: ['Food'], path: 'Top level', index: 3),
    _summary(current.collectionId, 'Phrasal verbs', index: 4),
  ];
  late _FakeInput input;

  /// The main screen at `/` with Collections pushed on top at `/c`, as the
  /// drawer (`go`) or a tag tap (`push`) leave it: Back can pop to main.
  Future<void> pump(
    WidgetTester t, {
    TagKind? tagKind,
    String? tag,
  }) async {
    input = _FakeInput(current);
    await t.pumpWidget(ProviderScope(
      overrides: [
        wordInputNotifierProvider.overrideWith(() => input),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([films, podcasts])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(films),
              LevelItem.collection(current),
            ])),
        collectionLevelProvider('f1').overrideWith((ref) => Stream.value([
              LevelItem.folder(podcasts),
            ])),
        collectionSummariesProvider
            .overrideWith((ref) => Stream.value(summaries)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/c', routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Text('MAIN SCREEN'),
            routes: [
              GoRoute(
                path: 'c',
                // The real route's build, so the query fields reach the
                // screen as they do in the app.
                builder: (context, state) =>
                    CollectionsRoute(tagKind: tagKind, tag: tag)
                        .build(context, state),
              ),
            ],
          ),
        ]),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1));
  }

  Future<void> openSearch(WidgetTester t, String query) async {
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    await t.enterText(find.byType(TextField), query);
    await t.pump();
    await t.pump();
  }

  Future<void> back(WidgetTester t) async {
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
  }

  Finder resultTile(String name) =>
      find.widgetWithText(CollectionResultTile, name);

  testWidgets('the top bar has search and filter icons', (t) async {
    await pump(t);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets(
      'search entry: field in the top bar with autofocus; empty query keeps '
      'the folder view', (t) async {
    await pump(t);
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    final field = t.widget<TextField>(find.descendant(
        of: find.byType(AppBar), matching: find.byType(TextField)));
    expect(field.autofocus, isTrue);
    expect(find.text('Films'), findsOneWidget); // the folder icon
    expect(find.byType(CollectionResultTile), findsNothing);
  });

  testWidgets(
      'AC-19: typing "cook" lists name or description matches from all '
      'folders with folder paths, folders hidden, live', (t) async {
    await pump(t);
    await openSearch(t, 'cook');
    expect(resultTile('Kitchen talk'), findsOneWidget);
    expect(resultTile('Cooking club'), findsOneWidget);
    expect(find.text('Films / Podcasts'), findsOneWidget);
    expect(find.text('Top level'), findsOneWidget);
    expect(resultTile('Dark S1'), findsNothing);
    // folders are hidden while searching
    expect(find.text('Films'), findsNothing);
    // tag chips on the tile
    expect(
        find.descendant(
            of: resultTile('Kitchen talk'), matching: find.text('Food')),
        findsOneWidget);

    await t.enterText(find.byType(TextField), 'club');
    await t.pump();
    expect(resultTile('Kitchen talk'), findsNothing);
    expect(resultTile('Cooking club'), findsOneWidget);
  });

  testWidgets('AC-27: an empty collection is found by its name', (t) async {
    await pump(t);
    await openSearch(t, 'dark');
    expect(resultTile('Dark S1'), findsOneWidget);
  });

  testWidgets('AC-22: while searching no drag, and delete mode is not offered',
      (t) async {
    await pump(t);
    // before searching: the icons can be dragged
    expect(find.byType(DraggableCollectionIcon), findsWidgets);
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    expect(find.byType(DraggableCollectionIcon), findsNothing);
    await t.enterText(find.byType(TextField), 'cook');
    await t.pump();
    await t.pump();
    expect(find.byType(DraggableCollectionIcon), findsNothing);
    await t.longPress(resultTile('Kitchen talk'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(input.opened, isEmpty);

    await t.tap(find.byTooltip('Recycle bin'));
    await t.pumpAndSettle();
    expect(find.text('Go to recycle bin'), findsOneWidget);
    expect(find.text('Enable delete mode'), findsNothing);
  });

  testWidgets(
      'AC-24: nothing matches → "No collections match"; Clear filters brings '
      'back the open folder', (t) async {
    await pump(t);
    await t.tap(find.text('Films'));
    await t.pump();
    await t.pump();
    expect(find.text('Podcasts'), findsOneWidget);
    await openSearch(t, 'xyz');
    expect(find.text(CollectionsResultsView.emptyText), findsOneWidget);
    await t.tap(find.widgetWithText(
        FilledButton, CollectionsResultsView.clearFiltersText));
    await t.pump();
    await t.pump();
    expect(find.text('Podcasts'), findsOneWidget); // still in Films
    expect(find.text('Collections'), findsWidgets); // title back
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.byType(TextField)),
        findsNothing);
  });

  testWidgets(
      'Back from a search started here: the first Back clears, the second '
      'leaves', (t) async {
    await pump(t);
    await openSearch(t, 'cook');
    await back(t);
    expect(find.text('MAIN SCREEN'), findsNothing);
    expect(find.byType(CollectionResultTile), findsNothing);
    expect(find.text('Films'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    await back(t);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });

  testWidgets(
      'AC-14 / route-seeded: a topic tag opens results from all folders with '
      'a removable chip, topic only, My order', (t) async {
    await pump(t, tagKind: TagKind.topic, tag: 'Food');
    expect(resultTile('Kitchen talk'), findsOneWidget);
    // "Food" as an origin tag does not match a topic filter (AC-39)
    expect(resultTile('Food court'), findsNothing);
    expect(find.byType(CollectionResultTile), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Clear'), findsOneWidget);

    // removing the chip brings the folder view back
    // only the filter chip has a delete button; the tile's chips do not
    await t.tap(find.byTooltip('Delete'));
    await t.pump();
    await t.pump();
    expect(find.byType(CollectionResultTile), findsNothing);
    expect(find.text('Films'), findsOneWidget);
  });

  testWidgets('route-seeded origin tag filters by origin only', (t) async {
    await pump(t, tagKind: TagKind.origin, tag: 'Food');
    expect(resultTile('Food court'), findsOneWidget);
    expect(resultTile('Kitchen talk'), findsNothing);
  });

  testWidgets('AC-39: from a tag, Back returns straight to the main screen',
      (t) async {
    await pump(t, tagKind: TagKind.topic, tag: 'Food');
    await back(t);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });

  testWidgets(
      'AC-39: from a tag, Clear filters shows the folder Collections opens at',
      (t) async {
    await pump(t, tagKind: TagKind.topic, tag: 'Food');
    await t.tap(find.widgetWithText(TextButton, 'Clear'));
    await t.pump();
    await t.pump();
    expect(find.byType(CollectionResultTile), findsNothing);
    expect(find.text('Films'), findsOneWidget);
    expect(find.text('Up'), findsNothing); // the top level
    // nothing active any more: Back leaves
    await back(t);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });

  testWidgets('AC-39: from a tag, a tapped result opens it as current',
      (t) async {
    await pump(t, tagKind: TagKind.topic, tag: 'Food');
    await t.tap(resultTile('Kitchen talk'));
    await t.pumpAndSettle();
    expect(input.opened, ['k']);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });

  test('the route carries the tag in its query', () {
    final loc =
        const CollectionsRoute(tagKind: TagKind.topic, tag: 'Food').location;
    expect(loc, contains('tag=Food'));
    expect(loc, contains('topic'));
  });

  group('with the store (AC-23, AC-27)', () {
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('collections_search_test');
      store = await CollectionStore.open(directory: dir.path);
    });

    tearDown(() async {
      await store.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    Future<List<String>> search(CollectionFilter filter) async => [
          for (final s in searchCollections(
              await store.watchSummaries(debounce: Duration.zero).first, filter,
              now: DateTime.now()))
            s.name
        ];

    test('AC-23: a binned "Food" collection is neither filtered nor searched',
        () async {
      final binned = await store.create(name: 'Old food', topic: ['Food']);
      await store.create(name: 'Live food', topic: ['Food']);
      await store.setCurrentCollectionId(
          (await store.create(name: 'Current')).collectionId);
      expect((await store.bin(binned.collectionId)).result, BinResult.done);

      expect(await search(const CollectionFilter(topicTags: ['Food'])),
          ['Live food']);
      expect(
          await search(const CollectionFilter(query: 'food')), ['Live food']);
    });

    test('AC-27: an empty collection made with a tag is found', () async {
      await store.create(name: 'Dark S1', origin: ['Netflix']);
      expect(await search(const CollectionFilter(query: 'Dark')), ['Dark S1']);
    });
  });
}
