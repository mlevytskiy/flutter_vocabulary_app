import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_a.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';

import 'photo_panel_test_host.dart';

/// side-bar-for-main-screen T8: opening half-open and full-open, settling at
/// the stops, and stepping back (spec AC-03, AC-07, AC-08, AC-10; QG-2a).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const halfWidth = 112.0; // LookA().halfOpenWidth

  test('the tests assume look A', () => expect(const LookA().halfOpenWidth, halfWidth));

  testWidgets('a tap settles half-open within 300 ms, small photos oldest first (AC-03, QG-2a)',
      (tester) async {
    final host = PanelHost(photos: fakePhotos(3));
    await host.pump(tester);
    expect(panelFinder, findsNothing);

    await tester.tap(tabFinder);
    // 300 ms from the tap: the first frame after it, then the rest.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 284));
    expect(host.controller.stop, PanelStop.halfOpen);
    final page = pageRect(tester);
    final half = Rect.fromLTRB(page.right - halfWidth, page.top, page.right, page.bottom);
    expect(panelRect(tester), half);
    // Settled: it does not move any more.
    await tester.pump(const Duration(milliseconds: 200));
    expect(panelRect(tester), half);

    final tops = [for (final id in ['p0', 'p1', 'p2']) tester.getRect(smallPhoto(id)).top];
    expect(tops, orderedEquals([...tops]..sort()));
    // The word rows stay visible beside it.
    expect(find.text('row 3').hitTestable(), findsOneWidget);
  });

  testWidgets('opening closes the keyboard and keeps what was typed (AC-03)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(find.byKey(const Key('host-field')));
    await tester.pump();
    expect(host.fieldFocus.hasFocus, isTrue);

    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    expect(host.fieldFocus.hasFocus, isFalse);
    expect(host.field.text, 'half-typed');
  });

  testWidgets('a short drag to the left settles half-open (AC-03)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.drag(tabFinder, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
  });

  testWidgets('a longer drag to the left settles full-open, covering the rows (AC-07)',
      (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.drag(tabFinder, const Offset(-520, 0));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);
    expect(panelRect(tester).left, 0);
    expect(find.text('row 3').hitTestable(), findsNothing);
  });

  testWidgets('a flick from closed moves one stop only (AC-08)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.fling(tabFinder, const Offset(-300, 0), 3000);
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);

    await tester.fling(find.byKey(PhotoPanel.handleKey), const Offset(-80, 0), 3000);
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);
  });

  testWidgets('the expand control opens full-open (AC-07)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);
  });

  testWidgets('the small photos grow into the large one on the way to full-open (AC-07)',
      (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final growing = tester.getRect(find.byKey(PhotoPanel.growingPhotoKey));
    await tester.pump(const Duration(milliseconds: 60));
    final grown = tester.getRect(find.byKey(PhotoPanel.growingPhotoKey));
    expect(grown.width, greaterThan(growing.width));
    await tester.pumpAndSettle();
    expect(find.byKey(PhotoPanel.growingPhotoKey), findsNothing);
  });

  testWidgets('a drag back on the handle settles by the rule (AC-08, AC-10)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();

    // A short drag back from full-open: half-open.
    await tester.drag(find.byKey(PhotoPanel.handleKey), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);

    // Back to full-open, then a long drag back closes it.
    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    final handle = tester.getCenter(find.byKey(PhotoPanel.handleKey));
    await tester.dragFrom(handle.translate(-300, 0), const Offset(790, 0));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.closed);
    expect(panelFinder, findsNothing);
    expect(tabFinder, findsOneWidget);
  });

  testWidgets('stepBack goes full-open → half-open → closed (AC-10)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.drag(tabFinder, const Offset(-520, 0));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.fullOpen);

    host.controller.stepBack();
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
    expect(panelRect(tester).width, halfWidth);

    host.controller.stepBack();
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.closed);
    expect(panelFinder, findsNothing);
  });

  testWidgets('the close control closes half-open', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PhotoPanel.closeKey));
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.closed);
  });

  testWidgets('tapping a small photo selects it; again clears it (AC-04, AC-05)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    await tester.tap(smallPhoto('p1'));
    await tester.pump();
    expect(host.controller.selectedId, 'p1');
    await tester.tap(smallPhoto('p2'));
    await tester.pump();
    await tester.tap(smallPhoto('p2'));
    await tester.pump();
    expect(host.controller.selectedId, isNull);
    expect(host.selections, ['p1', 'p2', null]);
  });
}
