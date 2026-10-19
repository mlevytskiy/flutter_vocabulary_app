import 'package:flutter/widgets.dart';

/// The layout width every phone gets: the iPhone 15/16's 393 pt (owner,
/// 2026-10-19). A narrower screen (a 360 dp Android) would otherwise give an
/// icon or a line of text the same logical size on less room, so it looked
/// bigger there than on the iPhone.
const layoutWidth = 393.0;

/// How much [LayoutScale] shrinks a screen whose short side is [shortestSide]:
/// below [width] to match it, never enlarged above it (owner, 2026-10-19).
double layoutScaleFor(double shortestSide, {double width = layoutWidth}) =>
    shortestSide <= 0 || shortestSide >= width ? 1 : shortestSide / width;

/// Lays [child] out as on a [layoutWidth]-wide screen and draws it scaled to
/// the real one, so icons, text, spacing and taps keep the iPhone's
/// proportions on a narrower phone. The short side decides, so turning the
/// phone keeps the same scale.
///
/// The [MediaQuery] below says the scaled size, insets and pixel ratio, so
/// the keyboard inset, the safe areas and image sizes stay right in the
/// scaled space; [FittedBox] maps paint and hit tests between the two.
class LayoutScale extends StatelessWidget {
  const LayoutScale({super.key, required this.child, this.width = layoutWidth});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = layoutScaleFor(media.size.shortestSide, width: width);
    if (scale == 1) return child;
    final size = media.size / scale;
    return MediaQuery(
      data: media.copyWith(
        size: size,
        devicePixelRatio: media.devicePixelRatio * scale,
        padding: media.padding / scale,
        viewPadding: media.viewPadding / scale,
        viewInsets: media.viewInsets / scale,
        systemGestureInsets: media.systemGestureInsets / scale,
      ),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );
  }
}
