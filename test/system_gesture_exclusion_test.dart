import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/services/system_gesture_exclusion.dart';

/// side-bar-for-main-screen T4: the photo tab's rectangle reaches Android over
/// `vocab/system_gesture_exclusion` in physical pixels; an empty list clears
/// it; platform errors are swallowed; nothing is sent off Android (spec AC-12,
/// ADR-0002).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('vocab/system_gesture_exclusion');
  late List<MethodCall> calls;
  late bool fail;

  setUp(() {
    calls = [];
    fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (fail) throw PlatformException(code: 'boom');
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('one call per setRects, in physical pixels', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = SystemGestureExclusion();
    await service.setRects(
      const [Rect.fromLTWH(350, 100, 40.4, 120)],
      devicePixelRatio: 2.5,
    );
    expect(calls, hasLength(1));
    expect(calls.single.method, 'setRects');
    expect(calls.single.arguments, [
      {'left': 875, 'top': 250, 'right': 976, 'bottom': 550},
    ]);
  });

  test('clear sends an empty list', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await SystemGestureExclusion().clear();
    expect(calls.single.method, 'setRects');
    expect(calls.single.arguments, isEmpty);
  });

  test('a PlatformException is swallowed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    fail = true;
    await expectLater(
      SystemGestureExclusion().setRects(const [Rect.fromLTWH(0, 0, 10, 10)], devicePixelRatio: 1),
      completes,
    );
    expect(calls, hasLength(1));
  });

  test('a missing handler (no native side) is swallowed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await expectLater(SystemGestureExclusion().clear(), completes);
  });

  test('nothing is sent off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await SystemGestureExclusion().setRects(const [Rect.fromLTWH(0, 0, 10, 10)], devicePixelRatio: 3);
    await SystemGestureExclusion().clear();
    expect(calls, isEmpty);
  });
}
