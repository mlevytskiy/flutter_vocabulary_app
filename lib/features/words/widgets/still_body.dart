import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Holds the main screen's body as one picture while the side menu is on
/// screen, sliding or open.
///
/// A frame of the menu's slide then draws the body from that picture instead
/// of again from scratch; in Aurora, from scratch means the frosted blur
/// behind every word row, which Android GPUs did not finish in a frame while
/// the menu moved (owner, 2026-10-18). What is seen is the same: the body does
/// not change under the menu's scrim, and the picture has the device's pixels.
/// Android only; iOS draws the live body as before.
///
/// [StillBody] wraps the body; [StillBodyWhileMounted] goes inside the
/// Scaffold's `drawer`. The Scaffold builds the drawer's child only from the
/// first frame the menu appears (a tap on the menu button, or the first pixel
/// of an edge drag) until it is fully away again, so the child's life is
/// exactly the time the body should hold still. Nothing else is involved: no
/// timer, no guess at the slide's length.
class StillBody extends StatelessWidget {
  const StillBody({super.key, required this.controller, required this.child});

  final SnapshotController controller;
  final Widget child;

  /// Overrides whether the body is held still (Android); tests only.
  @visibleForTesting
  static bool? debugEnabled;

  static bool get enabled =>
      debugEnabled ?? defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) => SnapshotWidget(
        controller: controller,
        // A platform view in the body would only turn the picture off.
        mode: SnapshotMode.permissive,
        // The keyboard may come or go while the menu is open.
        autoresize: true,
        child: child,
      );
}

/// Holds the [StillBody] with the same [controller] still for as long as this
/// widget is in the tree: see [StillBody].
class StillBodyWhileMounted extends StatefulWidget {
  const StillBodyWhileMounted(
      {super.key, required this.controller, required this.child});

  final SnapshotController controller;
  final Widget child;

  @override
  State<StillBodyWhileMounted> createState() => _StillBodyWhileMountedState();
}

class _StillBodyWhileMountedState extends State<StillBodyWhileMounted> {
  @override
  void initState() {
    super.initState();
    if (StillBody.enabled) widget.controller.allowSnapshotting = true;
  }

  @override
  void didUpdateWidget(StillBodyWhileMounted old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.allowSnapshotting = false;
      if (StillBody.enabled) widget.controller.allowSnapshotting = true;
    }
  }

  @override
  void dispose() {
    // The drawer's child goes before the screen that owns the controller.
    widget.controller.allowSnapshotting = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
