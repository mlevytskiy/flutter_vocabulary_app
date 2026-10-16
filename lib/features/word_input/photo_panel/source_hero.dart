import 'package:flutter/material.dart';

/// The hero that carries one source's picture between the half-open photo
/// panel and the Notes page (owner, 2026-10-15). Both sides wrap the
/// source's picture in it with the same [id].
///
/// The flight always draws the panel's small picture ([small] true): its
/// photo is already read and decoded, so nothing blinks in on the way; the
/// Notes page's own, larger decode takes over when the flight lands.
class SourceHero extends StatelessWidget {
  const SourceHero({
    super.key,
    required this.id,
    required this.child,
    this.small = false,
  });

  final String id;
  final Widget child;

  /// This is the panel's side of the flight.
  final bool small;

  static Object tag(String id) => 'source-hero-$id';

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = fromHeroContext.widget as Hero;
    final to = toHeroContext.widget as Hero;
    final picture = from.child is _SmallSide ? from.child : to.child;
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: picture);
  }

  @override
  Widget build(BuildContext context) => Hero(
        tag: tag(id),
        flightShuttleBuilder: _shuttle,
        child: small ? _SmallSide(child: child) : child,
      );
}

/// Marks the panel's side of a [SourceHero], so the flight can pick it.
class _SmallSide extends StatelessWidget {
  const _SmallSide({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The share of the screen's width one Notes page takes; its neighbours
/// peek in at the sides.
const notesPageFraction = 0.74;

/// The logical width a source's picture is drawn at on the Notes page, for
/// a screen [screenWidth] wide: the panel decodes photos at it ahead.
double notesPictureWidth(double screenWidth) =>
    screenWidth * notesPageFraction - 12;
