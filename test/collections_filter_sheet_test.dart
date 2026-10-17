import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_filter_sheet.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_results_view.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

/// collection-tags T14 (SCR-06, SCR-07; AC-20, AC-20b, AC-21, AC-37, AC-38):
/// the Collections filter sheet.

CollectionSummary _s(
  String id,
  String name, {
  List<String> origin = const [],
  List<String> topic = const [],
  int index = 0,
  DateTime? created,
}) =>
    CollectionSummary(
      id: id,
      name: name,
      description: '',
      originTags: origin,
      topicTags: topic,
      sourceOriginKeys: const {},
      sourceTopicKeys: const {},
      folderPath: 'Top level',
      treeIndex: index,
      created: created ?? DateTime.now(),
      edited: DateTime.now(),
    );

class _FakeInput extends WordInputNotifier {
  @override
  Future<WordCollection> build() async => WordCollection.create()
    ..name = 'Cur'
    ..words = [WordPair(word: 'a', translation: 'b')];
}

void main() {
  final many = [
    for (var i = 0; i < 14; i++)
      _s('m$i', 'Coll $i', topic: ['topic$i'], index: i),
  ];
  final few = [
    _s('a', 'A', origin: ['Series'], topic: ['Food'], index: 0),
    _s('b', 'B', origin: ['Series'], topic: ['Food', 'Idioms'], index: 1),
    _s('c', 'C', origin: ['Book'], index: 2),
  ];

  CollectionFilter? result;
  var opened = false;

  Future<void> open(
    WidgetTester t,
    List<CollectionSummary> summaries, {
    CollectionFilter current = const CollectionFilter(),
    DateRangePicker? pick,
  }) async {
    result = null;
    opened = false;
    await t.pumpWidget(ProviderScope(
      overrides: [
        collectionSummariesProvider
            .overrideWith((ref) => Stream.value(summaries)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCollectionsFilterSheet(context,
                    current: current, pickRange: pick);
                opened = true;
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

  testWidgets('counts, Show all and narrowing', (t) async {
    await open(t, few);
    expect(find.text('Series 2'), findsOneWidget);
    expect(find.text('Book 1'), findsOneWidget);
    expect(find.text('Food 2'), findsOneWidget);
    expect(find.text('Show 3 collections'), findsOneWidget);

    await t.enterText(find.byKey(const Key('narrow-topic')), 'idi');
    await t.pump();
    expect(find.text('Idioms 1'), findsOneWidget);
    expect(find.text('Food 2'), findsNothing);
  });

  testWidgets('first 12 then Show all', (t) async {
    await open(t, many);
    expect(find.byType(FilterChip), findsNWidgets(12));
    await t.ensureVisible(find.text('Show all'));
    await t.tap(find.text('Show all'));
    await t.pump();
    expect(find.byType(FilterChip), findsNWidgets(14));
    expect(find.text('No tags yet'), findsOneWidget); // origin
  });

  testWidgets(
      'collections-search AC-09: counts follow the draft, a 0 chip is '
      'disabled, the order stays', (t) async {
    await open(t, few);
    await t.tap(find.text('Series 2'));
    await t.pump();
    expect(find.text('Show 2 collections'), findsOneWidget);
    expect(find.text('Series 2'), findsOneWidget);
    expect(find.text('Book 0'), findsOneWidget);
    expect(
        t
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Book 0'))
            .onSelected,
        isNull);
    expect(find.text('Food 2'), findsOneWidget);
    expect(find.text('Idioms 1'), findsOneWidget);
    await t.tap(find.text('Idioms 1'));
    await t.pump();
    expect(find.text('Food 1'), findsOneWidget);
    expect(find.text('Show 1 collections'), findsOneWidget);
    // a picked chip stays enabled even at 0
    final chips = t.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    expect(chips.where((c) => c.selected).every((c) => c.onSelected != null),
        isTrue);
  });

  testWidgets('live N of 0 still applies', (t) async {
    await open(t, few, current: const CollectionFilter(query: 'zzz'));
    expect(find.text('Show 0 collections'), findsOneWidget);
    await t.tap(find.text('Show 0 collections'));
    await t.pumpAndSettle();
    expect(result!.query, 'zzz');
  });

  testWidgets('Reset clears the draft but keeps the query', (t) async {
    await open(t, few,
        current: const CollectionFilter(query: 'x', originTags: ['Series']));
    await t.tap(find.text('Last 7 days').first);
    await t.tap(find.text('Name A–Z'));
    await t.pump();
    await t.tap(find.text('Reset'));
    await t.pump();
    await t.tap(find.textContaining('Show '));
    await t.pumpAndSettle();
    expect(result!.originTags, isEmpty);
    expect(result!.created, DateChoice.any);
    expect(result!.sort, CollectionSort.myOrder);
    expect(result!.query, 'x');
  });

  testWidgets('dismiss without the button changes nothing', (t) async {
    await open(t, few);
    await t.tap(find.text('Series 2'));
    await t.pump();
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(opened, isTrue);
    expect(result, isNull);
  });

  testWidgets('custom range: label, and start after end is refused', (t) async {
    var next =
        DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 5));
    await open(t, few, pick: (_, __) async => next);
    await t.tap(find.text('Custom range…').first);
    await t.pump();
    expect(find.text('1 Oct – 5 Oct'), findsOneWidget);

    // DateTimeRange itself forbids start > end, so test the guard directly
    // and through a picker that returns an equal-day range.
    expect(rangeProblem(DateTime(2026, 10, 6), DateTime(2026, 10, 5)),
        rangeProblemMessage);
    next =
        DateTimeRange(start: DateTime(2026, 10, 7), end: DateTime(2026, 10, 7));
    await t.ensureVisible(find.text('Custom range…'));
    await t.tap(find.text('Custom range…')); // Edited row
    await t.pump();
    expect(find.text(rangeProblemMessage), findsNothing);
    expect(find.text('7 Oct – 7 Oct'), findsOneWidget);

    await t.ensureVisible(find.textContaining('Show '));
    await t.tap(find.textContaining('Show '));
    await t.pumpAndSettle();
    expect(result!.created.isCustom, isTrue);
    expect(result!.edited.isCustom, isTrue);
  });

  testWidgets('a refused range shows the SnackBar and is not applied',
      (t) async {
    // A picker that bypasses DateTimeRange's own assert is impossible, so
    // use a subclass-free fake: start after end via a mutable subclass.
    await open(t, few, pick: (_, __) async => _BadRange());
    await t.tap(find.text('Custom range…').first);
    await t.pump();
    expect(find.text(rangeProblemMessage), findsWidgets);
    expect(find.text('Custom range…'), findsNWidgets(2));
  });

  testWidgets('apply shows the chips on the results', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        wordInputNotifierProvider.overrideWith(() => _FakeInput()),
        collectionFoldersProvider
            .overrideWith((ref) => Stream.value(<CollectionFolder>[])),
        collectionLevelProvider(null)
            .overrideWith((ref) => Stream.value(<LevelItem>[])),
        collectionSummariesProvider.overrideWith((ref) => Stream.value(few)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/c', routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Text('MAIN'),
            routes: [
              GoRoute(
                path: 'c',
                builder: (context, state) =>
                    const CollectionsRoute().build(context, state),
              ),
            ],
          ),
        ]),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1));
    // the filter belongs to search (collections-search AC-01)
    await t.tap(find.byIcon(Icons.search));
    await t.pump();
    await t.tap(find.byIcon(Icons.tune));
    await t.pumpAndSettle();
    await t.tap(find.text('Series 2'));
    await t.pump();
    await t.tap(find.text('Show 2 collections'));
    await t.pumpAndSettle();
    expect(find.byType(CollectionResultTile), findsNWidgets(2));
    expect(find.widgetWithText(InputChip, 'Series'), findsWidgets);
  });
}

class _BadRange implements DateTimeRange {
  @override
  DateTime get start => DateTime(2026, 10, 6);
  @override
  DateTime get end => DateTime(2026, 10, 5);
  @override
  Duration get duration => Duration.zero;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
