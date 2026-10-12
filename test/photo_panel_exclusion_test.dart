import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';

import 'photo_panel_test_host.dart';

/// side-bar-for-main-screen T10: the rectangle Android keeps out of the Back
/// gesture always matches what is on screen (spec AC-12, ADR-0002).
void main() {
  const channel = MethodChannel('vocab/system_gesture_exclusion');
  late List<List<Rect>> sent;
  late double dpr;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      sent.add([
        for (final m in (call.arguments as List).cast<Map>())
          Rect.fromLTRB(
            (m['left'] as int) / dpr,
            (m['top'] as int) / dpr,
            (m['right'] as int) / dpr,
            (m['bottom'] as int) / dpr,
          ),
      ]);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void expectSent(Rect expected) {
    expect(sent.last, hasLength(1));
    final r = sent.last.single;
    // Rounded outward to whole physical pixels.
    expect(r.left, closeTo(expected.left, 1));
    expect(r.top, closeTo(expected.top, 1));
    expect(r.right, closeTo(expected.right, 1));
    expect(r.bottom, closeTo(expected.bottom, 1));
  }

  testWidgets('closed sends the tab rectangle, again after a move, and only on change',
      (tester) async {
    dpr = tester.view.devicePixelRatio;
    final host = PanelHost();
    await host.pump(tester);
    await tester.pumpAndSettle();
    expectSent(tabRect(tester));

    final calls = sent.length;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(sent.length, calls, reason: 'nothing changed, nothing sent');

    await tester.drag(tabFinder, const Offset(0, 150));
    await tester.pumpAndSettle();
    expectSent(tabRect(tester));
  });

  testWidgets('half-open sends the handle, full-open clears it, closing sends the tab again',
      (tester) async {
    dpr = tester.view.devicePixelRatio;
    final host = PanelHost();
    await host.pump(tester);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    expect(host.controller.stop, PanelStop.halfOpen);
    expectSent(tester.getRect(find.byKey(PhotoPanel.handleKey)));

    await tester.tap(find.byKey(PhotoPanel.expandKey));
    await tester.pumpAndSettle();
    expect(sent.last, isEmpty);

    host.controller.close();
    await tester.pumpAndSettle();
    expectSent(tabRect(tester));
  });

  testWidgets('a layout change (keyboard) resends the moved tab', (tester) async {
    dpr = tester.view.devicePixelRatio;
    final host = PanelHost();
    await host.pump(tester);
    await tester.drag(tabFinder, const Offset(0, 350));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expectSent(tabRect(tester));
  });

  testWidgets('no photo with words left clears it; so does leaving the screen', (tester) async {
    dpr = tester.view.devicePixelRatio;
    final host = PanelHost();
    await host.pump(tester);
    await tester.pumpAndSettle();
    expect(sent.last, isNotEmpty);

    host.photos.value = const [];
    await tester.pumpAndSettle();
    expect(tabFinder, findsNothing);
    expect(sent.last, isEmpty);

    host.photos.value = fakePhotos(2);
    await tester.pumpAndSettle();
    expectSent(tabRect(tester));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(sent.last, isEmpty);
  });

  testWidgets('a session with no photo with words never excludes anything', (tester) async {
    dpr = tester.view.devicePixelRatio;
    final host = PanelHost(photos: const []);
    await host.pump(tester);
    await tester.pumpAndSettle();
    expect(sent.where((r) => r.isNotEmpty), isEmpty);
  });
}
