import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_a.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_preview.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/source_tile.dart';

import 'photo_panel_test_host.dart';
import 'photo_preview_test.dart' show MapSourcePhotoStore, kPng;

/// Owner, 2026-10-15: the panel's photos are read ahead so half-open does not
/// blink, the tab's third preview becomes a mosaic with more than three
/// sources, and a film shows its poster.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder mosaic() => find.descendant(of: tabFinder, matching: find.byKey(LookA.mosaicKey));
  int tabPreviews(WidgetTester tester) =>
      find.descendant(of: tabFinder, matching: find.byType(PhotoPreview)).evaluate().length;

  group('the tab', () {
    testWidgets('three sources: three previews, no mosaic', (tester) async {
      await PanelHost(photos: fakePhotos(3)).pump(tester);
      expect(mosaic(), findsNothing);
      expect(tabPreviews(tester), 3);
    });

    testWidgets('four sources: the third preview is a mosaic of the third and fourth', (tester) async {
      await PanelHost(photos: fakePhotos(4)).pump(tester);
      expect(mosaic(), findsOneWidget);
      expect(find.descendant(of: mosaic(), matching: find.byType(PhotoPreview)), findsNWidgets(2));
      expect(tabPreviews(tester), 4);
    });

    testWidgets('seven sources: the mosaic shows the third to the sixth, the tab keeps its height',
        (tester) async {
      final host = PanelHost(photos: fakePhotos(3));
      await host.pump(tester);
      final height = tabRect(tester).height;
      host.photos.value = fakePhotos(7);
      await PanelHost.settleLoads(tester);
      expect(find.descendant(of: mosaic(), matching: find.byType(PhotoPreview)), findsNWidgets(4));
      expect(tabPreviews(tester), 6);
      expect(tabRect(tester).height, height);
      expect(find.descendant(of: tabFinder, matching: find.text('7')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a set in the mosaic is a small tile with no overflow', (tester) async {
      await PanelHost(photos: [...fakePhotos(3), fakeSet('quizlet-1', at: 5)]).pump(tester);
      expect(find.descendant(of: mosaic(), matching: find.byType(SourceTile)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('half-open draws every read-ahead photo in its first frame, with no new read',
      (tester) async {
    final photos = fakePhotos(6);
    final store = MapSourcePhotoStore({for (final p in photos) p.source.id: kPng});
    final host = PanelHost(photos: photos, store: store);
    await host.pump(tester);
    final reads = store.reads.length;
    expect(store.reads.toSet(), {for (final p in photos) p.source.id}, reason: 'all read ahead');

    await tester.tap(tabFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    for (final p in photos.take(4)) {
      expect(find.descendant(of: smallPhoto(p.source.id), matching: find.byType(Image)), findsOneWidget,
          reason: '${p.source.id} is drawn at once');
    }
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
    expect(store.reads.length, reads, reason: 'opening reads no file again');
  });

  group('a tile in the half-open column (owner, 2026-10-15)', () {
    Future<void> pumpTile(WidgetTester tester, SessionSource source, {int? count}) =>
        tester.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(
                width: 96, height: 96, child: SourceTile(source: source, wordCount: count)),
          ),
        ));

    testWidgets('a film: CC and "N words", its name under them', (tester) async {
      await pumpTile(tester, SessionSource()
        ..id = 'subtitles-1'
        ..kind = SourceKind.subtitles
        ..name = 'Harbour Lights', count: 12);
      expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
      expect(find.text('12 words'), findsOneWidget);
      final count = tester.getRect(find.text('12 words'));
      final name = tester.getRect(find.byKey(const Key('source-tile-name')));
      expect(name.top, greaterThan(count.bottom - 0.5), reason: 'the name is under the count');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a set: its logo and "1 word"', (tester) async {
      await pumpTile(tester, SessionSource()
        ..id = 'quizlet-1'
        ..kind = SourceKind.set
        ..name = 'Irregular verbs', count: 1);
      expect(find.text('1 word'), findsOneWidget);
      expect(find.text('Irregular verbs'), findsOneWidget);
    });

    testWidgets('a film with a poster: the poster instead of CC and the count', (tester) async {
      await pumpTile(tester, SessionSource()
        ..id = 'subtitles-1'
        ..kind = SourceKind.subtitles
        ..name = 'Harbour Lights'
        ..url = 'https://posters.test/501.jpg', count: 12);
      expect(find.byKey(const Key('source-tile-poster')), findsOneWidget);
    });
  });

  group('a film tile', () {
    SessionSource film({String? poster}) => SessionSource()
      ..id = 'subtitles-1'
      ..kind = SourceKind.subtitles
      ..name = 'Harbour Lights'
      ..url = poster;

    Future<void> pumpTile(WidgetTester tester, SessionSource source, {bool mini = false}) =>
        tester.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(width: 96, height: 96, child: SourceTile(source: source, mini: mini)),
          ),
        ));

    testWidgets('with a poster: the poster, the title over it, the icon until it loads', (tester) async {
      await pumpTile(tester, film(poster: 'https://posters.test/501.jpg'));
      expect(find.byKey(const Key('source-tile-poster')), findsOneWidget);
      expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
      expect(find.text('Harbour Lights'), findsWidgets);
    });

    testWidgets('mini with a poster: the poster only', (tester) async {
      await pumpTile(tester, film(poster: 'https://posters.test/501.jpg'), mini: true);
      expect(find.byKey(const Key('source-tile-poster')), findsOneWidget);
      expect(find.byKey(const Key('source-tile-name')), findsNothing);
    });

    testWidgets('without a poster: the film icon and the title, as before', (tester) async {
      await pumpTile(tester, film());
      expect(find.byKey(const Key('source-tile-poster')), findsNothing);
      expect(find.byIcon(Icons.closed_caption_outlined), findsOneWidget);
      expect(find.text('Harbour Lights'), findsOneWidget);
    });
  });
}
