import 'dart:async';

import 'package:flutter/material.dart';

/// How long a picture takes to fly into the recycle-bin button.
const flyToBinDuration = Duration(milliseconds: 550);

/// Flies [child] from [from] (global) into the point [to] (global) on the
/// overlay: along a curve that lifts first, shrinking and fading as it lands.
/// Completes when it has landed; the picture is gone by then.
Future<void> flyToBin(
  BuildContext context, {
  required Rect from,
  required Offset to,
  required Widget child,
}) {
  final landed = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flight(
      from: from,
      to: to,
      onLanded: () {
        entry.remove();
        landed.complete();
      },
      child: child,
    ),
  );
  Overlay.of(context).insert(entry);
  return landed.future;
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.from,
    required this.to,
    required this.onLanded,
    required this.child,
  });

  final Rect from;
  final Offset to;
  final VoidCallback onLanded;
  final Widget child;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: flyToBinDuration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onLanded();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.from.center;
    final end = widget.to;
    // The curve's bend sits above the higher of the two points, so the
    // picture lifts out of the grid before it drops into the button.
    final control = Offset(
      (start.dx + end.dx) / 2,
      (start.dy < end.dy ? start.dy : end.dy) - 80,
    );
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInCubic.transform(_c.value);
          final u = 1 - t;
          // A quadratic Bézier from start through control to end.
          final p = start * (u * u) + control * (2 * u * t) + end * (t * t);
          final scale = 1 - 0.75 * t;
          final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3 * 0.7;
          return Stack(children: [
            Positioned(
              left: p.dx - widget.from.width / 2,
              top: p.dy - widget.from.height / 2,
              width: widget.from.width,
              height: widget.from.height,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          ]);
        },
        child: widget.child,
      ),
    );
  }
}
