import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/collection_folder.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_level.dart';
import 'package:flutter_vocabulary_app/core/services/collection_search.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_filter_sheet.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_results_view.dart';
import 'package:flutter_vocabulary_app/features/collections/filter_tag_field.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

/// collection-tags T14 (SCR-06, SCR-07; AC-20, AC-20b, AC-21, AC-37, AC-38):
/// the Collections filter sheet, in the Pills layout (filter-sheet-pills).

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  final five = [
    ...few,
    _s('d', 'D', origin: ['Film'], topic: ['Travel'], index: 3),
  ];

  Future<void> pickFromMenu(WidgetTester t, Key pill, String item) async {
    await t.tap(find.byKey(pill));
    await t.pumpAndSettle();
    await t.tap(find
        .ancestor(
            of: find.text(item).last,
            matching: find.byWidgetPredicate((w) => w is PopupMenuEntry))
        .first);
    await t.pumpAndSettle();
  }

  testWidgets('one tag field: suggestions by word start with kind and count',
      (t) async {
    await open(t, few);
    expect(find.text('Show 3 collections'), findsOneWidget);
    await t.enterText(find.byKey(FilterTagField.inputKey), 'se');
    await t.pump();
    expect(find.byKey(FilterTagField.optionKey(TagKind.origin, 'Series')),
        findsOneWidget);
    expect(find.text('origin · 2'), findsOneWidget);
    await t.enterText(find.byKey(FilterTagField.inputKey), 'idi');
    await t.pump();
    expect(find.text('topic · 1'), findsOneWidget);
    await t.enterText(find.byKey(FilterTagField.inputKey), 'oms');
    await t.pump();
    expect(find.text('No tag starts with “oms”'), findsOneWidget);
  });

  testWidgets(
      'picking a tag adds its chip, counts follow the draft, a 0 option is '
      'disabled (collections-search AC-09)', (t) async {
    await open(t, few);
    await t.enterText(find.byKey(FilterTagField.inputKey), 'ser');
    await t.pump();
    await t.tap(find.byKey(FilterTagField.optionKey(TagKind.origin, 'Series')));
    await t.pump();
    expect(find.byKey(const ValueKey('filter-picked-origin-Series')),
        findsOneWidget);
    expect(find.text('Show 2 collections'), findsOneWidget);
    await t.enterText(find.byKey(FilterTagField.inputKey), 'bo');
    await t.pump();
    final book = t.widget<ListTile>(
        find.byKey(FilterTagField.optionKey(TagKind.origin, 'Book')));
    expect(book.enabled, isFalse);
    // Enter picks the first enabled option.
    await t.enterText(find.byKey(FilterTagField.inputKey), 'f');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(
        find.byKey(const ValueKey('filter-picked-topic-Food')), findsOneWidget);
    // The chip's delete button unpicks it.
    await t.tap(find.descendant(
        of: find.byKey(const ValueKey('filter-picked-origin-Series')),
        matching: find.byIcon(Icons.clear)));
    await t.pump();
    expect(find.text('Show 2 collections'), findsOneWidget);
  });

  testWidgets('Popular: hidden with 4 tags or fewer', (t) async {
    await open(t, few);
    expect(find.text('Popular'), findsNothing);
  });

  testWidgets('Popular: 4 most used without recent searches; a tap picks',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    await open(t, five);
    expect(find.text('Popular'), findsOneWidget);
    for (final q in [
      (TagKind.origin, 'Series'),
      (TagKind.topic, 'Food'),
      (TagKind.origin, 'Book'),
      (TagKind.origin, 'Film'),
    ]) {
      expect(find.byKey(CollectionsFilterSheet.quickKey(q.$1, q.$2)),
          findsOneWidget);
    }
    await t.tap(
        find.byKey(CollectionsFilterSheet.quickKey(TagKind.origin, 'Series')));
    await t.pump();
    expect(find.text('Show 2 collections'), findsOneWidget);
  });

  testWidgets('Popular: 2 recent searches then 2 most used', (t) async {
    SharedPreferences.setMockInitialValues({
      RecentFilterTagsNotifier.prefsKey: ['topic|travel', 'topic|Idioms'],
    });
    await open(t, five);
    await t.pumpAndSettle();
    for (final q in [
      (TagKind.topic, 'Travel'),
      (TagKind.topic, 'Idioms'),
      (TagKind.origin, 'Series'),
      (TagKind.topic, 'Food'),
    ]) {
      expect(find.byKey(CollectionsFilterSheet.quickKey(q.$1, q.$2)),
          findsOneWidget);
    }
    expect(find.byKey(CollectionsFilterSheet.quickKey(TagKind.origin, 'Book')),
        findsNothing);
  });

  testWidgets('live N of 0 still applies', (t) async {
    await open(t, few, current: const CollectionFilter(query: 'zzz'));
    expect(find.text('Show 0 collections'), findsOneWidget);
    await t.tap(find.text('Show 0 collections'));
    await t.pumpAndSettle();
    expect(result!.query, 'zzz');
  });

  testWidgets('date pills and the Sort pill apply', (t) async {
    await open(t, few);
    expect(find.text('Sort: My order'), findsOneWidget);
    await pickFromMenu(t, CollectionsFilterSheet.dateKey(true), 'Last 7 days');
    expect(find.text('Last 7 days'), findsOneWidget);
    await pickFromMenu(t, CollectionsFilterSheet.sortKey, 'Name A–Z');
    expect(find.text('Sort: Name A–Z'), findsOneWidget);
    await t.tap(find.textContaining('Show '));
    await t.pumpAndSettle();
    expect(result!.created, DateChoice.last7Days);
    expect(result!.edited, DateChoice.any);
    expect(result!.sort, CollectionSort.nameAZ);
  });

  testWidgets('Reset clears the draft but keeps the query', (t) async {
    await open(t, few,
        current: const CollectionFilter(query: 'x', originTags: ['Series']));
    await pickFromMenu(t, CollectionsFilterSheet.dateKey(true), 'Last 7 days');
    await pickFromMenu(t, CollectionsFilterSheet.sortKey, 'Name A–Z');
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
    await pickFromMenu(t, CollectionsFilterSheet.dateKey(true), 'This year');
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(opened, isTrue);
    expect(result, isNull);
  });

  testWidgets('custom range: label on the pill, same day is fine', (t) async {
    var next =
        DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 5));
    await open(t, few, pick: (_, __) async => next);
    await pickFromMenu(
        t, CollectionsFilterSheet.dateKey(true), 'Custom range…');
    expect(find.text('1 Oct – 5 Oct'), findsOneWidget);

    expect(rangeProblem(DateTime(2026, 10, 6), DateTime(2026, 10, 5)),
        rangeProblemMessage);
    next =
        DateTimeRange(start: DateTime(2026, 10, 7), end: DateTime(2026, 10, 7));
    await pickFromMenu(
        t, CollectionsFilterSheet.dateKey(false), 'Custom range…');
    expect(find.text(rangeProblemMessage), findsNothing);
    expect(find.text('7 Oct – 7 Oct'), findsOneWidget);

    await t.tap(find.textContaining('Show '));
    await t.pumpAndSettle();
    expect(result!.created.isCustom, isTrue);
    expect(result!.edited.isCustom, isTrue);
  });

  testWidgets('a refused range shows the message and is not applied',
      (t) async {
    await open(t, few, pick: (_, __) async => _BadRange());
    await pickFromMenu(
        t, CollectionsFilterSheet.dateKey(true), 'Custom range…');
    expect(find.text(rangeProblemMessage), findsOneWidget);
    expect(find.text('Any time'), findsNWidgets(2));
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
    await t.enterText(find.byKey(FilterTagField.inputKey), 'ser');
    await t.pump();
    await t.tap(find.byKey(FilterTagField.optionKey(TagKind.origin, 'Series')));
    await t.pump();
    await t.tap(find.text('Show 2 collections'));
    await t.pumpAndSettle();
    expect(find.byType(CollectionResultTile), findsNWidgets(2));
    expect(find.widgetWithText(InputChip, 'Series'), findsWidgets);
    // The applied tag is remembered for the Popular line.
    final scope = t.element(find.byType(CollectionResultTile).first);
    expect(ProviderScope.containerOf(scope).read(recentFilterTagsProvider),
        [(kind: TagKind.origin, text: 'Series')]);
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
