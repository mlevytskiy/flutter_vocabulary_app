import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/widgets/layout_scale.dart';

/// LayoutScale (owner, 2026-10-19): every phone lays out as the 393 pt
/// iPhone 15/16; a narrower screen draws that layout scaled down, a wider one
/// is left alone.
void main() {
  test('only a screen narrower than the iPhone is scaled, by its short side',
      () {
    expect(layoutScaleFor(360), closeTo(360 / 393, 1e-9));
    expect(layoutScaleFor(393), 1);
    expect(layoutScaleFor(430), 1);
    expect(layoutScaleFor(0), 1);
  });

  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 24 * 3.0, bottom: 48 * 3.0);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => LayoutScale(child: child!),
      home: child,
    ));
  }

  testWidgets(
      'on a 360 dp phone the app sees the iPhone width and draws it scaled; '
      'taps land where it is drawn', (tester) async {
    late MediaQueryData seen;
    var taps = 0;
    await pumpAt(
      tester,
      const Size(360, 760),
      Builder(builder: (context) {
        seen = MediaQuery.of(context);
        return Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              key: const Key('b'),
              onPressed: () => taps++,
              icon: const Icon(Icons.add, key: Key('i'), size: 24),
            ),
          ),
        );
      }),
    );
    const scale = 360 / 393;
    expect(seen.size.width, closeTo(393, 1e-6));
    expect(seen.size.height, closeTo(760 / scale, 1e-6));
    expect(seen.devicePixelRatio, closeTo(3 * scale, 1e-9));
    expect(seen.padding.top, closeTo(24 / scale, 1e-6));
    // Logical size and real size times the pixel ratio agree.
    expect(seen.size.width * seen.devicePixelRatio, closeTo(360 * 3, 1e-6));

    // The 24 pt icon covers 24 * 360/393 of the real screen.
    final drawn = tester.getRect(find.byKey(const Key('i')));
    expect(drawn.width, closeTo(24 * scale, 1e-6));
    expect(drawn.right, lessThanOrEqualTo(360 + 1e-6));

    await tester.tap(find.byKey(const Key('b')));
    expect(taps, 1);
  });

  testWidgets('a screen at or above the iPhone width is left as it is',
      (tester) async {
    late MediaQueryData seen;
    await pumpAt(
      tester,
      const Size(430, 932),
      Builder(builder: (context) {
        seen = MediaQuery.of(context);
        return const Center(child: Icon(Icons.add, key: Key('i'), size: 24));
      }),
    );
    expect(seen.size, const Size(430, 932));
    expect(seen.devicePixelRatio, 3);
    expect(tester.getSize(find.byKey(const Key('i'))).width, 24);
  });
}
