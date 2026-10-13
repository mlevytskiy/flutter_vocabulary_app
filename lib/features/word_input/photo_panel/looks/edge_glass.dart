import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Glass that sticks to the screen's right edge (photo panel look A).
///
/// It fills its box, whose right side is the screen edge: rounded corners of
/// [radius] on the inner (left) side, and above and below the box concave
/// flares [flare] long that run into the edge, like a drop stuck to a wall.
/// The flares paint outside the box (over the top bar, for a tab at the top)
/// and never take touches. [child] is laid out in the box, on the glass.
///
/// On Impeller the glass is `liquid_glass_renderer`'s: the box's glass and an
/// unseen wall just past the edge melt together in one blend group, and the
/// blend draws the flares. Elsewhere (Skia, widget tests) [edgeGlassPath]
/// draws the same outline with a frosted blur: the blend's fillet is exactly
/// a quadratic curve with its control point in the corner.
class EdgeGlass extends StatelessWidget {
  const EdgeGlass({
    super.key,
    required this.settings,
    required this.radius,
    required this.flare,
    this.child,
  });

  final LiquidGlassSettings settings;
  final double radius;
  final double flare;
  final Widget? child;

  /// How far the glass reaches past the screen edge, so the box's right
  /// corners are never seen.
  double get _past => radius + 8;

  /// The wall runs this far past the box, so its ends are out of the blend's
  /// reach and only the flares show.
  double get _over => 2 * flare;

  @override
  Widget build(BuildContext context) {
    final glass = LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final path = edgeGlassPath(size,
          edge: size.width - _past,
          top: _over,
          bottom: size.height - _over,
          radius: radius,
          flare: flare);
      // On Impeller the package draws the rim itself.
      final liquid = ui.ImageFilter.isShaderFilterSupported;
      return CustomPaint(
        painter: _Light(path, settings, shadow: true),
        foregroundPainter:
            liquid ? null : _Light(path, settings, shadow: false),
        child: liquid ? _liquid(size) : _frosted(size, path),
      );
    });
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: -_past,
          top: -_over,
          bottom: -_over,
          child: IgnorePointer(child: glass),
        ),
        if (child != null) child!,
      ],
    );
  }

  /// The box's glass and the wall past the edge, blended into one shape.
  Widget _liquid(Size size) {
    final edge = size.width - _past;
    return LiquidGlassLayer(
      settings: settings,
      child: LiquidGlassBlendGroup(
        blend: flare,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: _over,
              bottom: _over,
              child: LiquidGlass.grouped(
                shape: LiquidRoundedRectangle(borderRadius: radius),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: edge,
              right: 0,
              top: 0,
              bottom: 0,
              child: const LiquidGlass.grouped(
                shape: LiquidRoundedRectangle(borderRadius: 0),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The same outline as a frosted blur with a tint and a rim.
  Widget _frosted(Size size, Path path) {
    final blur = settings.effectiveBlur;
    return ClipPath(
      clipper: _PathClipper(path),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: CustomPaint(
          painter: _Tint(path, settings.effectiveGlassColor),
          size: size,
        ),
      ),
    );
  }
}

/// The glass's outline in its own box: the screen edge at x = [edge], the
/// box from y = [top] to [bottom] and from x = 0, inner corners of [radius],
/// and concave flares [flare] long along the edge above and below. It closes
/// past the edge, at the box's right side.
Path edgeGlassPath(
  Size size, {
  required double edge,
  required double top,
  required double bottom,
  required double radius,
  required double flare,
}) {
  final r = Radius.circular(radius);
  return Path()
    ..moveTo(edge, top - flare)
    ..quadraticBezierTo(edge, top, edge - flare, top)
    ..lineTo(radius, top)
    ..arcToPoint(Offset(0, top + radius), radius: r, clockwise: false)
    ..lineTo(0, bottom - radius)
    ..arcToPoint(Offset(radius, bottom), radius: r, clockwise: false)
    ..lineTo(edge - flare, bottom)
    ..quadraticBezierTo(edge, bottom, edge, bottom + flare)
    // Back up past the screen edge, so the rim along the edge is unseen.
    ..lineTo(size.width, bottom + flare)
    ..lineTo(size.width, top - flare)
    ..close();
}

class _PathClipper extends CustomClipper<Path> {
  _PathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClipper oldClipper) => oldClipper.path != path;
}

class _Tint extends CustomPainter {
  _Tint(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(path, Paint()..color = color);

  @override
  bool shouldRepaint(_Tint old) => old.path != path || old.color != color;
}

/// With [shadow], the soft shadow under the glass; without, the light rim
/// along its outline, drawn over it.
class _Light extends CustomPainter {
  _Light(this.path, this.settings, {required this.shadow});

  final Path path;
  final LiquidGlassSettings settings;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final light = settings.effectiveLightIntensity.clamp(0.0, 1.0);
    if (shadow) {
      canvas.drawPath(
          path.shift(const Offset(0, 5)),
          Paint()
            ..color = Color.fromRGBO(58, 29, 110, 0.2 * light)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      return;
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: light),
              const Color(0xFF9F86D8).withValues(alpha: 0.75 * light),
              Colors.white.withValues(alpha: 0.8 * light),
            ],
          ).createShader(path.getBounds()));
  }

  @override
  bool shouldRepaint(_Light old) =>
      old.path != path || old.settings != settings || old.shadow != shadow;
}
