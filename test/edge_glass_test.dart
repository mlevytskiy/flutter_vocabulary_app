import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/edge_glass.dart';
import 'package:flutter_vocabulary_app/features/word_input/photo_panel/looks/look_a.dart';

/// Look A's glass sticks to the screen edge: rounded corners on the inner
/// side, concave flares that run into the edge above and below.
void main() {
  group('edgeGlassPath', () {
    const size = Size(100, 200);
    // The screen edge at x = 80, the box from y = 40 to 160.
    final path = edgeGlassPath(size, edge: 80, top: 40, bottom: 160, radius: 16, flare: 14);

    test('the box is glass, but not its rounded inner corners', () {
      expect(path.contains(const Offset(40, 100)), isTrue);
      expect(path.contains(const Offset(79, 41)), isTrue);
      expect(path.contains(const Offset(1, 41)), isFalse, reason: 'top inner corner is round');
      expect(path.contains(const Offset(1, 159)), isFalse, reason: 'bottom inner corner is round');
    });

    test('above and below, concave flares hug the edge and fade into it', () {
      // The blend's fillet: sqrt(x) + sqrt(y) = sqrt(flare), x from the edge,
      // y from the box.
      expect(path.contains(const Offset(79, 38)), isTrue, reason: 'flare above, at the edge');
      expect(path.contains(const Offset(79, 162)), isTrue, reason: 'flare below, at the edge');
      expect(path.contains(const Offset(74, 34)), isFalse, reason: 'concave, not a square corner');
      expect(path.contains(const Offset(79, 40 - 15)), isFalse, reason: 'ends after the flare');
      expect(path.contains(const Offset(60, 39)), isFalse, reason: 'only near the edge');
    });
  });

  group('EdgeGlass', () {
    testWidgets('the glass reaches past the box for the flares and takes no touches',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Stack(children: [
          Positioned(
            right: 0,
            top: 100,
            width: 52,
            height: 120,
            child: EdgeGlass(
              settings: const LiquidGlassSettings(),
              radius: 16,
              flare: 14,
              child: GestureDetector(
                key: const Key('content'),
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
          ),
        ]),
      ));
      final content = tester.getRect(find.byKey(const Key('content')));
      expect(content, const Rect.fromLTWH(800 - 52, 100, 52, 120), reason: 'child fills the box');
      final glass = tester.getRect(find.byType(IgnorePointer).last);
      expect(glass.top, lessThan(content.top - 14), reason: 'room for the flare above');
      expect(glass.bottom, greaterThan(content.bottom + 14), reason: 'and below');
      expect(glass.right, greaterThan(800), reason: 'past the screen edge');

      await tester.tapAt(content.center);
      expect(taps, 1);
    });
  });

  group('look A', () {
    const look = LookA();

    testWidgets('the tab stands on edge glass', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => look.buildTab(context,
              photos: const [], preview: (_, __) => const SizedBox()),
        ),
      ));
      expect(find.byType(EdgeGlass), findsOneWidget);
    });

    testWidgets('half-open stands on edge glass; full-open is dark', (tester) async {
      Widget panel(double fullness) => MaterialApp(
            home: Builder(
              builder: (context) => SizedBox(
                width: look.halfOpenWidth,
                height: 400,
                child: look.buildPanelSurface(context,
                    fullness: fullness, child: const Text('content')),
              ),
            ),
          );

      await tester.pumpWidget(panel(0));
      expect(find.byType(EdgeGlass), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      expect(find.ancestor(of: find.text('content'), matching: find.byType(Material)),
          findsWidgets,
          reason: 'the controls get their ink');

      await tester.pumpWidget(panel(1));
      expect(find.byType(EdgeGlass), findsNothing);
      expect(tester.widgetList<ColoredBox>(find.byType(ColoredBox)).map((b) => b.color),
          contains(Colors.black));
    });
  });
}
