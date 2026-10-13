import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  group('simple glass while the panel slides (Android)', () {
    tearDown(() => EdgeGlass.debugLiquidSupported = null);

    Widget glass({required bool simple}) => MaterialApp(
          home: SimpleGlassScope(
            simple: simple,
            child: const Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 52,
                height: 120,
                child: EdgeGlass(
                    settings: LiquidGlassSettings(), radius: 16, flare: 14),
              ),
            ),
          ),
        );

    /// The opacity of the liquid glass and of its frosted stand-in.
    (double, double) shown(WidgetTester tester) {
      final liquid = tester.widget<Opacity>(find
          .ancestor(of: find.byType(LiquidGlassLayer), matching: find.byType(Opacity))
          .first);
      final frosted = tester.renderObject<RenderAnimatedOpacity>(find
          .ancestor(of: find.byType(BackdropFilter), matching: find.byType(AnimatedOpacity))
          .first);
      return (liquid.opacity, frosted.opacity.value);
    }

    testWidgets('on Android the frosted glass stands in, then fades back to liquid',
        variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      await tester.pumpWidget(glass(simple: false));
      expect(shown(tester), (1.0, 0.0), reason: 'at rest: liquid');

      await tester.pumpWidget(glass(simple: true));
      expect(shown(tester), (0.0, 1.0), reason: 'sliding: frosted at once');

      await tester.pumpWidget(glass(simple: false));
      await tester.pump(const Duration(milliseconds: 100));
      final (liquid, frosted) = shown(tester);
      expect(liquid, 1.0, reason: 'liquid back underneath');
      expect(frosted, inExclusiveRange(0.0, 1.0), reason: 'frosted fading out');
      await tester.pumpAndSettle();
      expect(shown(tester), (1.0, 0.0));
      expect(find.byType(LiquidGlassLayer), findsOneWidget,
          reason: 'one liquid glass all along, never rebuilt');
    });

    testWidgets('elsewhere the liquid glass stays',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      await tester.pumpWidget(glass(simple: true));
      expect(shown(tester), (1.0, 0.0));
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
                    fullness: fullness,
                    halfOpenAt: Offset.zero,
                    halfOpenSize: Size(look.halfOpenWidth, 400),
                    child: const Text('content')),
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
