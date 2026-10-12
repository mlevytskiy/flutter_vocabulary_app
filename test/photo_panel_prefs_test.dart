import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';

/// side-bar-for-main-screen T3: the photo tab's height survives a restart and
/// is clamped on use; the review-only design variant keeps the chosen value in
/// memory even when the write fails (spec AC-01, AC-14, AC-19; sad §8).
///
/// The preferences channel is mocked by hand (not `setMockInitialValues`) so a
/// test can make writes fail.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  late Map<String, Object> stored;
  late bool failWrites;

  setUp(() {
    stored = {};
    failWrites = false;
    SharedPreferences.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method.startsWith('getAll')) return Map<String, Object>.of(stored);
      if (call.method.startsWith('set')) {
        if (failWrites) throw PlatformException(code: 'disk-full');
        final args = call.arguments as Map;
        stored[args['key'] as String] = args['value'] as Object;
        return true;
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<double> topAfterLoad(ProviderContainer c) async {
    c.read(photoTabTopProvider);
    await c.read(photoTabTopProvider.notifier).loaded;
    return c.read(photoTabTopProvider);
  }

  Future<PhotoPanelVariant> variantAfterLoad(ProviderContainer c) async {
    c.read(photoPanelVariantProvider);
    await c.read(photoPanelVariantProvider.notifier).loaded;
    return c.read(photoPanelVariantProvider);
  }

  group('photo_tab_top', () {
    test('no stored value gives the first default, beside the first word rows', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await topAfterLoad(c), PhotoTabTopNotifier.firstDefault);
      // Beside the first rows: inside the list's first ~two rows, below its 16 px padding.
      expect(PhotoTabTopNotifier.firstDefault, inInclusiveRange(16, 120));
    });

    test('a dragged height is read back after a restart', () async {
      final first = ProviderContainer();
      await topAfterLoad(first);
      await first.read(photoTabTopProvider.notifier).set(310.5);
      expect(first.read(photoTabTopProvider), 310.5);
      first.dispose();
      expect(stored['flutter.photo_tab_top'], 310.5);

      SharedPreferences.resetStatic();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(await topAfterLoad(second), 310.5);
    });

    test('a failed write keeps the dragged height in memory', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await topAfterLoad(c);
      failWrites = true;
      await c.read(photoTabTopProvider.notifier).set(200);
      expect(c.read(photoTabTopProvider), 200);
    });

    test('clamp keeps the tab below the top bar and above the floating buttons', () {
      expect(PhotoTabTopNotifier.clamp(-40, min: 0, max: 500), 0);
      expect(PhotoTabTopNotifier.clamp(250, min: 0, max: 500), 250);
      expect(PhotoTabTopNotifier.clamp(900, min: 0, max: 500), 500);
      // A screen too short for the tab: the top bar wins.
      expect(PhotoTabTopNotifier.clamp(100, min: 20, max: 10), 20);
    });
  });

  group('photo_panel_variant (until the pick)', () {
    test('defaults to a, and an unknown stored value falls back to a', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await variantAfterLoad(c), PhotoPanelVariant.a);

      stored['flutter.photo_panel_variant'] = 'zzz';
      SharedPreferences.resetStatic();
      final d = ProviderContainer();
      addTearDown(d.dispose);
      expect(await variantAfterLoad(d), PhotoPanelVariant.a);
    });

    test('the chosen variant survives a restart', () async {
      final first = ProviderContainer();
      await variantAfterLoad(first);
      await first.read(photoPanelVariantProvider.notifier).set(PhotoPanelVariant.c);
      first.dispose();

      SharedPreferences.resetStatic();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(await variantAfterLoad(second), PhotoPanelVariant.c);
    });

    test('a failed write keeps the chosen variant in memory', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await variantAfterLoad(c);
      failWrites = true;
      await c.read(photoPanelVariantProvider.notifier).set(PhotoPanelVariant.b);
      expect(c.read(photoPanelVariantProvider), PhotoPanelVariant.b);
    });
  });
}
