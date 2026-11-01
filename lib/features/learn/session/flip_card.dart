import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_decor.dart';

/// How long a card takes to turn over (learn-flow-cards, owner 2026-11-01).
const flipDuration = Duration(milliseconds: 540);

/// A card that turns over in 3D when [flipped] becomes true
/// (learn-flow-cards, owner 2026-11-01): it rotates about its vertical axis
/// with perspective, lifts a little at the half turn (a larger shadow) and
/// shows [back] from the half turn on, mirrored back so it reads the right
/// way round. Only one face is in the tree at a time.
///
/// [flipped] turning false turns it back to the front the same way (owner,
/// 2026-11-01). A new card gets a new key, so it starts on its front without
/// a turn. With animations off, the card shows the other face at once.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.flipped,
    required this.front,
    required this.back,
    this.onTap,
  });

  final bool flipped;
  final Widget front;
  final Widget back;

  /// A tap anywhere on the card (usually: flip it).
  final VoidCallback? onTap;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _turn =
      AnimationController(vsync: this, duration: flipDuration, value: widget.flipped ? 1 : 0);
  late final Animation<double> _eased = CurvedAnimation(parent: _turn, curve: Curves.easeInOutCubic);

  @override
  void didUpdateWidget(FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped == old.flipped) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _turn.value = widget.flipped ? 1 : 0;
    } else if (widget.flipped) {
      _turn.forward();
    } else {
      _turn.reverse();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final radius = BorderRadius.circular(decor.wordRowRadius.clamp(0, 20).toDouble());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _eased,
          builder: (context, _) {
            final t = _eased.value;
            final back = t >= 0.5;
            // The back is turned a half turn further, so it reads the right
            // way round once the card has turned over.
            final angle = math.pi * t + (back ? math.pi : 0);
            final lift = math.sin(math.pi * t);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle)
                ..scaleByDouble(1 + 0.05 * lift, 1 + 0.05 * lift, 1, 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: decor.panel,
                  borderRadius: radius,
                  border: Border.all(color: decor.panelBorder),
                  boxShadow: [
                    BoxShadow(
                      color: decor.flowCardShadow,
                      blurRadius: 6 + 18 * lift,
                      offset: Offset(0, 2 + 8 * lift),
                    ),
                  ],
                ),
                child: back ? widget.back : widget.front,
              ),
            );
          },
        ),
      ),
    );
  }
}
