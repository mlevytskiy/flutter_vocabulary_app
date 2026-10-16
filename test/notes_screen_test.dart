import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/notes/notes_screen.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/source_hero.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

import 'photo_preview_test.dart' show MapSourcePhotoStore, kPng;

/// Notes (owner, 2026-10-15): the half-open panel's expand control opens the
/// Notes page; one pager per source, starting on its picture, its words to
/// the right and its note to the left (kept since notes-editing; see
/// notes_editing_test.dart).

class _FakeInput extends WordInputNotifier {
  _FakeInput(this.session);
  final Session session;

  @override
  Future<Session> build() async => session;
}

Session _session() => Session.create()
  ..sources = [
    SessionSource()
      ..id = 'p1'
      ..fileName = 'p1.jpg'
      ..takenAt = DateTime(2026, 10, 15, 9),
    SessionSource()
      ..id = 's1'
      ..kind = SourceKind.set
      ..name = 'Kitchen set'
      ..url = 'https://quizlet.com/1/x/'
      ..takenAt = DateTime(2026, 10, 15, 10),
  ]
  ..words = [
    WordPair(word: 'cup', translation: 'чашка', sourceId: 'p1', rowId: 'r1'),
    WordPair(word: 'fork', translation: 'виделка', sourceId: 'p1', rowId: 'r2'),
    WordPair(
        word: 'pan', translation: 'сковорідка', sourceId: 's1', rowId: 'r3'),
  ];

void main() {
  late PhotoPanelController controller;
  late MapSourcePhotoStore store;

  Future<void> pumpMain(WidgetTester tester, {MapSourcePhotoStore? photoStore}) async {
    final photos = photoStore ?? MapSourcePhotoStore({});
    SharedPreferences.setMockInitialValues({});
    controller = PhotoPanelController();
    final container = ProviderContainer(overrides: [
      wordInputNotifierProvider.overrideWith(() => _FakeInput(_session())),
      sourcePhotoStoreProvider.overrideWithValue(photos),
      // A note's debounced write waits for a store that never opens.
      sessionStoreProvider
          .overrideWith((ref) => Completer<SessionStore>().future),
    ]);
    addTearDown(container.dispose);
    await tester
        .runAsync(() => container.read(wordInputNotifierProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Main')),
            body: Stack(children: [
              const SizedBox.expand(),
              Positioned.fill(
                child: PhotoPanel(
                  controller: controller,
                  onOpenNotes: (id) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => NotesScreen(selectedId: id))),
                ),
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    store = photos;
  }

  Future<void> openNotes(WidgetTester tester) async {
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
  }

  Finder heroOf(String id) =>
      find.byWidgetPredicate((w) => w is Hero && w.tag == SourceHero.tag(id),
          skipOffstage: false);

  testWidgets('expand opens Notes over the half-open panel, and Back returns',
      (tester) async {
    await pumpMain(tester);
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    // The small pictures are the heroes' panel side.
    expect(heroOf('p1'), findsOneWidget);
    expect(heroOf('s1'), findsOneWidget);
    expect(find.bySemanticsLabel('Open notes'), findsOneWidget);

    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-flight: the panel's picture is hidden while the hero flies.
    Finder hidden() => find.descendant(
        of: heroOf('p1'),
        matching: find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        skipOffstage: false);
    expect(hidden(), findsOneWidget);
    await tester.pumpAndSettle();
    expect(hidden(), findsNothing);

    expect(find.text('Notes'), findsOneWidget);
    expect(find.byKey(NotesScreen.itemKey('p1')), findsOneWidget);
    expect(find.byKey(NotesScreen.itemKey('s1')), findsOneWidget);
    expect(find.text('Photo 1'), findsOneWidget);
    expect(find.text('Kitchen set'), findsWidgets);
    expect(find.text('2 words'), findsOneWidget);
    // The panel stays half-open under Notes, for the flight back.
    expect(controller.stop, PanelStop.halfOpen);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsNothing);
    expect(controller.stop, PanelStop.halfOpen);
  });

  testWidgets(
      'a pager starts on the picture; words to the right, note to the left',
      (tester) async {
    await pumpMain(tester);
    await openNotes(tester);
    final pager = find.byKey(NotesScreen.pagerKey('p1'));
    expect(tester.widget<PageView>(pager).controller!.page, 1);

    await tester.drag(pager, const Offset(-400, 0));
    await tester.pumpAndSettle();
    Finder inPager(Finder f) => find.descendant(of: pager, matching: f);
    expect(tester.widget<PageView>(pager).controller!.page, 2);
    expect(inPager(find.text('cup — чашка')), findsOneWidget);
    expect(inPager(find.text('fork — виделка')), findsOneWidget);
    expect(inPager(find.text('pan — сковорідка')), findsNothing);

    await tester.drag(pager, const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.drag(pager, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(pager).controller!.page, 0);
    final note = find.descendant(
        of: pager, matching: find.byKey(NotesScreen.tagFieldKey));
    expect(
        find.descendant(
            of: pager, matching: find.byKey(NotesScreen.descriptionKey)),
        findsOneWidget);
    expect(
        find.descendant(of: pager, matching: find.byKey(NotesScreen.linkKey)),
        findsOneWidget);
    // The tags are below the title, description and links.
    await tester.scrollUntilVisible(note, 60,
        scrollable: find
            .descendant(of: pager, matching: find.byType(Scrollable))
            .at(1));
    await tester.enterText(note, 'kitchen');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'kitchen'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Notes draws the panel\'s read-ahead photo in its first frame, '
      'with no new read (owner, 2026-10-15)', (tester) async {
    await pumpMain(tester, photoStore: MapSourcePhotoStore({'p1': kPng}));
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    final reads = store.reads.length;
    expect(store.reads, contains('p1'), reason: 'read ahead by the panel');

    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pump();
    // The picture is built when the hero lands: it is drawn in that frame.
    final flying = find.descendant(
        of: heroOf('p1'),
        matching: find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        skipOffstage: false);
    final item = find.byKey(NotesScreen.itemKey('p1'));
    var frames = 0;
    while ((!tester.any(item) || tester.any(flying)) && frames++ < 60) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(frames, greaterThan(1), reason: 'the hero flew');
    expect(
        find.descendant(
            of: find.byKey(NotesScreen.itemKey('p1')), matching: find.byType(Image)),
        findsOneWidget,
        reason: 'drawn in the frame the hero lands');
    await tester.pumpAndSettle();
    expect(store.reads.length, reads, reason: 'Notes reads no file again');
  });

  testWidgets('Notes starts with the selected source in view', (tester) async {
    await pumpMain(tester);
    await tester.tap(find.byKey(PhotoPanel.tabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.smallPhotoKey('s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byKey(NotesScreen.itemKey('s1'))).dy;
    expect(top, lessThan(400));
  });
}
