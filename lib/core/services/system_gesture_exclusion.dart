import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tells Android which parts of the screen edge the app keeps for itself, so
/// a drag that starts on the photo tab is not taken as the Back gesture
/// (side-bar-for-main-screen ADR-0002, spec AC-12). `MainActivity` sets the
/// window's gesture exclusion rectangles on Android 10 and later.
///
/// Never throws, and does nothing off Android.
class SystemGestureExclusion {
  static const _channel = MethodChannel('vocab/system_gesture_exclusion');

  /// Replaces the excluded areas with [rects], given in logical pixels of the
  /// whole screen and sent in physical pixels, rounded outward.
  Future<void> setRects(List<Rect> rects, {required double devicePixelRatio}) =>
      _send([
        for (final r in rects)
          {
            'left': (r.left * devicePixelRatio).floor(),
            'top': (r.top * devicePixelRatio).floor(),
            'right': (r.right * devicePixelRatio).ceil(),
            'bottom': (r.bottom * devicePixelRatio).ceil(),
          },
      ]);

  /// No area excluded: every edge swipe is system Back again.
  Future<void> clear() => _send(const []);

  Future<void> _send(List<Map<String, int>> rects) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setRects', rects);
    } catch (e) {
      debugPrint('VOCAB: photo panel: gesture exclusion not set: $e');
    }
  }
}
