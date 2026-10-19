import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';

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
///
/// Android always draws the frosted glass: many Android GPUs cannot draw the
/// liquid glass over the word rows in a frame while either moves (owner,
/// 2026-10-13).
///
/// Off Android the frosted glass, like the liquid one, shows its shadow only
/// outside the outline and a hairline on it, so it reads as one glass with
/// its edge seen all round.
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

  /// Overrides whether the liquid glass can be drawn (Impeller); tests only.
  @visibleForTesting
  static bool? debugLiquidSupported;

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Whether the liquid glass is drawn here: where shaders can be drawn,
  /// and not on Android. Elsewhere the frosted glass is.
  static bool get liquidDrawn => _liquid;

  static bool get _liquid =>
      !_android &&
      (debugLiquidSupported ?? ui.ImageFilter.isShaderFilterSupported);

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
      final decor = AppDecor.of(context);
      if (_liquid) {
        // The Words settings' Liquid glass sliders (liquid-glass-tuning).
        return Consumer(builder: (context, ref, _) {
          final tuned =
              tunedGlass(settings, ref.watch(liquidGlassTuningProvider));
          return CustomPaint(
            // Clear glass: a shadow seen through it reads as a second glass
            // 5 pt below, so it shows only outside the outline.
            painter: _Light(path, tuned, decor,
                shadow: true, outsideOnly: true),
            // The package lights only the edges facing its light, in the
            // colour of what is behind them, so over light rows the outline
            // fades away; this hairline keeps it seen all round.
            foregroundPainter: _Hairline(path, decor.glassEdge),
            child: _liquidGlass(context, size, tuned),
          );
        });
      }
      if (_android) {
        return CustomPaint(
          painter: _Light(path, settings, decor, shadow: true),
          child: _frosted(context, size, path),
        );
      }
      // The frosted glass blurs what is under it, its own shadow too, which
      // then reads as a second glass 5 pt below: as on the liquid glass, the
      // shadow shows only outside the outline, and the hairline keeps the
      // edge seen over light rows.
      return CustomPaint(
        painter: _Light(path, settings, decor, shadow: true, outsideOnly: true),
        foregroundPainter: _Hairline(path, decor.glassEdge),
        child: _frosted(context, size, path),
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
  ///
  /// The package turns where the glass is on the screen into the screen's
  /// pixels with the pixel ratio it reads from [MediaQuery]. On a phone
  /// narrower than 393 pt, `LayoutScale` draws the app scaled down and says
  /// a smaller ratio there, so the glass was drawn scaled towards the
  /// screen's top-left corner, away from its outline: a second, offset
  /// glass (owner's iPhone, 2026-10-19). The package gets the screen's own
  /// ratio.
  Widget _liquidGlass(
      BuildContext context, Size size, LiquidGlassSettings settings) {
    final edge = size.width - _past;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(devicePixelRatio: View.of(context).devicePixelRatio),
      child: _liquidLayer(size, edge, settings),
    );
  }

  Widget _liquidLayer(Size size, double edge, LiquidGlassSettings settings) {
    return LiquidGlassLayer(
      settings: settings,
      // Its own backdrop read: a shared one left the iOS glass flatter.
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

  /// The same outline as a frosted blur with a tint and a rim: no shader,
  /// so far cheaper to draw than the liquid glass.
  Widget _frosted(BuildContext context, Size size, Path path) {
    final blur = settings.effectiveBlur;
    return CustomPaint(
      foregroundPainter:
          _Light(path, settings, AppDecor.of(context), shadow: false),
      child: ClipPath(
        clipper: _PathClipper(path),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          // One backdrop read with the other glass under the same group.
          backdropGroupKey: BackdropGroup.of(context)?.backdropKey,
          child: CustomPaint(
            painter: _Tint(path, settings.effectiveGlassColor),
            size: size,
          ),
        ),
      ),
    );
  }
}

/// [base] with the Words settings' Liquid glass sliders applied: the
/// thickness and the blur scaled, and the refractive index's part above 1
/// (how far the edge bends) scaled. It stays a hair above 1, as with no
/// bending at all the package's edge light has no direction.
LiquidGlassSettings tunedGlass(LiquidGlassSettings base, LiquidGlassTuning t) =>
    base.copyWith(
      thickness: base.thickness * t.thickness,
      refractiveIndex:
          math.max(1.001, 1 + (base.refractiveIndex - 1) * t.bending),
      blur: base.blur * t.blur,
    );

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

/// The liquid glass's outline: a thin line in the theme's glass edge colour.
class _Hairline extends CustomPainter {
  _Hairline(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.55));

  @override
  bool shouldRepaint(_Hairline old) => old.path != path || old.color != color;
}

/// With [shadow], the soft shadow under the glass; without, the light rim
/// along its outline, drawn over it.
class _Light extends CustomPainter {
  _Light(this.path, this.settings, this.decor,
      {required this.shadow, this.outsideOnly = false});

  final AppDecor decor;

  final Path path;
  final LiquidGlassSettings settings;
  final bool shadow;

  /// The shadow is clipped to outside [path].
  final bool outsideOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final light = settings.effectiveLightIntensity.clamp(0.0, 1.0);
    if (shadow) {
      if (outsideOnly) {
        canvas.clipPath(Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(path.getBounds().inflate(40))
          ..addPath(path, Offset.zero));
      }
      canvas.drawPath(
          path.shift(const Offset(0, 5)),
          Paint()
            ..color = decor.glassShadow.withValues(alpha: 0.2 * light)
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
              decor.glassEdge.withValues(alpha: 0.75 * light),
              Colors.white.withValues(alpha: 0.8 * light),
            ],
          ).createShader(path.getBounds()));
  }

  @override
  bool shouldRepaint(_Light old) =>
      old.path != path ||
      old.settings != settings ||
      old.shadow != shadow ||
      old.outsideOnly != outsideOnly;
}

