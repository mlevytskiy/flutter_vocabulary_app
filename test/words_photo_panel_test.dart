import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/words/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/words/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

import 'photo_preview_test.dart' show MapSourcePhotoStore;

/// words-photo-panel: the Words screen has the main screen's photo tab and
/// panel, for the collection it shows, the current one or a History one.
void main() {
  SessionSource photo(String id, int minute) => SessionSource()
    ..id = id
    ..fileName = '$id.jpg'
    ..takenAt = DateTime(2026, 10, 16, 9, minute);

  /// p1's rows are 0, 1 and 3; row 1 has no translation, so the table does
  /// not list it: p1's table rows are 0 and 2. p2's only row is table row 1.
  WordCollection current() => WordCollection.create()
    ..words = [
      WordPair(word: 'claim', translation: 'заява', sourceId: 'p1'),
      WordPair(word: 'orphan', sourceId: 'p1'),
      WordPair(word: 'curse', translation: 'прокляття', sourceId: 'p2'),
      WordPair(word: 'gated', translation: 'з воротами', sourceId: 'p1'),
    ]
    ..sources = [photo('p1', 1), photo('p2', 2)];

  WordCollection past() => WordCollection.create()
    ..words = [
      WordPair(word: 'tea', translation: 'чай', sourceId: 'h1'),
      WordPair(word: 'milk', translation: 'молоко', sourceId: 'h2'),
    ]
    ..sources = [photo('h1', 1), photo('h2', 2)];

  late GoRouter router;

  Future<void> pumpWords(WidgetTester tester,
      {required WordCollection main,
      WordCollection? shown,
      bool startOnMain = false}) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      wordsProvider.overrideWith(() => _FakeWords(main)),
      if (shown != null)
        collectionByIdProvider(shown.collectionId)
            .overrideWith((ref) async => shown),
      sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({})),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(wordsProvider.future);
      if (shown != null) {
        await container.read(collectionByIdProvider(shown.collectionId).future);
      }
    });
    router = GoRouter(
      initialLocation: startOnMain
          ? '/'
          : shown == null
          ? '/table'
          : '/table?collection-id=${shown.collectionId}',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('main')),
          routes: [
            GoRoute(
              path: 'table',
              builder: (context, state) => WordsTableScreen(
                  collectionId: state.uri.queryParameters['collection-id']),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  PhotoPanel panel(WidgetTester tester) =>
      tester.widget<PhotoPanel>(find.byType(PhotoPanel, skipOffstage: false));

  Set<int> highlighted(WidgetTester tester) => {
        for (final (index, row)
            in tester.widget<DataTable>(find.byType(DataTable)).rows.indexed)
          if (row.color != null) index,
      };

  Future<void> openHalf(WidgetTester tester) async {
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    expect(panel(tester).controller.stop, PanelStop.halfOpen);
  }

  testWidgets('the current collection: the tab, the table stays while open, '
      'a photo highlights its rows', (tester) async {
    await pumpWords(tester, main: current());
    expect(find.byKey(PhotoPanel.tabKey), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);

    await openHalf(tester);
    expect(find.byType(DataTable), findsOneWidget,
        reason: 'the table keeps its layout (owner, 2026-10-19)');
    expect(find.text('claim'), findsOneWidget);
    expect(find.text('заява'), findsOneWidget);
    expect(highlighted(tester), isEmpty);

    // p1's rows in the table are 0 and 2 (its row with no translation is
    // not in the table).
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();
    expect(panel(tester).controller.selectedId, 'p1');
    expect(highlighted(tester), {0, 2});

    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p2')));
    await tester.pumpAndSettle();
    expect(highlighted(tester), {1});

    await tester.tap(find.byKey(PhotoPanel.closeKey));
    await tester.pumpAndSettle();
    expect(panel(tester).controller.stop, PanelStop.closed);
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('selecting a source scrolls its first row to the top',
      (tester) async {
    final long = WordCollection.create()
      ..words = [
        for (var i = 0; i < 40; i++)
          WordPair(
              word: 'word$i',
              translation: 'слово$i',
              sourceId: i == 0 ? 'p1' : (i >= 20 && i < 22 ? 'p2' : null)),
      ]
      ..sources = [photo('p1', 1), photo('p2', 2)];
    await pumpWords(tester, main: long);
    await openHalf(tester);
    final scroll = find
        .ancestor(of: find.byType(DataTable), matching: find.byType(Scrollable))
        .first;
    final top = tester.getRect(scroll).top;
    final word20 = find.text('word20');
    expect(tester.getTopLeft(word20).dy,
        greaterThan(tester.getRect(scroll).bottom),
        reason: 'far below the screen');

    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p2')));
    await tester.pumpAndSettle();
    final table = tester.renderObject<RenderTable>(find.descendant(
        of: find.byType(DataTable), matching: find.byType(Table)));
    final rowTop = table
        .localToGlobal(table.getRowBox(21).topLeft) // 0 is the heading
        .dy;
    expect(rowTop, closeTo(top, 1),
        reason: "p2's first row at the top of the table");
    expect(highlighted(tester), {20, 21});
  });

  testWidgets('the tab stays where it stands while the Words screen slides '
      'in and out (owner, 2026-10-19)', (tester) async {
    await pumpWords(tester, main: current(), startOnMain: true);
    router.push('/table');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    final tab = find.byKey(PhotoPanel.tabKey);
    expect(tab, findsOneWidget, reason: 'on screen from the first frame');
    final during = <Rect>[tester.getRect(tab)];
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      during.add(tester.getRect(tab));
    }
    await tester.pumpAndSettle();
    final settled = tester.getRect(tab);
    for (final rect in during) {
      expect(rect, settled);
    }

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byKey(PhotoPanel.tabKey)), settled,
        reason: 'the leaving screen keeps it in place');
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the current collection opens Notes from the panel',
      (tester) async {
    await pumpWords(tester, main: current());
    expect(panel(tester).onOpenNotes, isNotNull);
    expect(panel(tester).notesPage, isNotNull);
    expect(panel(tester).collectionId, isNull);
  });

  testWidgets('a History collection: its own photos, no Notes, expand is '
      'full-open', (tester) async {
    final shown = past();
    await pumpWords(tester, main: current(), shown: shown);
    expect(panel(tester).collectionId, shown.collectionId);
    expect(panel(tester).onOpenNotes, isNull,
        reason: 'Notes edits the current collection only');

    await openHalf(tester);
    expect(find.byKey(PhotoPanel.smallPhotoKey('h1')), findsOneWidget);
    expect(find.byKey(PhotoPanel.smallPhotoKey('h2')), findsOneWidget);
    expect(find.byKey(PhotoPanel.smallPhotoKey('p1')), findsNothing,
        reason: "the current collection's photos are not listed");

    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('h2')));
    await tester.pumpAndSettle();
    expect(highlighted(tester), {1});

    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(panel(tester).controller.stop, PanelStop.fullOpen);
  });

  testWidgets('Back steps the open panel back and stays on the Words screen',
      (tester) async {
    await pumpWords(tester, main: current());
    await openHalf(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(panel(tester).controller.stop, PanelStop.closed);
    expect(find.byType(WordsTableScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WordsTableScreen), findsNothing,
        reason: 'closed, Back leaves as before');
  });

  testWidgets('while the panel is open a tap on the top bar only closes it',
      (tester) async {
    await pumpWords(tester, main: current());
    await openHalf(tester);
    await tester.tap(find.text('Words'));
    await tester.pumpAndSettle();
    expect(panel(tester).controller.stop, PanelStop.closed);
    expect(find.byType(WordsTableScreen), findsOneWidget);
  });
}

class _FakeWords extends WordsNotifier {
  _FakeWords(this._current);

  final WordCollection _current;

  @override
  Future<WordCollection> build() async => _current;
}
