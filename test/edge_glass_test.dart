import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import 'package:flutter_vocabulary_app/features/words/photo_panel/looks/edge_glass.dart';
import 'package:flutter_vocabulary_app/features/words/photo_panel/looks/look_a.dart';

/// Look A's glass sticks to the screen edge: rounded corners on the inner
/// side, concave flares that run into the edge above and below.
/// The liquid glass reads the Words settings' Liquid glass sliders.
Future<void> pumpIn(WidgetTester tester, Widget app) =>
    tester.pumpWidget(ProviderScope(child: app));

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
      await pumpIn(tester, MaterialApp(
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

  group('which glass', () {
    tearDown(() => EdgeGlass.debugLiquidSupported = null);

    Widget glass() => const MaterialApp(
          home: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 52,
              height: 120,
              child: EdgeGlass(settings: LiquidGlassSettings(), radius: 16, flare: 14),
            ),
          ),
        );

    testWidgets('Android always draws the frosted blur, never the liquid glass',
        variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      await pumpIn(tester, glass());
      expect(find.byType(LiquidGlassLayer), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('iOS draws the liquid glass where shaders work',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      await pumpIn(tester, glass());
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
    });

    testWidgets('the liquid glass gets a hairline outline, seen over light rows',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      await pumpIn(tester, glass());
      final outlined = find.byWidgetPredicate((w) =>
          w is CustomPaint && '${w.foregroundPainter.runtimeType}' == '_Hairline');
      expect(outlined, findsOneWidget);
    });
  });

  group('frosted where the liquid glass is not drawn', () {
    tearDown(() => EdgeGlass.debugLiquidSupported = null);

    Widget glass() => const MaterialApp(
          home: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 52,
              height: 120,
              child: EdgeGlass(settings: LiquidGlassSettings(), radius: 16, flare: 14),
            ),
          ),
        );

    Finder hairline() => find.byWidgetPredicate((w) =>
        w is CustomPaint && '${w.foregroundPainter.runtimeType}' == '_Hairline');

    testWidgets('iOS without shaders: frosted, outlined like the liquid glass',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      EdgeGlass.debugLiquidSupported = false;
      await pumpIn(tester, glass());
      expect(find.byType(LiquidGlassLayer), findsNothing);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(hairline(), findsOneWidget, reason: 'its edge seen over light rows');
    });

    testWidgets('Android keeps its frosted glass as it was, with no hairline',
        variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      await pumpIn(tester, glass());
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(hairline(), findsNothing);
    });
  });

  group('the liquid glass on a scaled-down layout', () {
    tearDown(() => EdgeGlass.debugLiquidSupported = null);

    testWidgets(
        "gets the screen's own pixel ratio, not LayoutScale's smaller one "
        "(a second, offset glass on the owner's 375 pt iPhone)",
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      await pumpIn(tester, MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            // What LayoutScale says on a 375 pt phone.
            data: MediaQuery.of(context).copyWith(
                devicePixelRatio: tester.view.devicePixelRatio * 375 / 393),
            child: const Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 52,
                height: 120,
                child: EdgeGlass(settings: LiquidGlassSettings(), radius: 16, flare: 14),
              ),
            ),
          ),
        ),
      ));
      final glass = tester.element(find.byType(LiquidGlassLayer));
      expect(MediaQuery.devicePixelRatioOf(glass), tester.view.devicePixelRatio);
    });
  });

  group('look A', () {
    const look = LookA();

    testWidgets('the tab is liquid glass on iOS',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      addTearDown(() => EdgeGlass.debugLiquidSupported = null);
      await pumpIn(tester, MaterialApp(
        home: Builder(
          builder: (context) => look.buildTab(context,
              photos: const [], preview: (_, __) => const SizedBox()),
        ),
      ));
      expect(find.byType(LiquidGlassLayer), findsOneWidget);
    });

    testWidgets('the tab stands on edge glass', (tester) async {
      await pumpIn(tester, MaterialApp(
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

      await pumpIn(tester, panel(0));
      expect(find.byType(EdgeGlass), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      expect(find.ancestor(of: find.text('content'), matching: find.byType(Material)),
          findsWidgets,
          reason: 'the controls get their ink');

      await pumpIn(tester, panel(1));
      expect(find.byType(EdgeGlass), findsNothing);
      expect(tester.widgetList<ColoredBox>(find.byType(ColoredBox)).map((b) => b.color),
          contains(Colors.black));
    });
  });
}
