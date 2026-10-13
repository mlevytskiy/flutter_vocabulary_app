import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/main_screen_pager.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

import 'photo_preview_test.dart' show MapSourcePhotoStore;

/// side-bar-for-main-screen T15: the photo tab on every page of the main
/// screen pager; the panel opens only over the words page (spec AC-13, sad §6
/// Flow 7).
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

  FilmDialogue dialogue(String id, String line, List<String> rowIds) =>
      FilmDialogue()
        ..id = id
        ..lines = [line]
        ..wordRowIds = rowIds;

  /// Two photos with words and two dialogues: three pages.
  Future<void> pumpMain(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      if (dir == null) {
        dir = Directory.systemTemp.createTempSync('photo_panel_pager_test');
        store = await SessionStore.open(directory: dir!.path);
      }
      final now = DateTime.now();
      final current = Session.create()
        ..updatedAt = now
        ..lastLocalModifiedAt = now
        ..words = [
          WordPair(word: 'fog', translation: 'туман', rowId: 'r1', sourceId: 'p1'),
          WordPair(word: 'attic', translation: 'горище', rowId: 'r2', sourceId: 'p2'),
          WordPair(word: 'dusty', translation: 'запорошений', rowId: 'r3'),
        ]
        ..sources = [photo('p1', 1), photo('p2', 2)]
        ..dialogues = [
          dialogue('d1', 'In the fog.', ['r1']),
          dialogue('d2', 'A dusty attic.', ['r2', 'r3']),
        ];
      await store.put(current);
      await store.setCurrentSessionId(current.sessionId);
    });
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({})),
    ]);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tearDownMain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  PanelStop stop(WidgetTester tester) => tester
      .widget<PhotoPanel>(find.byType(PhotoPanel, skipOffstage: false))
      .controller
      .stop;

  /// The pager's page (full-open has a PageView of its own for the photos).
  double page(WidgetTester tester) => tester
      .widget<PageView>(find.descendant(
          of: find.byType(MainScreenPager), matching: find.byType(PageView)))
      .controller!
      .page!;

  Rect tabRect(WidgetTester tester) =>
      tester.getRect(find.byKey(PhotoPanel.tabKey));

  /// A sideways swipe on the page, away from the tab.
  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.flingFrom(const Offset(150, 600), Offset(dx, 0), 2000);
    await tester.pumpAndSettle();
  }

  Future<void> toLastPage(WidgetTester tester) async {
    await swipe(tester, -250);
    await swipe(tester, -250);
    expect(page(tester), 2);
  }

  /// The pager runs back to the words page, and only then does the panel
  /// leave closed.
  Future<void> expectReturnsFirst(WidgetTester tester, PanelStop settled) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(page(tester), inExclusiveRange(0, 2), reason: 'the pager is moving');
    expect(stop(tester), PanelStop.closed, reason: 'opens after the pager');
    await tester.pumpAndSettle();
    expect(page(tester), 0);
    expect(stop(tester), settled);
  }

  testWidgets('a drag on the tab on the words page opens the panel and keeps the page',
      (tester) async {
    await pumpMain(tester);
    expect(page(tester), 0);
    await tester.drag(find.byKey(PhotoPanel.tabKey), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.halfOpen);
    expect(page(tester), 0);
    await tearDownMain(tester);
  });

  testWidgets('closed: a swipe away from the tab changes the page and the tab stays put',
      (tester) async {
    await pumpMain(tester);
    final before = tabRect(tester);
    await tester.timedDragFrom(const Offset(150, 600), const Offset(-120, 0),
        const Duration(milliseconds: 300));
    await tester.pump();
    expect(page(tester), greaterThan(0), reason: 'mid-swipe');
    expect(tabRect(tester), before, reason: 'the tab does not move with the page');
    await tester.pumpAndSettle();
    expect(page(tester), 1);
    expect(find.byKey(PhotoPanel.tabKey), findsOneWidget);
    expect(tabRect(tester), before);

    await swipe(tester, -250);
    expect(page(tester), 2);
    expect(tabRect(tester), before);
    await tearDownMain(tester);
  });

  testWidgets('a tap on the tab on a dialogue page returns to the words page, then opens',
      (tester) async {
    await pumpMain(tester);
    await toLastPage(tester);
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await expectReturnsFirst(tester, PanelStop.halfOpen);
    await tearDownMain(tester);
  });

  testWidgets('a fling on the tab on a dialogue page returns, then opens half-open',
      (tester) async {
    await pumpMain(tester);
    await toLastPage(tester);
    await tester.fling(find.byKey(PhotoPanel.tabKey), const Offset(-300, 0), 3000);
    await expectReturnsFirst(tester, PanelStop.halfOpen);
    await tearDownMain(tester);
  });

  testWidgets('a long slow drag on the tab on a dialogue page returns, then opens full-open',
      (tester) async {
    await pumpMain(tester);
    await toLastPage(tester);
    await tester.timedDrag(find.byKey(PhotoPanel.tabKey), const Offset(-320, 0),
        const Duration(seconds: 2));
    await expectReturnsFirst(tester, PanelStop.fullOpen);
    await tearDownMain(tester);
  });

  testWidgets('a short drag on the tab on a dialogue page returns, then opens half-open',
      (tester) async {
    await pumpMain(tester);
    await toLastPage(tester);
    await tester.drag(find.byKey(PhotoPanel.tabKey), const Offset(-60, 0));
    await expectReturnsFirst(tester, PanelStop.halfOpen);
    await tearDownMain(tester);
  });

  testWidgets('a screen-reader tap on the tab on a dialogue page returns, then opens',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpMain(tester);
    await toLastPage(tester);
    final node = tester.getSemantics(find.bySemanticsLabel('Session photos, 2'));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await expectReturnsFirst(tester, PanelStop.halfOpen);
    await tearDownMain(tester);
    handle.dispose();
  });

  testWidgets('open: no swipe changes the page', (tester) async {
    await pumpMain(tester);
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.halfOpen);

    await swipe(tester, -250);
    expect(page(tester), 0, reason: 'half-open: the pager does not swipe');

    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.fullOpen);
    await swipe(tester, -250);
    expect(page(tester), 0, reason: 'full-open: the pager does not swipe');
    await tearDownMain(tester);
  });
}
