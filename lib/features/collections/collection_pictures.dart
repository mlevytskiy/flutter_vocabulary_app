import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The Collections screen's pictures, drawn from the owner's Stitch design
/// ("Collections - Unified Text Icon with Badges", 2026-10-16): the SVG paths
/// on its 48x48 grid, painted directly because the app has no SVG package.

/// The pictures' shades come from the theme (app-themes): [AppDecor.pic50]
/// to [AppDecor.pic600], lightest to darkest, on [AppDecor.picPaper]. In
/// Classic they are the owner's violet, built around the Settings button's
/// `0xff954ef3` (2026-10-16). A theme with [AppDecor.picOutline] draws them
/// as outlines only, like a wireframe.

/// How a collection's document is outlined: plain, or darker for the current
/// collection. How many sources it has does not change it (owner, 2026-10-16).
enum DocumentLook { plain, current }

/// Where a collection's words came from, as a corner badge.
enum SourceBadge { quizlet, movie, image }

/// A collection's document picture, 48x48 by default.
class DocumentPicture extends StatelessWidget {
  const DocumentPicture(
      {super.key, this.look = DocumentLook.plain, this.size = 48});

  final DocumentLook look;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size),
      painter: _DocumentPainter(look, AppDecor.of(context)));
}

/// A folder's picture, 48x48 by default.
class FolderPicture extends StatelessWidget {
  const FolderPicture({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size.square(size), painter: _FolderPainter(AppDecor.of(context)));
}

/// One corner badge: Q in a circle, a clapperboard on the theme's colour, or
/// a picture frame. 16 wide; the movie badge is 14 high, the others 16.
class SourceBadgePicture extends StatelessWidget {
  const SourceBadgePicture(this.badge, {super.key});

  final SourceBadge badge;

  @override
  Widget build(BuildContext context) {
    final d = AppDecor.of(context);
    // An outline theme keeps every badge on paper, with its colour as ink.
    final movieFill = d.picOutline ? d.picPaper : d.pic500;
    final movieInk = d.picOutline ? d.pic500 : d.picPaper;
    switch (badge) {
      case SourceBadge.quizlet:
        return Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: d.picPaper,
            shape: BoxShape.circle,
            border: Border.all(color: d.pic500),
          ),
          child: Text(
            'Q',
            style: TextStyle(
              fontSize: 8.5,
              height: 1,
              fontWeight: FontWeight.w700,
              color: d.pic600,
            ),
          ),
        );
      case SourceBadge.movie:
        return Container(
          width: 16,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: movieFill,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: d.picOutline ? d.pic500 : d.picPaper),
          ),
          child: CustomPaint(
              size: const Size.square(10),
              painter: _GlyphPainter(_movieGlyph, movieInk)),
        );
      case SourceBadge.image:
        return Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: d.picPaper,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: d.pic500),
          ),
          child: CustomPaint(
              size: const Size.square(10),
              painter: _GlyphPainter(_imageGlyph, d.pic600)),
        );
    }
  }
}

Paint _stroke(Color color, double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..strokeWidth = width
  ..color = color;

class _DocumentPainter extends CustomPainter {
  const _DocumentPainter(this.look, this.d);

  final DocumentLook look;
  final AppDecor d;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final current = look == DocumentLook.current;
    final outline = d.picOutline;
    final edge = switch (look) {
      DocumentLook.plain => outline ? d.pic500 : d.pic200,
      DocumentLook.current => d.pic600,
    };
    final edgeWidth = switch (look) {
      DocumentLook.plain => 1.5,
      DocumentLook.current => 1.8,
    };
    const r = Radius.circular(3.5);
    // The sheet behind.
    final back = RRect.fromRectAndRadius(const Rect.fromLTWH(11, 7, 26, 34), r);
    if (outline) {
      canvas.drawRRect(back, _stroke(d.pic200, 1.2));
    } else {
      canvas.drawRRect(
        back,
        Paint()
          ..color = (current ? d.pic200 : d.pic100)
              .withValues(alpha: current ? 0.9 : 0.7),
      );
    }
    // The front sheet.
    final front = RRect.fromRectAndRadius(const Rect.fromLTWH(9, 9, 26, 34), r);
    canvas.drawRRect(front, Paint()..color = d.picPaper);
    canvas.drawRRect(front, _stroke(edge, edgeWidth));
    // The text lines.
    final lines = _stroke(
        current ? d.pic600 : d.pic500, current ? 2 : 1.75);
    for (final (y, w) in const [
      (16.0, 16.0),
      (21.0, 16.0),
      (26.0, 12.0),
      (31.0, 8.0)
    ]) {
      canvas.drawLine(Offset(14, y), Offset(14 + w, y), lines);
    }
    // The folded corner: its outline, then its fill.
    canvas.drawPath(
      Path()
        ..moveTo(28, 9)
        ..lineTo(28, 14)
        ..arcToPoint(const Offset(30, 16),
            radius: const Radius.circular(2), clockwise: false)
        ..lineTo(35, 16),
      _stroke(current || outline ? edge : d.pic200, current ? 1.8 : 1.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(28, 9)
        ..lineTo(35, 16)
        ..lineTo(30, 16)
        ..arcToPoint(const Offset(28, 14), radius: const Radius.circular(2))
        ..close(),
      Paint()
        ..color = outline
            ? d.picPaper
            : current
                ? d.pic200
                : d.pic50,
    );
  }

  @override
  bool shouldRepaint(_DocumentPainter old) => old.look != look || old.d != d;
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter(this.d);

  final AppDecor d;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final outline = d.picOutline;
    // The back with its tab.
    final back = Path()
      ..moveTo(8, 14)
      ..cubicTo(8, 12.3431, 9.34315, 11, 11, 11)
      ..lineTo(19.1716, 11)
      ..cubicTo(20.2324, 11, 21.2499, 11.4214, 22, 12.1716)
      ..lineTo(24.8284, 15)
      ..lineTo(37, 15)
      ..cubicTo(38.6569, 15, 40, 16.3431, 40, 18)
      ..lineTo(40, 34)
      ..cubicTo(40, 35.6569, 38.6569, 37, 37, 37)
      ..lineTo(11, 37)
      ..cubicTo(9.34315, 37, 8, 35.6569, 8, 34)
      ..close();
    canvas.drawPath(back, outline ? _stroke(d.pic200, 1.5) : (Paint()..color = d.pic200));
    // The paper inside.
    final paper = RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 15, 24, 12), const Radius.circular(2));
    if (outline) {
      canvas.drawRRect(paper, _stroke(d.pic500.withValues(alpha: 0.6), 1));
    } else {
      canvas.drawRRect(paper, Paint()..color = d.picPaper.withValues(alpha: 0.9));
    }
    // The front.
    final front = RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 16, 32, 21), const Radius.circular(3));
    if (outline) {
      canvas.drawRRect(front, Paint()..color = d.picPaper);
      canvas.drawRRect(front, _stroke(d.pic500, 1.6));
      // A scan line across the front, as on an old monitor.
      canvas.drawLine(const Offset(12, 27), const Offset(36, 27),
          _stroke(d.pic500.withValues(alpha: 0.45), 1));
      return;
    }
    canvas.drawRRect(front, Paint()..color = d.pic500);
    // The light along the front's top edge.
    canvas.drawPath(
      Path()
        ..moveTo(11, 16)
        ..lineTo(37, 16)
        ..cubicTo(38.6569, 16, 40, 17.3431, 40, 19)
        ..lineTo(40, 20)
        ..cubicTo(40, 18.3431, 38.6569, 17, 37, 17)
        ..lineTo(11, 17)
        ..cubicTo(9.34315, 17, 8, 18.3431, 8, 20)
        ..lineTo(8, 19)
        ..cubicTo(8, 17.3431, 9.34315, 16, 11, 16)
        ..close(),
      Paint()..color = d.pic100.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_FolderPainter old) => old.d != d;
}

/// A badge glyph on a 16x16 grid, filled even-odd so its cut-outs stay open.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final Path Function() glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 16);
    canvas.drawPath(
        glyph()..fillType = PathFillType.evenOdd, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color;
}

const _r1 = Radius.circular(1);
const _r15 = Radius.circular(1.5);
const _r2 = Radius.circular(2);

/// A clapperboard: the striped top, then the board.
Path _movieGlyph() => Path()
  ..moveTo(0, 4.5)
  ..arcToPoint(const Offset(1.5, 3), radius: _r15)
  ..lineTo(14.5, 3)
  ..arcToPoint(const Offset(16, 4.5), radius: _r15)
  ..lineTo(16, 5)
  ..lineTo(0, 5)
  ..close()
  ..moveTo(0, 6)
  ..lineTo(16, 6)
  ..lineTo(16, 13)
  ..arcToPoint(const Offset(14.5, 14.5), radius: _r15)
  ..lineTo(1.5, 14.5)
  ..arcToPoint(const Offset(0, 13), radius: _r15)
  ..close()
  ..moveTo(2, 3.5)
  ..lineTo(3.5, 5)
  ..lineTo(5, 5)
  ..lineTo(3.5, 3.5)
  ..close()
  ..moveTo(6, 3.5)
  ..lineTo(7.5, 5)
  ..lineTo(9, 5)
  ..lineTo(7.5, 3.5)
  ..close()
  ..moveTo(10, 3.5)
  ..lineTo(11.5, 5)
  ..lineTo(13, 5)
  ..lineTo(11.5, 3.5)
  ..close();

/// A picture frame with two hills and a sun.
Path _imageGlyph() => Path()
  ..moveTo(2, 2)
  ..arcToPoint(const Offset(0, 4), radius: _r2, clockwise: false)
  ..lineTo(0, 12)
  ..arcToPoint(const Offset(2, 14), radius: _r2, clockwise: false)
  ..lineTo(14, 14)
  ..arcToPoint(const Offset(16, 12), radius: _r2, clockwise: false)
  ..lineTo(16, 4)
  ..arcToPoint(const Offset(14, 2), radius: _r2, clockwise: false)
  ..close()
  ..moveTo(14, 3)
  ..arcToPoint(const Offset(15, 4), radius: _r1)
  ..lineTo(15, 9.5)
  ..lineTo(11.75, 6.25)
  ..arcToPoint(const Offset(10.336, 6.25), radius: _r1, clockwise: false)
  ..lineTo(6, 10.586)
  ..lineTo(4.172, 8.758)
  ..arcToPoint(const Offset(2.758, 8.758), radius: _r1, clockwise: false)
  ..lineTo(1, 10.516)
  ..lineTo(1, 4)
  ..arcToPoint(const Offset(2, 3), radius: _r1)
  ..close()
  ..moveTo(5.5, 5)
  ..arcToPoint(const Offset(5.5, 8), radius: _r15, largeArc: true)
  ..arcToPoint(const Offset(5.5, 5), radius: _r15)
  ..close();
