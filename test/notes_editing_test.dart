import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/notes/notes_screen.dart';
import 'package:flutter_vocabulary_app/features/notes/photo_viewer_screen.dart';
import 'package:flutter_vocabulary_app/features/notes/tag_editor.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_preview.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/word_row_item.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

import 'photo_preview_test.dart' show MapSourcePhotoStore, kPng;

/// notes-editing (owner, 2026-10-15): the Notes page keeps a title,
/// description, links and tags per source and tags per session, suggests
/// tags already used, opens a photo full screen and zooms it in place, and
/// opens a source's words as on the main screen, with "+ Add a word".

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
      ..takenAt = DateTime(2026, 10, 15, 10)
      ..tags = ['food'],
  ]
  ..words = [
    WordPair(word: 'cup', translation: 'чашка', sourceId: 'p1', rowId: 'r1'),
    WordPair(word: 'fork', translation: 'виделка', sourceId: 'p1', rowId: 'r2'),
    WordPair(
        word: 'pan', translation: 'сковорідка', sourceId: 's1', rowId: 'r3'),
    WordPair(word: '', translation: ''),
  ];

void main() {
  group('the note is kept with the session', () {
    test('a source note and session tags survive JSON and a copy', () {
      final source = SessionSource()
        ..id = 'p1'
        ..title = 'Market'
        ..description = 'Saturday'
        ..links = ['https://a', 'https://b']
        ..tags = ['food', 'trip'];
      final back = SessionSource.fromJson(source.toJson());
      expect(back.title, 'Market');
      expect(back.description, 'Saturday');
      expect(back.links, ['https://a', 'https://b']);
      expect(back.tags, ['food', 'trip']);
      final copy = source.copy();
      expect(copy.links, ['https://a', 'https://b']);
      copy.tags.add('x');
      expect(source.tags, ['food', 'trip'], reason: 'a copy owns its lists');

      final session = Session.create()..tags = ['week 1'];
      expect(Session.fromJson(session.toJson()).tags, ['week 1']);
      // A record from before has none.
      expect(SessionSource.fromJson({'id': 'x'}).links, isEmpty);
      expect(Session.fromJson({}).tags, isEmpty);
    });

    testWidgets('the notifier changes notes, session tags and inserts a word',
        (tester) async {
      final container = ProviderContainer(overrides: [
        wordInputNotifierProvider.overrideWith(() => _FakeInput(_session())),
        sessionStoreProvider
            .overrideWith((ref) => Completer<SessionStore>().future),
      ]);
      addTearDown(container.dispose);
      await container.read(wordInputNotifierProvider.future);
      final notifier = container.read(wordInputNotifierProvider.notifier);

      notifier.updateSourceNote('p1',
          title: 'Market', links: ['https://a'], tags: ['food']);
      notifier.updateSourceNote('p1', description: 'Saturday');
      final p1 = container
          .read(wordInputNotifierProvider)
          .value!
          .sources
          .firstWhere((s) => s.id == 'p1');
      expect(p1.title, 'Market', reason: 'left out, the title stays');
      expect(p1.description, 'Saturday');
      expect(p1.links, ['https://a']);
      expect(p1.tags, ['food']);
      notifier.updateSourceNote('p1', title: '  ');
      expect(p1.title, isNull, reason: 'an empty title is dropped');

      notifier.setSessionTags(['week 1']);
      expect(container.read(wordInputNotifierProvider).value!.tags, ['week 1']);

      notifier.insertAt(2, WordPair(word: 'jug', translation: '', sourceId: 'p1'));
      expect(
          [for (final w in container.read(wordInputNotifierProvider).value!.words) w.word],
          ['cup', 'fork', 'jug', 'pan', '']);

      expect(notifier.takeEditedElsewhere(), isFalse);
      notifier.markEditedElsewhere();
      expect(notifier.takeEditedElsewhere(), isTrue);
      expect(notifier.takeEditedElsewhere(), isFalse, reason: 'taken once');
      // Lets the debounced write go before the container is disposed.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('the Notes page', () {
    late ProviderContainer container;
    late MapSourcePhotoStore photos;

    Future<void> pumpNotes(WidgetTester tester,
        {List<Session> stored = const []}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.7;
      addTearDown(tester.view.reset);
      container = ProviderContainer(overrides: [
        wordInputNotifierProvider.overrideWith(() => _FakeInput(_session())),
        // The debounced write waits for a store that never opens.
        sessionStoreProvider
            .overrideWith((ref) => Completer<SessionStore>().future),
        nonEmptySessionsProvider.overrideWith((ref) => Stream.value(stored)),
        sourcePhotoStoreProvider.overrideWithValue(
            photos = MapSourcePhotoStore({'p1': kPng})),
      ]);
      addTearDown(container.dispose);
      await tester
          .runAsync(() => container.read(wordInputNotifierProvider.future));
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const NotesScreen(selectedId: 'p1'),
          routes: [
            GoRoute(
              path: 'photo/:sourceId',
              builder: (_, state) => PhotoViewerScreen(
                  sourceId: state.pathParameters['sourceId']!),
            ),
          ],
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    /// A widget test that lets the notifier's debounced write go before it
    /// ends.
    void notesTest(String name, Future<void> Function(WidgetTester) body) =>
        testWidgets(name, (tester) async {
          await body(tester);
          await tester.pump(const Duration(seconds: 1));
        });

    Session session() => container.read(wordInputNotifierProvider).value!;
    SessionSource source(String id) =>
        session().sources.firstWhere((s) => s.id == id);
    Finder pager(String id) => find.byKey(NotesScreen.pagerKey(id));

    Future<void> toNote(WidgetTester tester, String id) async {
      await tester.drag(pager(id), const Offset(400, 0));
      await tester.pumpAndSettle();
    }

    Future<Finder> scrollToInNote(
        WidgetTester tester, String id, Finder target) async {
      final inPager = find.descendant(of: pager(id), matching: target);
      await tester.scrollUntilVisible(inPager, 60,
          scrollable: find
              .descendant(of: pager(id), matching: find.byType(Scrollable))
              .at(1));
      await tester.pumpAndSettle();
      return inPager;
    }

    notesTest('a title above the description is kept and names the item',
        (tester) async {
      await pumpNotes(tester);
      await toNote(tester, 'p1');
      final title =
          find.descendant(of: pager('p1'), matching: find.byKey(NotesScreen.titleKey));
      final description = find.descendant(
          of: pager('p1'), matching: find.byKey(NotesScreen.descriptionKey));
      expect(tester.getTopLeft(title).dy,
          lessThan(tester.getTopLeft(description).dy));

      await tester.enterText(title, 'Market');
      await tester.enterText(description, 'Saturday stall');
      await tester.pump();
      expect(source('p1').title, 'Market');
      expect(source('p1').description, 'Saturday stall');
      expect(
          find.descendant(
              of: find.byKey(NotesScreen.itemKey('p1')),
              matching: find.text('Market')),
          findsNWidgets(2),
          reason: 'the field and the item header');
    });

    notesTest('more than one link, each kept; a removed one goes',
        (tester) async {
      await pumpNotes(tester);
      await toNote(tester, 'p1');
      await tester.enterText(
          find.descendant(of: pager('p1'), matching: find.byKey(NotesScreen.linkKey)),
          'https://one');
      final add = await scrollToInNote(
          tester, 'p1', find.byKey(NotesScreen.addLinkKey));
      await tester.tap(add);
      await tester.pumpAndSettle();
      final second = await scrollToInNote(
          tester, 'p1', find.byKey(NotesScreen.linkFieldKey(1)));
      await tester.enterText(second, 'https://two');
      await tester.pump();
      expect(source('p1').links, ['https://one', 'https://two']);

      await tester.tap(find.descendant(
          of: second, matching: find.byTooltip('Remove link')));
      await tester.pumpAndSettle();
      expect(source('p1').links, ['https://one']);
    });

    notesTest('several tags on a source, suggested from tags used anywhere',
        (tester) async {
      final older = Session.create()
        ..sources = [SessionSource()..id = 'old'..tags = ['travel']];
      await pumpNotes(tester, stored: [older]);
      await toNote(tester, 'p1');
      final field = await scrollToInNote(
          tester, 'p1', find.byKey(NotesScreen.tagFieldKey));
      await tester.enterText(field, 'kitchen');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Typing shows the tags used on other sources, not session tags.
      await tester.enterText(field, 'tr');
      await tester.pumpAndSettle();
      expect(find.byKey(TagEditor.suggestionKey('travel')), findsOneWidget);
      expect(find.byKey(TagEditor.suggestionKey('food')), findsNothing,
          reason: '"food" does not contain "tr"');
      await tester.tap(find.byKey(TagEditor.suggestionKey('travel')));
      await tester.pumpAndSettle();
      expect(source('p1').tags, ['kitchen', 'travel']);
      expect(
          find.descendant(
              of: pager('p1'), matching: find.widgetWithText(InputChip, 'travel')),
          findsOneWidget);

      await tester.tap(find.descendant(
          of: find.descendant(
              of: pager('p1'),
              matching: find.widgetWithText(InputChip, 'kitchen')),
          matching: find.byTooltip('Delete')));
      await tester.pumpAndSettle();
      expect(source('p1').tags, ['travel']);
    });

    notesTest('session tags sit above the list and are their own pool',
        (tester) async {
      final older = Session.create()..tags = ['B1 course'];
      await pumpNotes(tester, stored: [older]);
      final field = find.byKey(NotesScreen.sessionTagFieldKey);
      expect(tester.getTopLeft(field).dy,
          lessThan(tester.getTopLeft(find.byKey(NotesScreen.itemKey('p1'))).dy));

      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.byKey(TagEditor.suggestionKey('B1 course')), findsOneWidget);
      expect(find.byKey(TagEditor.suggestionKey('food')), findsNothing,
          reason: 'a source tag is not a session tag');
      await tester.enterText(field, 'week 3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(session().tags, ['week 3']);
      expect(find.widgetWithText(InputChip, 'week 3'), findsOneWidget);
    });

    notesTest('a tap on the photo opens it large, zoomable, and Back returns',
        (tester) async {
      await pumpNotes(tester);
      await tester.tap(find.byKey(NotesScreen.pictureKey('p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(PhotoViewerScreen.viewerKey), findsOneWidget);
      final viewer =
          tester.widget<InteractiveViewer>(find.byKey(PhotoViewerScreen.viewerKey));
      expect(viewer.maxScale, greaterThan(1));

      final center = tester.getCenter(find.byKey(PhotoViewerScreen.viewerKey));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
          greaterThan(1),
          reason: 'a double tap zooms in');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(PhotoViewerScreen.viewerKey), findsNothing);
      expect(find.byKey(NotesScreen.itemKey('p1')), findsOneWidget);
    });

    notesTest('the photo opens with no blink: the panel\'s bytes, decoded '
        'ahead, are drawn in the viewer\'s first frame', (tester) async {
      await pumpNotes(tester);
      // As the photo panel does before Notes opens.
      final context = tester.element(find.byType(NotesScreen));
      final preloader = container.read(photoPreloaderProvider);
      await tester.runAsync(() async {
        preloader.preload(
            context, photos, [source('p1')], const [100]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      final reads = photos.reads.length;

      await tester.tap(find.byKey(NotesScreen.pictureKey('p1')));
      // The large decode needs real time; the viewer waits for it.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump();
      final viewer = find.byType(PhotoViewerScreen);
      expect(viewer, findsOneWidget);
      // The hero flies the viewer's picture (its PhotoPreview fits the
      // photo in): already decoded in the frame the page opens.
      final large = find.byWidgetPredicate(
          (w) => w is PhotoPreview && w.fit == BoxFit.contain,
          skipOffstage: false);
      expect(large, findsOneWidget);
      expect(
          find.descendant(
              of: large,
              matching: find.byWidgetPredicate(
                  (w) => w is RawImage && w.image != null,
                  skipOffstage: false),
              skipOffstage: false),
          findsOneWidget,
          reason: 'drawn as the viewer opens, not after a file read');
      await tester.pumpAndSettle();
      expect(photos.reads.length, reads, reason: 'no new file read');
    });

    notesTest('a pinch zooms the photo in the pager, which then stands still',
        (tester) async {
      await pumpNotes(tester);
      final picture = find.byKey(NotesScreen.pictureKey('p1'));
      final center = tester.getCenter(picture);
      final a = await tester.startGesture(center - const Offset(20, 0),
          pointer: 1);
      final b = await tester.startGesture(center + const Offset(20, 0),
          pointer: 2);
      await tester.pump();
      for (var i = 1; i <= 5; i++) {
        await a.moveTo(center - Offset(20.0 + 15 * i, 0));
        await b.moveTo(center + Offset(20.0 + 15 * i, 0));
        await tester.pump();
      }
      expect(tester.widget<PageView>(pager('p1')).physics,
          isA<NeverScrollableScrollPhysics>());
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(find.descendant(
          of: picture, matching: find.byType(InteractiveViewer)));
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
          greaterThan(1));
      expect(tester.widget<PageView>(pager('p1')).physics,
          isA<NeverScrollableScrollPhysics>(),
          reason: 'zoomed in, one finger pans the photo');
    });

    notesTest(
        'a tap on the words opens them as on the main screen; '
        '"+ Add a word" adds one to the source', (tester) async {
      await pumpNotes(tester);
      await tester.drag(pager('p1'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(NotesScreen.wordsKey('p1')));
      await tester.pumpAndSettle();

      final dialog = find.byType(SourceWordsDialog);
      expect(dialog, findsOneWidget);
      final rows = find.descendant(of: dialog, matching: find.byType(WordRowItem));
      expect(rows, findsNWidgets(2));
      expect(find.descendant(of: dialog, matching: find.text('cup')), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('pan')), findsNothing);

      // An edit goes into the session.
      await tester.enterText(
          find.descendant(of: dialog, matching: find.text('fork')), 'spoon');
      await tester.pump();
      expect(session().words[1].word, 'spoon');
      expect(session().words[1].sourceId, 'p1');

      await tester.tap(find.byKey(SourceWordsDialog.addWordKey));
      await tester.pumpAndSettle();
      expect(rows, findsNWidgets(3));
      await tester.enterText(
          find.descendant(of: rows.at(2), matching: find.byType(TextField)).first,
          'jug');
      await tester.pump();
      expect([for (final w in session().words) w.word],
          ['cup', 'spoon', 'jug', 'pan', ''],
          reason: 'after the source\'s last word');
      expect(session().words[2].sourceId, 'p1');

      // Added and left blank, a row is taken out again on close.
      await tester.tap(find.byKey(SourceWordsDialog.addWordKey));
      await tester.pumpAndSettle();
      expect(session().words, hasLength(6));
      await tester.tap(find.byKey(SourceWordsDialog.closeKey));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect([for (final w in session().words) w.word],
          ['cup', 'spoon', 'jug', 'pan', '']);
      final notifier = container.read(wordInputNotifierProvider.notifier);
      expect(notifier.takeEditedElsewhere(), isTrue,
          reason: 'the main screen builds its rows again');
      // The page's words follow.
      expect(
          find.descendant(of: pager('p1'), matching: find.text('jug — ')),
          findsNothing);
      expect(find.text('3 words'), findsOneWidget);
    });

    notesTest('removing a word in the dialog takes it out of the session',
        (tester) async {
      await pumpNotes(tester);
      await tester.drag(pager('p1'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(NotesScreen.wordsKey('p1')));
      await tester.pumpAndSettle();
      final dialog = find.byType(SourceWordsDialog);
      final first = find.descendant(of: dialog, matching: find.byType(WordRowItem)).first;
      await tester.tap(find.descendant(of: first, matching: find.byIcon(Icons.close)).first);
      await tester.pumpAndSettle();
      expect([for (final w in session().words) w.word], ['fork', 'pan', '']);
      expect(find.descendant(of: dialog, matching: find.byType(WordRowItem)),
          findsOneWidget);
      // The rest still edit their own rows.
      await tester.enterText(
          find.descendant(of: dialog, matching: find.text('fork')), 'knife');
      await tester.pump();
      expect([for (final w in session().words) w.word], ['knife', 'pan', '']);
    });
  });
}
