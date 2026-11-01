import 'package:flutter/material.dart';

import '../../../core/theme/app_decor.dart';

/// How much of the width the current card takes; the rest shows the edges
/// of the cards before and after it (learn-flow-cards, owner 2026-11-01).
const flowViewportFraction = 0.86;

/// A [PageController] for [FlowPeekPager].
PageController flowPeekController() => PageController(viewportFraction: flowViewportFraction);

/// The Learn flow's pager (learn-flow-cards, owner 2026-11-01): each page is
/// a bordered card, with a slice of the card before and the card after it at
/// the sides, a little smaller and faded. Only [current] takes taps.
///
/// After the [count] pages comes one blank card, so the next card shows at
/// the side before the flow has picked it.
class FlowPeekPager extends StatelessWidget {
  const FlowPeekPager({
    super.key,
    required this.controller,
    required this.count,
    required this.current,
    required this.itemBuilder,
  });

  final PageController controller;
  final int count;
  final int current;
  final IndexedWidgetBuilder itemBuilder;

  /// How far page [i] is from the centre, 0 (centred) to 1 (or more).
  double _distance(int i) {
    final position = controller.hasClients && controller.position.haveDimensions
        ? controller.page ?? current.toDouble()
        : current.toDouble();
    return (position - i).abs().clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: PageView.builder(
        key: const ValueKey('flow-pager'),
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count + 1,
        itemBuilder: (context, i) => AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final d = _distance(i);
            return Opacity(
              opacity: 1 - 0.45 * d,
              child: Transform.scale(scale: 1 - 0.07 * d, child: child),
            );
          },
          child: IgnorePointer(
            ignoring: i != current,
            child: FlowCardFrame(
              key: ValueKey('flow-card-frame-$i'),
              child: i < count ? itemBuilder(context, i) : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// One page's card: the theme's card fill, border, corner and shadow.
class FlowCardFrame extends StatelessWidget {
  const FlowCardFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final radius = BorderRadius.circular(decor.wordRowRadius.clamp(0, 24).toDouble());
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 8, 5, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: decor.flowCard,
          borderRadius: radius,
          border: Border.all(color: decor.flowCardBorder),
          boxShadow: [BoxShadow(color: decor.flowCardShadow, blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          // The page draws its own safe area; the pager already keeps clear.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: child,
          ),
        ),
      ),
    );
  }
}
