import 'package:flutter/material.dart';

import '../../../core/theme/app_decor.dart';

/// How much of the width the current card takes; the rest shows the edges
/// of the cards before and after it (learn-flow-cards, owner 2026-11-01).
const flowViewportFraction = 0.86;

/// A [PageController] for [FlowPeekPager].
PageController flowPeekController() => PageController(viewportFraction: flowViewportFraction);

/// The Learn flow's pager (learn-flow-cards, owner 2026-11-01): each page is
/// a bordered card, with a slice of the card before and the card after it at
/// the sides, a little smaller and faded. Only the centred page takes taps.
///
/// After the [count] pages comes one blank card, so the next card shows at
/// the side before the flow has picked it.
///
/// A swipe moves back over the pages seen and forward again (owner,
/// 2026-11-01). The flow alone adds the next page ([FlowSwipePhysics] stops
/// the drag at [current]); a swipe forward past [current] calls
/// [onSwipePast], which moves the flow on (a card skipped unrated, a story
/// seen), and the pager then slides to the page it adds.
class FlowPeekPager extends StatelessWidget {
  const FlowPeekPager({
    super.key,
    required this.controller,
    required this.count,
    required this.current,
    required this.itemBuilder,
    required this.limit,
    this.onSwipePast,
  });

  final PageController controller;
  final int count;
  final int current;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onSwipePast;

  /// Kept by the screen across builds ([FlowSwipePhysics]).
  final FlowSwipeLimit limit;

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
      child: NotificationListener<OverscrollNotification>(
        onNotification: (n) {
          // Dragged on past the last page by the learner's finger.
          if (n.overscroll > 0 && n.dragDetails != null && n.depth == 0) onSwipePast?.call();
          return false;
        },
        child: PageView.builder(
          key: const ValueKey('flow-pager'),
          controller: controller,
          physics: FlowSwipePhysics(limit: limit..lastPage = current),
          itemCount: count + 1,
          itemBuilder: (context, i) => AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final d = _distance(i);
              return IgnorePointer(
                ignoring: d > 0.5,
                child: Opacity(
                  opacity: 1 - 0.45 * d,
                  child: Transform.scale(scale: 1 - 0.07 * d, child: child),
                ),
              );
            },
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

/// Page physics that stop a drag at [FlowSwipeLimit.lastPage]: the pages after it (the
/// blank next card) cannot be reached by a swipe, and the drag past it is
/// reported as overscroll. A page the flow adds moves the limit on.
class FlowSwipePhysics extends PageScrollPhysics {
  const FlowSwipePhysics({required this.limit, super.parent});

  /// Read on every move: a [Scrollable] keeps the physics it started with
  /// while their type stays the same, so the last page cannot be a field.
  final FlowSwipeLimit limit;

  @override
  FlowSwipePhysics applyTo(ScrollPhysics? ancestor) => FlowSwipePhysics(limit: limit, parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final last = limit.lastPage * position.viewportDimension * flowViewportFraction;
    if (value > last && value > position.pixels) {
      return value - (position.pixels > last ? position.pixels : last);
    }
    return super.applyBoundaryConditions(position, value);
  }
}

/// The last page a swipe may reach ([FlowSwipePhysics]); [FlowPeekPager]
/// moves it to its `current` page on every build.
class FlowSwipeLimit {
  int lastPage = 0;
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
