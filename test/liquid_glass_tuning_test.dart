import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/words/photo_panel/looks/edge_glass.dart';
import 'package:flutter_vocabulary_app/features/settings/settings_screen.dart';

/// liquid-glass-tuning (owner, 2026-10-19): the Words settings' Liquid glass
/// sliders scale the photo tab's and the half-open panel's liquid glass.
void main() {
  const base = LiquidGlassSettings(thickness: 16, blur: 3, refractiveIndex: 1.25);

  group('tunedGlass', () {
    test('100% is the look as designed', () {
      final t = tunedGlass(base, LiquidGlassTuningNotifier.asDesigned);
      expect(t.thickness, 16);
      expect(t.blur, 3);
      expect(t.refractiveIndex, closeTo(1.25, 1e-9));
    });

    test('thickness and blur scale; bending scales the index above 1', () {
      final t = tunedGlass(base, (thickness: 2.5, bending: 2.5, blur: 0.0));
      expect(t.thickness, 40);
      expect(t.blur, 0);
      expect(t.refractiveIndex, closeTo(1.625, 1e-9));
    });

    test('no bending stays a hair above 1, so the edge light keeps a direction', () {
      final t = tunedGlass(base, (thickness: 1.0, bending: 0.0, blur: 1.0));
      expect(t.refractiveIndex, greaterThan(1));
      expect(t.refractiveIndex, lessThan(1.01));
    });
  });

  group('LiquidGlassTuningNotifier', () {
    Future<ProviderContainer> loaded(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(liquidGlassTuningProvider);
      await c.read(liquidGlassTuningProvider.notifier).loaded;
      return c;
    }

    test('starts at 100% with nothing stored', () async {
      final c = await loaded({});
      expect(c.read(liquidGlassTuningProvider), LiquidGlassTuningNotifier.asDesigned);
    });

    test('reads the stored values, kept inside the ranges', () async {
      final c = await loaded({
        LiquidGlassTuningNotifier.thicknessKey: 2.5,
        LiquidGlassTuningNotifier.bendingKey: 9.0,
        LiquidGlassTuningNotifier.blurKey: 0.0,
      });
      expect(c.read(liquidGlassTuningProvider), (thickness: 2.5, bending: 3.0, blur: 0.0));
    });

    test('a change is saved, and Reset goes back to 100%', () async {
      final c = await loaded({});
      final n = c.read(liquidGlassTuningProvider.notifier);
      await n.set((thickness: 2.0, bending: 1.5, blur: 0.5));
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(LiquidGlassTuningNotifier.thicknessKey), 2.0);
      expect(prefs.getDouble(LiquidGlassTuningNotifier.bendingKey), 1.5);
      expect(prefs.getDouble(LiquidGlassTuningNotifier.blurKey), 0.5);

      await n.reset();
      expect(c.read(liquidGlassTuningProvider), LiquidGlassTuningNotifier.asDesigned);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(LiquidGlassTuningNotifier.thicknessKey), 1.0);
    });
  });

  group('the glass follows the sliders', () {
    tearDown(() => EdgeGlass.debugLiquidSupported = null);

    testWidgets('the liquid glass takes the tuned settings',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      SharedPreferences.setMockInitialValues({});
      EdgeGlass.debugLiquidSupported = true;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
                width: 52,
                height: 120,
                child: EdgeGlass(settings: base, radius: 16, flare: 14)),
          ),
        ),
      ));
      LiquidGlassSettings shown() =>
          tester.widget<LiquidGlassLayer>(find.byType(LiquidGlassLayer)).settings;
      expect(shown().thickness, 16);

      await c
          .read(liquidGlassTuningProvider.notifier)
          .set((thickness: 2.5, bending: 2.5, blur: 0.0));
      await tester.pump();
      expect(shown().thickness, 40);
      expect(shown().blur, 0);
      expect(shown().refractiveIndex, closeTo(1.625, 1e-9));
    });
  });

  group('Settings (the Words screen\'s round settings button)', () {
    tearDown(() => EdgeGlass.debugLiquidSupported = null);

    Future<ProviderContainer> pump(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('where the glass is liquid: Thickness, Bending, Blur and Reset',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      final c = await pump(tester);
      expect(find.text('Liquid glass'), findsOneWidget);
      for (final label in ['Thickness', 'Bending', 'Blur']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('100%'), findsNWidgets(3));
      final reset = find.widgetWithText(TextButton, 'Reset');
      expect(tester.widget<TextButton>(reset).onPressed, isNull, reason: 'already 100%');

      await tester.drag(find.byType(Slider).first, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(c.read(liquidGlassTuningProvider).thickness, greaterThan(1));
      expect(tester.widget<TextButton>(reset).onPressed, isNotNull);

      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(c.read(liquidGlassTuningProvider), LiquidGlassTuningNotifier.asDesigned);
      expect(find.text('100%'), findsNWidgets(3));
    });

    testWidgets('not on Android, whose glass is always frosted',
        variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      EdgeGlass.debugLiquidSupported = true;
      await pump(tester);
      expect(find.text('Liquid glass'), findsNothing);
    });
  });
}
