import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/source_tile.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/quizlet_logo_icon.dart';

import 'photo_panel_test_host.dart';

/// side-panel-sources: Quizlet sets with words in the tab and the half-open
/// panel; full-open stays photos only (spec AC-21).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder large(String id) => find.byKey(PhotoPanel.largePhotoKey(id));

  Future<PanelHost> openHalf(WidgetTester tester, PanelHost host) async {
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
    return host;
  }

  testWidgets('a session with only a set shows the tab, its preview a Quizlet tile',
      (tester) async {
    final handle = tester.ensureSemantics();
    final host = PanelHost(photos: [fakeSet('quizlet-1', name: 'Verbs')]);
    await host.pump(tester);
    expect(tabFinder, findsOneWidget);
    final tile = find.descendant(of: tabFinder, matching: find.byType(SourceTile));
    expect(tile, findsOneWidget);
    expect(tester.widget<SourceTile>(tile).mini, isTrue);
    expect(find.descendant(of: tile, matching: find.byType(QuizletLogoIcon)), findsOneWidget);
    expect(find.bySemanticsLabel('Collection sources, 1'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a photos-only tab keeps its label "Collection photos, N"', (tester) async {
    final handle = tester.ensureSemantics();
    await PanelHost(photos: fakePhotos(2)).pump(tester);
    expect(find.bySemanticsLabel('Collection photos, 2'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('half-open: a set is a tile the size of a small photo with its logo and name',
      (tester) async {
    final photos = fakePhotos(2);
    final host = PanelHost(photos: [
      photos[0],
      fakeSet('quizlet-1', name: 'A very long set name that never fits in the tile', at: 1),
      photos[1],
    ]);
    await openHalf(tester, host);

    final setRect = tester.getRect(smallPhoto('quizlet-1'));
    expect(setRect.size, tester.getRect(smallPhoto('p0')).size);
    // In the given order: p0, the set, p1.
    expect(setRect.top, greaterThan(tester.getRect(smallPhoto('p0')).top));
    expect(setRect.top, lessThan(tester.getRect(smallPhoto('p1')).top));

    final inSet = find.descendant(of: smallPhoto('quizlet-1'), matching: find.byType(QuizletLogoIcon));
    expect(inSet, findsOneWidget);
    final name = tester.widget<Text>(
        find.descendant(of: smallPhoto('quizlet-1'), matching: find.byKey(const Key('source-tile-name'))));
    expect(name.data, startsWith('A very long'));
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  testWidgets('tapping a set selects it like a photo; the same set again unselects',
      (tester) async {
    final host = PanelHost(photos: [...fakePhotos(1), fakeSet('quizlet-1', at: 1)]);
    await openHalf(tester, host);
    await tester.tap(smallPhoto('quizlet-1'));
    await tester.pump();
    expect(host.controller.selectedId, 'quizlet-1');
    expect(host.selections, ['quizlet-1']);
    await tester.tap(smallPhoto('p0'));
    await tester.pump();
    expect(host.controller.selectedId, 'p0');
    await tester.tap(smallPhoto('p0'));
    await tester.pump();
    expect(host.controller.selectedId, isNull);
  });

  testWidgets('a screen reader names a set as a Quizlet set and counts only photos',
      (tester) async {
    final handle = tester.ensureSemantics();
    final host = PanelHost(photos: [
      ...fakePhotos(2),
      fakeSet('quizlet-1', name: 'Verbs', at: 5),
    ]);
    await openHalf(tester, host);
    expect(find.bySemanticsLabel('Photo 1 of 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Photo 2 of 2'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('Quizlet set Verbs'));
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('with no photo, full-open is unavailable: no expand, drags stop at half-open',
      (tester) async {
    final host = PanelHost(photos: [fakeSet('quizlet-1')]);
    await openHalf(tester, host);
    expect(find.byKey(PhotoPanel.expandKey), findsNothing);

    // A flick from half-open and a long drag from closed both stay half-open.
    await tester.fling(find.byKey(PhotoPanel.handleKey), const Offset(-300, 0), 3000);
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);

    host.controller.close();
    await tester.pumpAndSettle();
    await tester.timedDrag(tabFinder, const Offset(-320, 0), const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
    expect(panelRect(tester).width, lessThan(pageRect(tester).width / 2));
  });

  testWidgets('a selected set: full-open starts at the first photo and shows photos only',
      (tester) async {
    final host = PanelHost(photos: [
      fakeSet('quizlet-1'),
      ...fakePhotos(3),
    ]);
    await openHalf(tester, host);
    await tester.tap(smallPhoto('quizlet-1'));
    await tester.pump();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);
    expect(large('p0'), findsOneWidget);
    expect(large('quizlet-1'), findsNothing);
    final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.contains(tester.getCenter(large('p0'))), isTrue);
    // Back in half-open the set is still selected.
    host.controller.stepBack();
    await tester.pumpAndSettle();
    expect(host.controller.selectedId, 'quizlet-1');
  });

  testWidgets('the last photo leaving while full-open settles half-open with the set',
      (tester) async {
    final host = PanelHost(photos: [...fakePhotos(1), fakeSet('quizlet-1', at: 1)]);
    await openHalf(tester, host);
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);

    host.photos.value = [fakeSet('quizlet-1', at: 1)];
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
    expect(smallPhoto('quizlet-1'), findsOneWidget);
  });
}
