import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/edge_glass.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_item.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_morph.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

import 'photo_preview_test.dart' show MapSourcePhotoStore;

/// side-bar-for-main-screen T13/T14: the photo panel on the real main screen
/// (spec AC-02, AC-04, AC-05, AC-06, AC-10, AC-11, AC-15, AC-15b, AC-17).
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

  // One store for the file, never closed (see switch_session_test.dart).
  Directory? dir;
  late SessionStore store;
  late ProviderContainer container;
  tearDownAll(() {
    if (dir != null && dir!.existsSync()) dir!.deleteSync(recursive: true);
  });

  SessionSource photo(String id, int minute) => SessionSource()
    ..id = id
    ..fileName = '$id.jpg'
    ..takenAt = DateTime(2026, 10, 13, 9, minute);

  /// 20 rows: p1's rows are 3 and 15, p2's only row is 18; the rest typed.
  List<WordPair> twentyRows() => [
        for (var i = 0; i < 20; i++)
          WordPair(
            word: 'word$i',
            translation: 'слово$i',
            sourceId: switch (i) { 3 || 15 => 'p1', 18 => 'p2', _ => null },
          ),
      ];

  Future<void> ensureStore() async {
    if (dir != null) return;
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('main_screen_photo_panel_test');
    store = await SessionStore.open(directory: dir!.path);
  }

  Future<Session> pumpMain(WidgetTester tester,
      {List<WordPair>? words, bool photos = true, Session? otherSession}) async {
    SharedPreferences.setMockInitialValues({});
    late Session current;
    await tester.runAsync(() async {
      await ensureStore();
      final now = DateTime.now();
      current = Session.create()
        ..updatedAt = now
        ..lastLocalModifiedAt = now
        ..words = words ?? twentyRows()
        ..sources = photos ? [photo('p1', 1), photo('p2', 2)] : [];
      await store.put(current);
      await store.setCurrentSessionId(current.sessionId);
    });
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({})),
      if (otherSession != null)
        nonEmptySessionsProvider.overrideWith((ref) => Stream.value([current, otherSession])),
    ]);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    container.read(wordInputNotifierProvider.notifier).addAll([WordPair()]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return current;
  }

  Future<void> tearDownMain(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  PanelStop stop(WidgetTester tester) {
    final panel = tester.widget<PhotoPanel>(find.byType(PhotoPanel, skipOffstage: false));
    return panel.controller.stop;
  }

  String? selected(WidgetTester tester) =>
      tester.widget<PhotoPanel>(find.byType(PhotoPanel, skipOffstage: false)).controller.selectedId;

  /// Indices of the rows drawn with a highlight: while the panel is open
  /// each row is its one line, closed the full row.
  Set<int> highlighted(WidgetTester tester) => {
        for (final row in tester.widgetList<WordRowItem>(find.byType(WordRowItem)))
          if (row.highlight != null) row.index,
        for (final line in tester.widgetList<CompactWordLine>(find.byType(CompactWordLine)))
          if (line.highlight != null) line.index,
      };

  /// Row [index], a full row or its one line.
  Finder row(int index) =>
      find.byWidgetPredicate((w) => w is WordRowMorph && w.index == index);

  /// Row [index]'s one line, while the panel is open.
  Finder line(int index) =>
      find.byWidgetPredicate((w) => w is CompactWordLine && w.index == index);

  Rect listRect(WidgetTester tester) => tester.getRect(find.byType(ListView).first);

  ScrollPosition listPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  Future<void> openHalf(WidgetTester tester) async {
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.halfOpen);
  }

  testWidgets('a session with photos shows the tab; no row is highlighted', (tester) async {
    await pumpMain(tester);
    expect(find.byKey(PhotoPanel.tabKey), findsOneWidget);
    expect(highlighted(tester), isEmpty);
    await tearDownMain(tester);
  });

  testWidgets('open, every row is one line "word — translation"; closed, the rows are back',
      (tester) async {
    await pumpMain(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    expect(find.byType(CompactWordLine), findsNothing);

    await openHalf(tester);
    expect(find.byType(WordRowItem), findsNothing);
    expect(tester.widget<CompactWordLine>(line(0)).text, 'word0 — слово0');
    expect(tester.widget<CompactWordLine>(line(1)).text, 'word1 — слово1');
    expect(tester.getSize(row(1)).height, lessThan(64), reason: 'one line of text');

    await tester.tap(find.byKey(PhotoPanel.closeKey));
    await tester.pumpAndSettle();
    expect(find.byType(CompactWordLine), findsNothing);
    expect(
        find.descendant(
            of: find.byWidgetPredicate((w) => w is WordRowItem && w.index == 1),
            matching: find.byWidgetPredicate(
                (w) => w is TextField && w.controller?.text == 'word1')),
        findsOneWidget);
    await tearDownMain(tester);
  });

  testWidgets('the glass slides and is covered, never resized or refaded (Android cost)',
      (tester) async {
    await pumpMain(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    final glass = find.descendant(
        of: find.byKey(PhotoPanel.panelKey), matching: find.byType(EdgeGlass));
    final sizes = <(double, double)>{};
    final settings = <Object>{};
    void record() {
      if (!tester.any(glass)) return;
      final size = tester.getSize(glass);
      sizes.add((size.width, size.height));
      settings.add(tester.widget<EdgeGlass>(glass).settings);
    }

    await tester.tap(find.byKey(PhotoPanel.tabKey));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      record();
    }
    expect(stop(tester), PanelStop.halfOpen);
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      record();
    }
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.fullOpen);
    expect(sizes, hasLength(1), reason: 'one size all the way: $sizes');
    expect(settings, hasLength(1), reason: 'never faded through its settings');
    await tearDownMain(tester);
  });

  testWidgets('selecting a photo highlights all its rows and jumps to the first (AC-04)',
      (tester) async {
    await pumpMain(tester);
    await openHalf(tester);
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p2')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(selected(tester), 'p2');
    expect(highlighted(tester), {18});
    final rect = tester.getRect(row(18));
    expect(rect.top, greaterThanOrEqualTo(listRect(tester).top));
    expect(rect.bottom, lessThanOrEqualTo(listRect(tester).bottom));

    // Another photo moves the highlight; its first row (3) is far up again.
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();
    expect(highlighted(tester), containsAll([3]));
    expect(highlighted(tester).contains(18), isFalse);
    expect(tester.any(row(3)), isTrue);

    // The same photo again clears it and does not scroll (AC-05).
    final offset = listPosition(tester).pixels;
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();
    expect(selected(tester), isNull);
    expect(highlighted(tester), isEmpty);
    expect(listPosition(tester).pixels, offset);
    await tearDownMain(tester);
  });

  testWidgets('scrolling the list keeps half-open and the highlight (AC-06)', (tester) async {
    await pumpMain(tester);
    await openHalf(tester);
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();
    final before = listPosition(tester).pixels;
    await tester.dragFrom(listRect(tester).centerLeft.translate(40, 0), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(listPosition(tester).pixels, isNot(before));
    expect(stop(tester), PanelStop.halfOpen);
    expect(selected(tester), 'p1');
    await tearDownMain(tester);
  });

  testWidgets('Back steps full-open → half-open → closed, and leaves only when closed (AC-10)',
      (tester) async {
    await pumpMain(tester);
    await openHalf(tester);
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.fullOpen);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.halfOpen);
    expect(selected(tester), 'p1', reason: 'full-open → half-open keeps the highlight');

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.closed);
    expect(selected(tester), isNull);
    expect(highlighted(tester), isEmpty);
    expect(find.byType(WordInputScreen), findsOneWidget);

    // Closed: Back is no longer the panel's (the app may leave).
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tearDownMain(tester);
  });

  testWidgets('no photo with words: no tab and no Back interception (AC-02)', (tester) async {
    await pumpMain(tester, photos: false, words: [WordPair(word: 'typed')]);
    expect(find.byKey(PhotoPanel.tabKey), findsNothing);
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tearDownMain(tester);
  });

  testWidgets('clearing the selected photo\'s last row clears the selection (AC-15)',
      (tester) async {
    await pumpMain(tester);
    await openHalf(tester);
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p2')));
    await tester.pumpAndSettle();
    expect(selected(tester), 'p2');

    container.read(wordInputNotifierProvider.notifier).updateAt(18, word: '');
    await tester.pumpAndSettle();
    expect(selected(tester), isNull);
    expect(find.byKey(PhotoPanel.smallPhotoKey('p2')), findsNothing);
    expect(stop(tester), PanelStop.halfOpen);
    await tearDownMain(tester);
  });

  // T14: an open panel owns the main screen's touches (AC-11, AC-13, AC-15b).

  testWidgets('with the panel open a tap on a row only closes it: no focus, no delete (AC-11)',
      (tester) async {
    await pumpMain(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await openHalf(tester);
    final rows = container.read(wordInputNotifierProvider).value!.words.length;

    await tester.tap(line(1), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.closed);
    expect(FocusManager.instance.primaryFocus?.context?.widget is EditableText, isFalse);

    // The delete button sits at the row's right edge, under the half-open
    // panel: a tap there belongs to the panel and deletes nothing (AC-14).
    final delete = tester.getCenter(find
        .descendant(
            of: find.byWidgetPredicate((w) => w is WordRowItem && w.index == 1),
            matching: find.byIcon(Icons.close))
        .first);
    await openHalf(tester);
    await tester.tapAt(delete);
    await tester.pumpAndSettle();
    expect(container.read(wordInputNotifierProvider).value!.words.length, rows);

    // Another row's one line: only closes the panel.
    await tester.tap(line(2), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.closed);
    expect(FocusManager.instance.primaryFocus?.context?.widget is EditableText, isFalse);
    expect(container.read(wordInputNotifierProvider).value!.words.length, rows);
    await tearDownMain(tester);
  });

  testWidgets('with the panel open the top bar and the floating buttons only close it (AC-11)',
      (tester) async {
    await pumpMain(tester);
    await openHalf(tester);
    await tester.tap(find.text('Next'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.closed);
    expect(find.byType(WordInputScreen), findsOneWidget);
    expect(find.text('Next').hitTestable(), findsOneWidget, reason: 'still on the main screen');

    await openHalf(tester);
    await tester.tap(find.byTooltip('Settings'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.closed);
    expect(find.byTooltip('Settings').hitTestable(), findsOneWidget, reason: 'Settings not opened');
    await tearDownMain(tester);
  });

  testWidgets('the drawer does not open while the panel is open, and the tab hides behind it',
      (tester) async {
    await pumpMain(tester,
        otherSession: Session.create()..words = [WordPair(word: 'older')]);
    await tester.pump();
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffold.hasDrawer, isTrue);

    await openHalf(tester);
    await tester.dragFrom(const Offset(2, 300), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isFalse);
    expect(stop(tester), PanelStop.closed, reason: 'the edge swipe only closed the panel');

    scaffold.openDrawer();
    await tester.pumpAndSettle();
    expect(find.byKey(PhotoPanel.tabKey), findsNothing);
    scaffold.closeDrawer();
    await tester.pumpAndSettle();
    expect(find.byKey(PhotoPanel.tabKey), findsOneWidget);
    await tearDownMain(tester);
  });

  testWidgets('a new current session closes the panel and clears the selection (AC-15b)',
      (tester) async {
    late Session other;
    await tester.runAsync(() async {
      await ensureStore();
      other = Session.create()
        ..updatedAt = DateTime(2026, 9, 2)
        ..lastLocalModifiedAt = DateTime(2026, 9, 2)
        ..words = [WordPair(word: 'from', sourceId: 'q1')]
        ..sources = [photo('q1', 5)];
      await store.put(other);
    });
    await pumpMain(tester);
    await openHalf(tester);
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();

    await tester.runAsync(() =>
        container.read(wordInputNotifierProvider.notifier).switchTo(other.sessionId));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.closed);
    expect(selected(tester), isNull);
    // The tab now shows only the new session's photo (AC-16).
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PhotoPanel.smallPhotoKey('q1')), findsOneWidget);
    expect(find.byKey(PhotoPanel.smallPhotoKey('p1')), findsNothing);
    await tearDownMain(tester);
  });

  testWidgets('another route on top closes the panel first', (tester) async {
    await pumpMain(tester);
    await openHalf(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push(PageRouteBuilder<void>(pageBuilder: (_, __, ___) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.closed);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(PhotoPanel.tabKey).hitTestable(), findsOneWidget);
    await tearDownMain(tester);
  });

  testWidgets('background and back with the same session keeps the stop and the selection',
      (tester) async {
    await pumpMain(tester);
    await openHalf(tester);
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.halfOpen);
    expect(selected(tester), 'p1');
    await tearDownMain(tester);
  });
}
