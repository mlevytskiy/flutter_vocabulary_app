import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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
import 'package:flutter_vocabulary_app/core/services/system_gesture_exclusion.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/looks.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/photo_panel_look.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/main_screen_pager.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_item.dart';
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
/// AC-18) on the real main screen, once per design variant (AC-19, ADR-0003).
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

  // One store for the file, never closed (see switch_session_test.dart).
  Directory? dir;
  late SessionStore store;
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
    store = await SessionStore.open(directory: dir!.path);
  }

  Future<Session> pumpMain(WidgetTester tester, PhotoPanelVariant variant,
      {List<WordPair>? words, bool photos = true, List<FilmDialogue> dialogues = const []}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Speech stops when the session changes or the screen goes.
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async => null);
    SharedPreferences.setMockInitialValues({});
    late Session current;
    await tester.runAsync(() async {
      await ensureStore();
      final now = DateTime.now();
      current = Session.create()
        ..updatedAt = now
        ..lastLocalModifiedAt = now
        ..words = words ?? rows()
        ..sources = photos ? [photo('p1', 1), photo('p2', 2)] : []
        ..dialogues = dialogues;
      await store.put(current);
      await store.setCurrentSessionId(current.sessionId);
    });
    exclusion = _RecordingExclusion();
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      sourcePhotoStoreProvider.overrideWithValue(MapSourcePhotoStore({})),
      systemGestureExclusionProvider.overrideWithValue(exclusion),
    ]);
    await tester.runAsync(() async {
      await container.read(wordInputNotifierProvider.future);
      await container.read(photoPanelVariantProvider.notifier).set(variant);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
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

  Set<int> highlighted(WidgetTester tester) => {
        for (final row in tester.widgetList<WordRowItem>(find.byType(WordRowItem)))
          if (row.highlight != null) row.index,
      };

  Finder row(int index) =>
      find.byWidgetPredicate((w) => w is WordRowItem && w.index == index);

  Finder rowField(int index, String label) => find.descendant(
      of: row(index),
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

  Future<void> openFull(WidgetTester tester) async {
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(stop(tester), PanelStop.fullOpen);
  }

  /// Browses to the next large photo the variant's way (AC-07b, AC-19).
  Future<void> browseNext(WidgetTester tester, PhotoPanelVariant variant) async {
    final browser = find.byKey(PhotoPanel.largeBrowserKey);
    final offset = variant == PhotoPanelVariant.a ? const Offset(-300, 0) : const Offset(0, -500);
    await tester.drag(browser, offset);
    await tester.pumpAndSettle();
  }

  double pagerPage(WidgetTester tester) => tester
      .widget<PageView>(find.descendant(
          of: find.byType(MainScreenPager), matching: find.byType(PageView)))
      .controller!
      .page!;

  for (final variant in PhotoPanelVariant.values) {
    final look = lookFor(variant);

    group('variant ${variant.name}', () {
      testWidgets('the tab sits on the right between the top bar and the buttons (AC-01)',
          (tester) async {
        await pumpMain(tester, variant);
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
        await pumpMain(tester, variant, photos: false, words: [WordPair(word: 'typed')]);
        expect(find.byKey(PhotoPanel.tabKey), findsNothing);
        expect(await tester.binding.handlePopRoute(), isFalse);
        await tearDownMain(tester);
      });

      testWidgets('a tap settles half-open within 300 ms, oldest first, keyboard closed, '
          'text kept, placeholders shown (AC-03, AC-09)', (tester) async {
        await pumpMain(tester, variant);
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
        expect(wordFocused(tester, 1), isFalse, reason: 'the keyboard closes');
        expect(tester.widget<TextField>(rowField(1, 'Word')).controller!.text, 'word1',
            reason: 'the text is kept');

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
        expect(tester.getRect(row(1)).left, lessThan(listRect(tester).right - look.halfOpenWidth),
            reason: 'the rows stay visible beside it');
        await tearDownMain(tester);
      });

      testWidgets('selecting highlights its rows and jumps; one selection; unselecting does '
          'not scroll; scrolling keeps it (AC-04, AC-05, AC-06, AC-09)', (tester) async {
        await pumpMain(tester, variant);
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
        await pumpMain(tester, variant, words: rows(count: 200, p1: [190], p2: [5]));
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

      testWidgets('full-open grows the photo, starts at the selected one, browsing keeps the '
          'selection, two-finger zoom is there (AC-07, AC-07b)', (tester) async {
        await pumpMain(tester, variant);
        await openHalf(tester);
        await select(tester, 'p2');

        await tester.tap(find.byKey(PhotoPanel.expandKey));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(PhotoPanel.growingPhotoKey), findsOneWidget);
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.fullOpen);
        final panelRect = tester.getRect(find.byKey(PhotoPanel.panelKey));
        expect(panelRect.left, 0, reason: 'covers the word rows');
        expect(panelRect.right, listRect(tester).right);
        final large = find.byKey(PhotoPanel.largePhotoKey('p2'));
        expect(large, findsOneWidget);
        expect(tester.widget(large), isA<InteractiveViewer>(), reason: 'two-finger zoom');

        await tester.tap(large);
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.fullOpen, reason: 'a tap on a large photo does nothing');

        await browseNext(tester, variant);
        await browseNext(tester, variant);
        expect(selected(tester), 'p2', reason: 'browsing never changes the selection');

        await tester.tap(find.byKey(PhotoPanel.backKey));
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.halfOpen);
        expect(highlighted(tester), {18});
        await tearDownMain(tester);
      });

      testWidgets('drags settle at a stop; a flick moves one stop (AC-08)', (tester) async {
        await pumpMain(tester, variant);
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
        expect(stop(tester), PanelStop.fullOpen, reason: 'a long drag');

        await tester.fling(find.byKey(PhotoPanel.handleKey), const Offset(80, 0), 3000);
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.halfOpen);
        await tearDownMain(tester);
      });

      testWidgets('Back steps back and never leaves while open (AC-10)',
          (tester) async {
        await pumpMain(tester, variant);
        await openHalf(tester);
        await select(tester, 'p1');
        await openFull(tester);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
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
        await pumpMain(tester, variant);
        await openHalf(tester);
        final count = container.read(wordInputNotifierProvider).value!.words.length;

        await tester.tap(rowField(1, 'Word'), warnIfMissed: false);
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
        await pumpMain(tester, variant);
        await tester.pump();
        final tab = tester.getRect(find.byKey(PhotoPanel.tabKey));
        expect(exclusion.sent.last, [tab]);

        await openHalf(tester);
        await tester.pump();
        expect(exclusion.sent.last.single.height, look.handleBarHeight);
        expect(exclusion.sent.last.single.width, look.halfOpenWidth);

        await openFull(tester);
        await tester.pump();
        expect(exclusion.sent.last, isEmpty);
        await tearDownMain(tester);
      });

      testWidgets('on a dialogue page the tab stays put and opening returns to the words page '
          '(AC-13)', (tester) async {
        // Few rows: the swipe starts on the page, not on a row's text field.
        await pumpMain(tester, variant, words: rows(count: 3, p1: [1], p2: [2]), dialogues: [
          FilmDialogue()
            ..id = 'd1'
            ..lines = ['word1 in a line.']
            ..wordRowIds = ['r1'],
        ]);
        final before = tester.getRect(find.byKey(PhotoPanel.tabKey));
        await tester.flingFrom(const Offset(150, 600), const Offset(-250, 0), 2000);
        await tester.pumpAndSettle();
        expect(pagerPage(tester), 1);
        expect(tester.getRect(find.byKey(PhotoPanel.tabKey)), before);

        await tester.tap(find.byKey(PhotoPanel.tabKey));
        await tester.pumpAndSettle();
        expect(pagerPage(tester), 0);
        expect(stop(tester), PanelStop.halfOpen);

        await tester.flingFrom(const Offset(150, 600), const Offset(-250, 0), 2000);
        await tester.pumpAndSettle();
        expect(pagerPage(tester), 0, reason: 'no swipe changes the page while open');
        await tearDownMain(tester);
      });

      testWidgets('a vertical drag moves the tab and nothing under it responds (AC-14)',
          (tester) async {
        await pumpMain(tester, variant);
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
        await pumpMain(tester, variant);
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
            container.read(wordInputNotifierProvider.notifier).switchTo(other.sessionId));
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

      testWidgets('a screen reader opens, expands and closes without a drag (AC-18)',
          (tester) async {
        final handle = tester.ensureSemantics();
        await pumpMain(tester, variant);
        void tap(String label) {
          final node = tester.getSemantics(find.bySemanticsLabel(label));
          node.owner!.performAction(node.id, SemanticsAction.tap);
        }

        tap('Session photos, 2');
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.halfOpen);
        tap('Show photos large');
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.fullOpen);
        tap('Back to small photos');
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.halfOpen);
        tap('Close photos');
        await tester.pumpAndSettle();
        expect(stop(tester), PanelStop.closed);
        await tearDownMain(tester);
        handle.dispose();
      });

      testWidgets('switching the variant redraws at once (AC-19)', (tester) async {
        await pumpMain(tester, variant);
        await openHalf(tester);
        final next = PhotoPanelVariant.values[(variant.index + 1) % PhotoPanelVariant.values.length];
        await tester.runAsync(() => container.read(photoPanelVariantProvider.notifier).set(next));
        await tester.pump();
        expect(tester.getSize(find.byKey(PhotoPanel.panelKey)).width, lookFor(next).halfOpenWidth);
        expect(stop(tester), PanelStop.halfOpen);
        await tearDownMain(tester);
      });
    });
  }
}
