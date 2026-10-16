import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_morph.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
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
      {required WordCollection main, WordCollection? shown}) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeWordInput(main)),
      if (shown != null)
        collectionByIdProvider(shown.collectionId)
            .overrideWith((ref) async => shown),
      sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({})),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(wordInputNotifierProvider.future);
      if (shown != null) {
        await container.read(collectionByIdProvider(shown.collectionId).future);
      }
    });
    router = GoRouter(
      initialLocation: shown == null
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
        for (final line
            in tester.widgetList<CompactWordLine>(find.byType(CompactWordLine)))
          if (line.highlight != null) line.index,
      };

  Future<void> openHalf(WidgetTester tester) async {
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    expect(panel(tester).controller.stop, PanelStop.halfOpen);
  }

  testWidgets('the current collection: the tab, one-line rows while open, '
      'a photo highlights its rows, closed the table is back', (tester) async {
    await pumpWords(tester, main: current());
    expect(find.byKey(PhotoPanel.tabKey), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(CompactWordLine), findsNothing);

    await openHalf(tester);
    final lines = [
      for (final line
          in tester.widgetList<CompactWordLine>(find.byType(CompactWordLine)))
        line.text,
    ];
    expect(lines, ['claim — заява', 'curse — прокляття', 'gated — з воротами']);
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
    expect(find.byType(CompactWordLine), findsNothing);
    expect(find.text('claim'), findsOneWidget, reason: 'the table again');
  });

  testWidgets('selecting a source scrolls its first row to the top',
      (tester) async {
    final long = WordCollection.create()
      ..words = [
        for (var i = 0; i < 40; i++)
          WordPair(
              word: 'word$i',
              translation: 'слово$i',
              sourceId: i == 0 ? 'p1' : (i >= 30 ? 'p2' : null)),
      ]
      ..sources = [photo('p1', 1), photo('p2', 2)];
    await pumpWords(tester, main: long);
    await openHalf(tester);
    final line30 =
        find.byWidgetPredicate((w) => w is CompactWordLine && w.index == 30);
    expect(line30, findsNothing, reason: 'far below the screen');

    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p2')));
    await tester.pumpAndSettle();
    final list = tester.getRect(find.byType(ListView).first);
    expect(tester.getTopLeft(line30).dy, closeTo(list.top, 1),
        reason: "p2's first row at the top of the list");
  });

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

class _FakeWordInput extends WordInputNotifier {
  _FakeWordInput(this._current);

  final WordCollection _current;

  @override
  Future<WordCollection> build() async => _current;
}
