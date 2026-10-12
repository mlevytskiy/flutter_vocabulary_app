import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_a.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';

import 'photo_panel_test_host.dart';

/// A look that hides the tab while the list scrolls.
class _HidingLook extends LookA {
  const _HidingLook();
  @override
  bool get hidesTabWhileScrolling => true;
}

/// side-bar-for-main-screen T7: where the photo tab sits and how it moves
/// (spec AC-01, AC-02, AC-14, AC-17).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no photo with words draws nothing (AC-02)', (tester) async {
    final host = PanelHost(photos: const []);
    await host.pump(tester);
    expect(tabFinder, findsNothing);
  });

  testWidgets('the tab sits on the right side, beside the first rows (AC-01)', (tester) async {
    await PanelHost().pump(tester);
    final page = pageRect(tester);
    final tab = tabRect(tester);
    expect(tab.right, page.right);
    expect(tab.top, page.top + PhotoTabTopNotifier.firstDefault);
    // Not in a corner: clear of the top bar.
    expect(tab.top, greaterThan(page.top));
  });

  testWidgets('a vertical drag moves the tab, and the height is kept after a restart (AC-14)',
      (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    final before = tabRect(tester);
    await tester.drag(tabFinder, const Offset(0, 120));
    await tester.pumpAndSettle();
    final after = tabRect(tester);
    expect(after.top, closeTo(before.top + 120, 1));
    expect(host.controller.stop, PanelStop.closed);

    // A restart: a fresh ProviderScope reads the kept value.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(PanelHost().build(key: UniqueKey()));
    await PanelHost.settleLoads(tester);
    expect(tabRect(tester).top, closeTo(after.top, 1));
  });

  testWidgets('a diagonal drag goes by its main direction', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    final start = tabRect(tester).top;

    // Mainly down: moves the tab, never opens the panel.
    await tester.drag(tabFinder, const Offset(-30, 90));
    await tester.pumpAndSettle();
    expect(tabRect(tester).top, closeTo(start + 90, 1));
    expect(host.controller.stop, PanelStop.closed);
  });

  testWidgets('the tab stays put while the list scrolls (AC-01)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    final before = tabRect(tester);
    await tester.drag(find.text('row 3'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(host.scroll.offset, greaterThan(0));
    expect(tabRect(tester), before);
  });

  testWidgets('the tab rides above the keyboard and returns when it closes (AC-01)',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final host = PanelHost(bottomReserve: 80);
    await host.pump(tester);
    await tester.drag(tabFinder, const Offset(0, 300));
    await tester.pumpAndSettle();
    final kept = tabRect(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final keyboardTop = tester.view.physicalSize.height / tester.view.devicePixelRatio - 300;
    expect(tabRect(tester).bottom, lessThanOrEqualTo(keyboardTop));

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tabRect(tester), kept);
  });

  testWidgets('the tab stays between the top bar and the floating buttons (AC-01, AC-14)',
      (tester) async {
    SharedPreferences.setMockInitialValues({'flutter.photo_tab_top': 5000.0});
    final host = PanelHost(bottomReserve: 120);
    await host.pump(tester);
    final page = pageRect(tester);
    expect(tabRect(tester).bottom, lessThanOrEqualTo(page.bottom - 120));

    await tester.drag(tabFinder, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tabRect(tester).top, greaterThanOrEqualTo(page.top));
  });

  testWidgets('a touch on the tab is ignored while the screen is busy (AC-17)', (tester) async {
    final host = PanelHost(busy: true);
    await host.pump(tester);
    final before = tabRect(tester);
    await tester.tap(tabFinder);
    await tester.drag(tabFinder, const Offset(0, 100));
    await tester.drag(tabFinder, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tabRect(tester), before);
    expect(host.controller.stop, PanelStop.closed);
    // The row under the tab gets nothing either (AC-14).
    expect(host.tappedRows, isEmpty);
  });

  testWidgets('a tap on the tab never reaches the row under it (AC-14)', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pump();
    expect(host.tappedRows, isEmpty);
  });

  testWidgets('a look that hides the tab while scrolling fades it, then shows it again',
      (tester) async {
    final host = PanelHost(look: const _HidingLook());
    await host.pump(tester);
    double opacity() => tester
        .widget<AnimatedOpacity>(
            find.ancestor(of: tabFinder, matching: find.byType(AnimatedOpacity)).first)
        .opacity;
    expect(opacity(), 1);

    final gesture = await tester.startGesture(tester.getCenter(find.text('row 3')));
    await gesture.moveBy(const Offset(0, -60));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(opacity(), 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('a look that does not hide keeps the tab while scrolling', (tester) async {
    final host = PanelHost();
    await host.pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('row 3')));
    await gesture.moveBy(const Offset(0, -60));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(
            find.ancestor(of: tabFinder, matching: find.byType(AnimatedOpacity)).first).opacity,
        1);
    await gesture.up();
  });
}
