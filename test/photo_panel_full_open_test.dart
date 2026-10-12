import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_preview.dart';

import 'photo_panel_test_host.dart';

/// side-bar-for-main-screen T9: the large photos in full-open (spec AC-07b,
/// AC-09, AC-10).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Finder large(String id) => find.byKey(PhotoPanel.largePhotoKey(id));

  Future<PanelHost> openFull(WidgetTester tester, {String? select}) async {
    final host = PanelHost(photos: fakePhotos(5));
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    if (select != null) {
      await tester.ensureVisible(smallPhoto(select));
      await tester.pumpAndSettle();
      await tester.tap(smallPhoto(select));
      await tester.pump();
    }
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);
    return host;
  }

  bool onScreen(WidgetTester tester, Finder f) {
    final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    return f.evaluate().isNotEmpty && screen.contains(tester.getCenter(f));
  }

  testWidgets('full-open starts at the selected photo (AC-07b)', (tester) async {
    await openFull(tester, select: 'p3');
    expect(onScreen(tester, large('p3')), isTrue);
  });

  testWidgets('with nothing selected it starts at the first photo (AC-07b)', (tester) async {
    await openFull(tester);
    expect(onScreen(tester, large('p0')), isTrue);
  });

  testWidgets('only the shown photo and its neighbours are decoded, at screen width', (tester) async {
    await openFull(tester, select: 'p3');
    final previews = find.descendant(
        of: find.byKey(PhotoPanel.largeBrowserKey), matching: find.byType(PhotoPreview));
    expect(previews.evaluate().length, inInclusiveRange(1, 3));
    expect(large('p0'), findsNothing);
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final e in previews.evaluate()) {
      expect((e.widget as PhotoPreview).width, screenWidth);
    }
  });

  testWidgets('a two-finger pinch zooms; a drag on the zoomed photo leaves the panel full-open',
      (tester) async {
    final host = await openFull(tester, select: 'p1');
    final center = tester.getCenter(large('p1'));
    // Fingers spread vertically, so the sideways pager does not claim them.
    final a = await tester.startGesture(center.translate(0, -20), pointer: 1);
    final b = await tester.startGesture(center.translate(0, 20), pointer: 2);
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await a.moveBy(const Offset(0, -20));
      await b.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    final viewer = tester.widget<InteractiveViewer>(large('p1'));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), greaterThan(1.2));

    await tester.drag(large('p1'), const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);
    expect(panelRect(tester).left, 0);
  });

  testWidgets('browsing does not change the selected photo; back in half-open the highlight stays',
      (tester) async {
    final host = await openFull(tester, select: 'p1');
    await tester.fling(large('p1'), const Offset(-400, 0), 2000);
    await tester.pumpAndSettle();
    expect(onScreen(tester, large('p2')), isTrue);
    expect(host.controller.selectedId, 'p1');

    host.controller.stepBack();
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
    expect(host.controller.selectedId, 'p1');
  });

  testWidgets('a tap on a large photo does nothing else (AC-07b)', (tester) async {
    final host = await openFull(tester, select: 'p2');
    await tester.tap(large('p2'));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);
    expect(host.controller.selectedId, 'p2');
    expect(host.selections, ['p2']);
  });

  testWidgets('an unreadable photo shows the placeholder large (AC-09)', (tester) async {
    await openFull(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.descendant(
          of: large('p0'),
          matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Photo not available')),
      findsOneWidget,
    );
  });
}
