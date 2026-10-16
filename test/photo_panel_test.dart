import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/system_gesture_exclusion.dart';
import 'package:flutter_vocabulary_app/features/notes/notes_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_a.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/photo_panel_look.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_item.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_morph.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

import 'photo_panel_test_host.dart';
import 'photo_preview_test.dart' show MapSourcePhotoStore;

/// Records what the panel sends to Android's gesture exclusion (ADR-0002).
class _RecordingExclusion extends SystemGestureExclusion {
  final sent = <List<Rect>>[];

  @override
  Future<void> setRects(List<Rect> rects, {required double devicePixelRatio}) async =>
      sent.add(rects);

  @override
  Future<void> clear() async => sent.add(const []);
}

/// side-bar-for-main-screen T19: the shared panel behaviour (spec AC-01 to
/// AC-18) on the real main screen, with look A.
/// No photo file exists here, so every preview is the "not available"
/// placeholder (AC-09).
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

  // One store for the file, never closed (see switch_collection_test.dart).
  Directory? dir;
  late CollectionStore store;
  late ProviderContainer container;
  late _RecordingExclusion exclusion;
  tearDownAll(() {
    if (dir != null && dir!.existsSync()) dir!.deleteSync(recursive: true);
  });

  SessionSource photo(String id, int minute) => SessionSource()
    ..id = id
    ..fileName = '$id.jpg'
    ..takenAt = DateTime(2026, 10, 13, 9, minute);

  /// [count] rows: p1's rows are 3 and 15, p2's only row is 18 (or the ones
  /// given), the rest typed.
  List<WordPair> rows({int count = 20, List<int> p1 = const [3, 15], List<int> p2 = const [18]}) => [
        for (var i = 0; i < count; i++)
          WordPair(
            word: 'word$i',
            translation: 'слово$i',
            rowId: 'r$i',
            sourceId: p1.contains(i)
                ? 'p1'
                : p2.contains(i)
                    ? 'p2'
                    : null,
          ),
      ];

  Future<void> ensureStore() async {
    if (dir != null) return;
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('photo_panel_test');
    store = await CollectionStore.open(directory: dir!.path);
  }

  Future<WordCollection> pumpMain(WidgetTester tester,
      {List<WordPair>? words, bool photos = true}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Speech stops when the session changes or the screen goes.
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async => null);
    SharedPreferences.setMockInitialValues({});
    late WordCollection current;
    await tester.runAsync(() async {
      await ensureStore();
      final now = DateTime.now();
      current = WordCollection.create()
        ..updatedAt = now
        ..lastLocalModifiedAt = now
        ..words = words ?? rows()
        ..sources = photos ? [photo('p1', 1), photo('p2', 2)] : [];
      await store.put(current);
      await store.setCurrentCollectionId(current.collectionId);
    });
    exclusion = _RecordingExclusion();
    container = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({})),
      systemGestureExclusionProvider.overrideWithValue(exclusion),
    ]);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: mainScreenRouter()),
    ));
    // A notifier change makes the screen restore the session's rows (as
    // main_screen_photo_panel_test.dart).
    container.read(wordInputNotifierProvider.notifier).addAll([WordPair()]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    return current;
  }

  Future<void> tearDownMain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  PhotoPanel panel(WidgetTester tester) =>
      tester.widget<PhotoPanel>(find.byType(PhotoPanel, skipOffstage: false));
  PanelStop stop(WidgetTester tester) => panel(tester).controller.stop;
  String? selected(WidgetTester tester) => panel(tester).controller.selectedId;

  /// Rows drawn with a highlight: while the panel is open each row is its
  /// one line, closed the full row.
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

  Finder rowField(int index, String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is WordRowItem && w.index == index),
      matching: find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label));

  bool wordFocused(WidgetTester tester, int index) =>
      tester.widget<TextField>(rowField(index, 'Word')).focusNode!.hasFocus;

  Rect listRect(WidgetTester tester) => tester.getRect(find.byType(ListView).first);

  ScrollPosition listPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  void expectFullyInView(WidgetTester tester, int index) {
    final list = listRect(tester);
    final r = tester.getRect(row(index));
    expect(r.top, greaterThanOrEqualTo(list.top - 0.5), reason: 'row $index top in view');
    expect(r.bottom, lessThanOrEqualTo(list.bottom + 0.5), reason: 'row $index bottom in view');
  }

  Future<void> openHalf(WidgetTester tester) async {
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.halfOpen);
  }

  Future<void> select(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey(id)));
    await tester.pumpAndSettle();
  }

  /// On the main screen a drag to full-open opens Notes, over the panel
  /// back at half-open (owner, 2026-10-15).
  Future<void> openNotesByDrag(WidgetTester tester) async {
    await tester.fling(
        find.byKey(PhotoPanel.handleKey), const Offset(-60, 0), 3000);
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);
    expect(stop(tester), PanelStop.halfOpen);
  }

  const look = LookA();

  group('look A', () {
    testWidgets('the tab sits on the right between the top bar and the buttons (AC-01)',
        (tester) async {
      await pumpMain(tester);
      final tab = tester.getRect(find.byKey(PhotoPanel.tabKey));
      final list = listRect(tester);
      expect(tab.right, list.right, reason: 'on the right edge');
      expect(tab.top, greaterThan(list.top), reason: 'not in the top corner');
      expect(tab.bottom, lessThanOrEqualTo(list.bottom - 80), reason: 'above the buttons');
      expect(tab.height, lessThanOrEqualTo(PhotoPanelLook.maxTabHeight));

      final before = tab;
      await tester.dragFrom(list.centerLeft.translate(40, 0), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(listPosition(tester).pixels, greaterThan(0));
      expect(tester.getRect(find.byKey(PhotoPanel.tabKey)), before,
          reason: 'stays at its place while the list scrolls');
      await tearDownMain(tester);
    });

    testWidgets('no photo with words: no tab, Back as before (AC-02)', (tester) async {
      await pumpMain(tester, photos: false, words: [WordPair(word: 'typed')]);
      expect(find.byKey(PhotoPanel.tabKey), findsNothing);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tearDownMain(tester);
    });

    testWidgets('a tap settles half-open within 300 ms, oldest first, keyboard closed, '
        'text kept, placeholders shown (AC-03, AC-09)', (tester) async {
      await pumpMain(tester);
      // A row being edited (typing would start the row's lookups, which
      // outlive the test).
      await tester.tap(rowField(1, 'Word'));
      await tester.pump();
      expect(wordFocused(tester, 1), isTrue);

      await tester.tap(find.byKey(PhotoPanel.tabKey));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 284));
      expect(stop(tester), PanelStop.halfOpen);
      expect(tester.getSize(find.byKey(PhotoPanel.panelKey)).width, look.halfOpenWidth);
      expect(FocusManager.instance.primaryFocus?.context?.widget is EditableText, isFalse,
          reason: 'the keyboard closes');

      final p1 = tester.getRect(find.byKey(PhotoPanel.smallPhotoKey('p1')));
      final p2 = tester.getRect(find.byKey(PhotoPanel.smallPhotoKey('p2')));
      expect(p1.top, lessThan(p2.top), reason: 'oldest first');
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(PhotoPanel.smallPhotoKey('p1')),
              matching: find.byWidgetPredicate(
                  (w) => w is Semantics && w.properties.label == 'Photo not available')),
          findsOneWidget,
          reason: 'no file: the placeholder (AC-09)');
      expect(tester.widget<CompactWordLine>(line(1)).text, startsWith('word1'),
          reason: 'the text is kept, shown on the row\'s one line');
      expect(tester.getRect(row(1)).left, lessThan(listRect(tester).right - look.halfOpenWidth),
          reason: 'the rows stay visible beside it');
      await tearDownMain(tester);
    });

    testWidgets('selecting highlights its rows and jumps; one selection; unselecting does '
        'not scroll; scrolling keeps it (AC-04, AC-05, AC-06, AC-09)', (tester) async {
      await pumpMain(tester);
      await openHalf(tester);

      await select(tester, 'p2');
      expect(selected(tester), 'p2');
      expect(highlighted(tester), {18});
      expectFullyInView(tester, 18);

      await select(tester, 'p1');
      expect(selected(tester), 'p1');
      expect(highlighted(tester), containsAll([3]));
      expect(highlighted(tester).contains(18), isFalse, reason: 'one photo at a time');
      expectFullyInView(tester, 3);

      final at = listPosition(tester).pixels;
      await select(tester, 'p1');
      expect(selected(tester), isNull);
      expect(highlighted(tester), isEmpty);
      expect(listPosition(tester).pixels, at, reason: 'unselecting never scrolls');

      await select(tester, 'p2');
      await tester.dragFrom(listRect(tester).centerLeft.translate(40, 0), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.halfOpen);
      expect(selected(tester), 'p2');
      await tearDownMain(tester);
    });

    testWidgets('the jump brings a row 190 of 200 fully into view within 500 ms (AC-04)',
        (tester) async {
      await pumpMain(tester, words: rows(count: 200, p1: [190], p2: [5]));
      await openHalf(tester);
      await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('p1')));
      for (var spent = 0; spent < 500; spent += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expectFullyInView(tester, 190);
      expect(highlighted(tester), {190});
      await tester.pumpAndSettle();
      await tearDownMain(tester);
    });

    testWidgets('a drag past half-open turns the panel into the Notes page, '
        'which then opens on the selected source (owner, 2026-10-15)', (tester) async {
      // A notch: the page in the panel keeps clear of it, as the pushed one.
      tester.view.padding = const FakeViewPadding(top: 150);
      addTearDown(tester.view.resetPadding);
      await pumpMain(tester);
      await openHalf(tester);
      await select(tester, 'p2');
      final handle = find.byKey(PhotoPanel.handleKey);

      // Mid-drag: the Notes page shows inside the widening panel, and the
      // large photos never do.
      final gesture = await tester.startGesture(tester.getCenter(handle));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(PhotoPanel.notesRevealKey), findsOneWidget);
      expect(find.byKey(PhotoPanel.growingPhotoKey), findsNothing);
      expect(find.byKey(PhotoPanel.largeBrowserKey), findsNothing);
      final reveal = tester.getRect(find.byKey(PhotoPanel.notesRevealKey));
      expect(reveal.left, 0, reason: 'laid out on the whole screen, as pushed');
      final revealTitle = tester.getRect(find.descendant(
          of: find.byKey(PhotoPanel.notesRevealKey),
          matching: find.text('Notes')));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(tester.getRect(find.text('Notes')), revealTitle,
          reason: 'the top bar is below the notch in both');
      expect(revealTitle.top, greaterThan(150 / tester.view.devicePixelRatio));
      expect(find.byKey(PhotoPanel.notesRevealKey), findsNothing,
          reason: 'under Notes the panel is back at half-open');
      expect(find.byKey(NotesScreen.itemKey('p2')), findsOneWidget);
      expect(stop(tester), PanelStop.halfOpen);
      expect(selected(tester), 'p2');

      // A short drag that falls back stays the panel: no Notes.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      await tester.timedDrag(handle, const Offset(-80, 0), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(NotesScreen), findsNothing);
      expect(find.byKey(PhotoPanel.notesRevealKey), findsNothing);
      expect(stop(tester), PanelStop.halfOpen);
      await tearDownMain(tester);
    });

    testWidgets('drags settle at a stop; a flick moves one stop (AC-08)', (tester) async {
      await pumpMain(tester);
      final tab = find.byKey(PhotoPanel.tabKey);

      await tester.drag(tab, const Offset(-50, 0));
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.halfOpen, reason: 'any drag left from closed');
      await tester.tap(find.byKey(PhotoPanel.closeKey));
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.closed);

      await tester.fling(tab, const Offset(-300, 0), 3000);
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.halfOpen, reason: 'a flick never skips a stop');
      await tester.tap(find.byKey(PhotoPanel.closeKey));
      await tester.pumpAndSettle();

      await tester.timedDrag(tab, const Offset(-320, 0), const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(NotesScreen), findsOneWidget,
          reason: 'a long drag opens Notes (owner, 2026-10-15)');
      expect(stop(tester), PanelStop.halfOpen);
      await tearDownMain(tester);
    });

    testWidgets('Back steps back and never leaves while open (AC-10)',
        (tester) async {
      await pumpMain(tester);
      await openHalf(tester);
      await select(tester, 'p1');
      await openNotesByDrag(tester);

      // Back closes Notes first, onto the half-open panel.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(NotesScreen), findsNothing);
      expect(stop(tester), PanelStop.halfOpen);
      expect(selected(tester), 'p1');

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.closed);
      expect(find.byType(WordInputScreen), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tearDownMain(tester);
    });

    testWidgets('open: a tap on a row or a button only closes it (AC-11)', (tester) async {
      await pumpMain(tester);
      await openHalf(tester);
      final count = container.read(wordInputNotifierProvider).value!.words.length;

      await tester.tap(line(1), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.closed);
      expect(wordFocused(tester, 1), isFalse);

      await openHalf(tester);
      await tester.tap(find.byTooltip('Settings'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.closed);
      expect(find.byType(WordInputScreen), findsOneWidget);
      expect(container.read(wordInputNotifierProvider).value!.words.length, count);
      await tearDownMain(tester);
    });

    testWidgets('Android keeps the tab, then the handle, then nothing from Back (AC-12)',
        (tester) async {
      await pumpMain(tester);
      await tester.pump();
      final tab = tester.getRect(find.byKey(PhotoPanel.tabKey));
      expect(exclusion.sent.last, [tab]);

      await openHalf(tester);
      await tester.pump();
      expect(exclusion.sent.last.single.height, look.handleBarHeight);
      expect(exclusion.sent.last.single.width, look.halfOpenWidth);

      await openNotesByDrag(tester);
      await tester.pump();
      expect(exclusion.sent.last, isEmpty);
      await tearDownMain(tester);
    });

    testWidgets('a vertical drag moves the tab and nothing under it responds (AC-14)',
        (tester) async {
      await pumpMain(tester);
      final count = container.read(wordInputNotifierProvider).value!.words.length;
      final before = tester.getRect(find.byKey(PhotoPanel.tabKey));

      await tester.drag(find.byKey(PhotoPanel.tabKey), const Offset(0, 200));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byKey(PhotoPanel.tabKey));
      expect(after.top, closeTo(before.top + 200, 1));
      expect(stop(tester), PanelStop.closed, reason: 'one drag never does both');
      expect(container.read(photoTabTopProvider), closeTo(after.top - listRect(tester).top, 1));

      await tester.tap(find.byKey(PhotoPanel.tabKey));
      await tester.pumpAndSettle();
      expect(container.read(wordInputNotifierProvider).value!.words.length, count,
          reason: 'no row control fired through the tab');
      await tearDownMain(tester);
    });

    testWidgets('the panel follows the words; a new session closes it; background keeps it '
        '(AC-15, AC-15b, AC-16)', (tester) async {
      late WordCollection other;
      await tester.runAsync(() async {
        await ensureStore();
        other = WordCollection.create()
          ..updatedAt = DateTime(2026, 9, 2)
          ..lastLocalModifiedAt = DateTime(2026, 9, 2)
          ..words = [WordPair(word: 'from', sourceId: 'q1')]
          ..sources = [photo('q1', 5)];
        await store.put(other);
      });
      await pumpMain(tester);
      await openHalf(tester);
      await select(tester, 'p2');

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.halfOpen);
      expect(selected(tester), 'p2');

      container.read(wordInputNotifierProvider.notifier).updateAt(18, word: '');
      await tester.pumpAndSettle();
      expect(selected(tester), isNull);
      expect(find.byKey(PhotoPanel.smallPhotoKey('p2')), findsNothing);
      expect(stop(tester), PanelStop.halfOpen);

      await tester.runAsync(() =>
          container.read(wordInputNotifierProvider.notifier).switchTo(other.collectionId));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.closed);
      await openHalf(tester);
      expect(find.byKey(PhotoPanel.smallPhotoKey('q1')), findsOneWidget);
      expect(find.byKey(PhotoPanel.smallPhotoKey('p1')), findsNothing);
      await tearDownMain(tester);
    });

    testWidgets('busy: the tab ignores touches (AC-17)', (tester) async {
      final host = PanelHost(busy: true, look: look);
      await tester.pumpWidget(host.build());
      await tester.pump();
      await tester.tap(find.byKey(PhotoPanel.tabKey), warnIfMissed: false);
      await tester.drag(find.byKey(PhotoPanel.tabKey), const Offset(-100, 0), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(host.controller.stop, PanelStop.closed);
    });

    testWidgets('a screen reader opens, finds Open notes and closes without a drag (AC-18)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpMain(tester);
      void tap(String label) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        node.owner!.performAction(node.id, SemanticsAction.tap);
      }

      tap('Collection photos, 2');
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.halfOpen);
      // Expand is the Notes page's button now (owner, 2026-10-15).
      expect(find.bySemanticsLabel('Open notes'), findsOneWidget);
      tap('Close photos');
      await tester.pumpAndSettle();
      expect(stop(tester), PanelStop.closed);
      await tearDownMain(tester);
      handle.dispose();
    });
  });
}

