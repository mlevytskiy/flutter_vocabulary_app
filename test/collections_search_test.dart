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
import 'package:flutter_vocabulary_app/features/collections/collection_icon.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_results_view.dart';
import 'package:flutter_vocabulary_app/features/collections/match_outside_sheet.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

/// collection-tags T13 (SCR-05; AC-14, AC-19, AC-22, AC-23, AC-24, AC-27,
/// AC-39): search mode and the results of the Collections screen; since
/// collections-search (AC-01 – AC-08, AC-10) the list is the open folder's
/// level and Match outside holds the rest.

class _FakeInput extends WordsNotifier {
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
  String? folderId,
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
      folderId: folderId,
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
        folderId: 'f2',
        index: 0),
    _summary('c', 'Cooking club', path: 'Top level', index: 1),
    _summary('d', 'Dark S1',
        origin: ['Netflix'], path: 'Films', folderId: 'f1', index: 2),
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
        wordsNotifierProvider.overrideWith(() => input),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value([films, podcasts])),
        collectionLevelProvider(null).overrideWith((ref) => Stream.value([
              LevelItem.folder(films),
              LevelItem.collection(current),
            ])),
        collectionLevelProvider('f1').overrideWith((ref) => Stream.value([
              LevelItem.folder(podcasts),
            ])),
        collectionLevelProvider('f2')
            .overrideWith((ref) => Stream.value(<LevelItem>[])),
        collectionSummariesProvider
            .overrideWith((ref) => Stream.value(summaries)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/words/c', routes: [
          GoRoute(
            path: '/words',
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

  /// The system Back (while searching the bar's leading is ← Close search).
  Future<void> openSearchText(WidgetTester t, String query) async {
    await t.enterText(find.byType(TextField), query);
    await t.pump();
    await t.pump();
  }

  Future<void> back(WidgetTester t) async {
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
  }

  Finder resultTile(String name) =>
      find.widgetWithText(CollectionResultTile, name);

  Finder routeCollection(String id) => find.byKey(Key('route-collection-$id'));

  Future<void> openSheet(WidgetTester t) async {
    await t.tap(find.byKey(const Key('match-outside-header')));
    await t.pumpAndSettle();
  }

  testWidgets(
      'collections-search AC-01: outside search only the search icon; the '
      'filter comes with the field', (t) async {
    await pump(t);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsNothing);
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets(
      'owner 2026-10-18: ← Close search ends the search and brings the folder '
      'view back', (t) async {
    await pump(t);
    await openSearch(t, 'cook');
    expect(resultTile('Cooking club'), findsOneWidget);
    await t.tap(find.byTooltip('Close search'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Close search'), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Films'), findsOneWidget); // the folder view
    expect(find.text('MAIN SCREEN'), findsNothing); // did not leave the screen
  });

  testWidgets(
      'owner 2026-10-18: ✕ shows only with text and clears the text, the '
      'field stays', (t) async {
    await pump(t);
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    expect(find.byTooltip('Clear text'), findsNothing);
    await openSearchText(t, 'cook');
    expect(find.byTooltip('Clear text'), findsOneWidget);
    await t.tap(find.byTooltip('Clear text'));
    await t.pump();
    await t.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.byTooltip('Clear text'), findsNothing);
    expect(resultTile('Cooking club'), findsNothing);
    expect(find.text('Films'), findsOneWidget);
  });

  testWidgets(
      'owner 2026-10-18: opening search does not move the icons', (t) async {
    await pump(t);
    final icon = find.widgetWithText(CollectionIcon, 'Films');
    final before = t.getRect(icon);
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    expect(t.getRect(icon), before);
  });

  testWidgets('AC-01: a filter from a tag tap shows the filter icon too',
      (t) async {
    await pump(t, tagKind: TagKind.topic, tag: 'Food');
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('AC-02: the hint says where the search looks', (t) async {
    await pump(t);
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    expect(find.text('Search collections'), findsOneWidget);
    await back(t);
    await t.tap(find.text('Films'));
    await t.pump();
    await t.pump();
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    expect(find.text('Search in Films'), findsOneWidget);
  });

  testWidgets(
      'AC-03/AC-05: the list is this level; deeper matches peek in Match '
      'outside and the round buttons hide', (t) async {
    await pump(t);
    expect(find.byTooltip('Settings'), findsOneWidget);
    await openSearch(t, 'cook');
    expect(resultTile('Cooking club'), findsOneWidget);
    expect(resultTile('Kitchen talk'), findsNothing);
    expect(find.text(MatchOutsideSheet.title), findsOneWidget);
    expect(find.text('1 deeper'), findsOneWidget);
    expect(find.text('Show route'), findsOneWidget); // peeking
    expect(find.byTooltip('Settings'), findsNothing);
    await openSheet(t);
    expect(routeCollection('k'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
  });

  testWidgets('AC-05: nothing outside, no sheet', (t) async {
    await pump(t);
    await openSearch(t, 'club');
    expect(resultTile('Cooking club'), findsOneWidget);
    expect(find.text(MatchOutsideSheet.title), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets(
      'AC-03/AC-04: a folder directly here whose name matches is a result; '
      'a tap opens it and keeps the query', (t) async {
    await pump(t);
    await openSearch(t, 'film');
    expect(find.byKey(const Key('folder-result-f1')), findsOneWidget);
    await t.tap(find.byKey(const Key('folder-result-f1')));
    await t.pump();
    await t.pump();
    expect(find.text('Search in Films'), findsOneWidget);
    expect(find.text('film'), findsOneWidget); // the query stays
  });

  testWidgets(
      'AC-06/AC-07: inside Films the route marks "You are here", and a tap '
      'on Collections opens the top level with the query', (t) async {
    await pump(t);
    await t.tap(find.text('Films'));
    await t.pump();
    await t.pump();
    await openSearch(t, 'o'); // here: the Podcasts folder; outside: more
    expect(find.byKey(const Key('folder-result-f2')), findsOneWidget);
    await openSheet(t);
    expect(find.text(MatchOutsideSheet.hereText), findsOneWidget);
    expect(routeCollection('k'), findsOneWidget); // deeper, under Films
    expect(routeCollection('c'), findsOneWidget); // elsewhere
    await t.tap(find.byKey(const Key('route-root')));
    await t.pumpAndSettle();
    expect(find.text('Search collections'), findsOneWidget);
    expect(resultTile('Cooking club'), findsOneWidget);
  });

  testWidgets(
      'AC-08: nothing in the folder or below → the list says so and the sheet '
      'opens by itself', (t) async {
    await pump(t);
    await t.tap(find.text('Films'));
    await t.pump();
    await t.pump();
    await openSearch(t, 'club');
    await t.pumpAndSettle();
    expect(find.text('Nothing in Films or its subfolders matches'),
        findsOneWidget);
    expect(find.text('1 found elsewhere, shown below'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget); // opened
    expect(t.getRect(routeCollection('c')).top,
        lessThan(t.getSize(find.byType(Scaffold)).height * 0.75));
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
    // here: by name; deeper, in Match outside: by description
    expect(resultTile('Cooking club'), findsOneWidget);
    await openSheet(t);
    expect(routeCollection('k'), findsOneWidget);
    expect(find.text('Films / Podcasts'), findsOneWidget); // its place chip
    expect(routeCollection('d'), findsNothing);
    // the folder view is gone while searching
    expect(find.byType(DraggableCollectionIcon), findsNothing);

    await t.enterText(find.byType(TextField), 'club');
    await t.pump();
    expect(routeCollection('k'), findsNothing);
    expect(resultTile('Cooking club'), findsOneWidget);
  });

  testWidgets('AC-27: an empty collection is found by its name', (t) async {
    await pump(t);
    await openSearch(t, 'dark');
    await t.pumpAndSettle(); // nothing at the top: the sheet opens itself
    expect(routeCollection('d'), findsOneWidget);
  });

  testWidgets('AC-22: while searching no drag, and delete mode is not offered',
      (t) async {
    await pump(t);
    // before searching: the icons can be dragged
    expect(find.byType(DraggableCollectionIcon), findsWidgets);
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    expect(find.byType(DraggableCollectionIcon), findsNothing);
    await t.enterText(find.byType(TextField), 'club');
    await t.pump();
    await t.pump();
    expect(find.byType(DraggableCollectionIcon), findsNothing);
    await t.longPress(resultTile('Cooking club'));
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
    await t.pumpAndSettle();
    // Kitchen talk is in Films / Podcasts: deeper, so the sheet opened
    expect(routeCollection('k'), findsOneWidget);
    expect(
        find.text('Nothing directly in the top level matches'), findsOneWidget);
    // "Food" as an origin tag does not match a topic filter (AC-39)
    expect(resultTile('Food court'), findsNothing);
    expect(find.byType(CollectionResultTile), findsNothing);
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
    expect(find.byTooltip('Up'), findsNothing); // the top level
    // nothing active any more: Back leaves
    await back(t);
    expect(find.text('MAIN SCREEN'), findsOneWidget);
  });

  testWidgets('AC-39: from a tag, a tapped result opens it as current',
      (t) async {
    await pump(t, tagKind: TagKind.topic, tag: 'Food');
    await t.pumpAndSettle();
    await t.tap(routeCollection('k'));
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
