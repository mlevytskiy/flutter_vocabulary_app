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
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_item.dart';
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

  Future<Session> pumpMain(WidgetTester tester, {List<WordPair>? words, bool photos = true}) async {
    SharedPreferences.setMockInitialValues({});
    late Session current;
    await tester.runAsync(() async {
      if (dir == null) {
        dir = Directory.systemTemp.createTempSync('main_screen_photo_panel_test');
        store = await SessionStore.open(directory: dir!.path);
      }
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
    final panel = tester.widget<PhotoPanel>(find.byType(PhotoPanel));
    return panel.controller.stop;
  }

  String? selected(WidgetTester tester) =>
      tester.widget<PhotoPanel>(find.byType(PhotoPanel)).controller.selectedId;

  /// Indices of the rows drawn with a highlight.
  Set<int> highlighted(WidgetTester tester) => {
        for (final row in tester.widgetList<WordRowItem>(find.byType(WordRowItem)))
          if (row.highlight != null) row.index,
      };

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
    final row = tester.getRect(find.byWidgetPredicate((w) => w is WordRowItem && w.index == 18));
    expect(row.top, greaterThanOrEqualTo(listRect(tester).top));
    expect(row.bottom, lessThanOrEqualTo(listRect(tester).bottom));

    // Another photo moves the highlight; its first row (3) is far up again.
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
    await tester.pumpAndSettle();
    expect(highlighted(tester), containsAll([3]));
    expect(highlighted(tester).contains(18), isFalse);
    expect(tester.any(find.byWidgetPredicate((w) => w is WordRowItem && w.index == 3)), isTrue);

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
}
