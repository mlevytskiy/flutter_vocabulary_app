import 'package:flutter/material.dart';

/// The Collections screen's pictures, drawn from the owner's Stitch design
/// ("Collections - Unified Text Icon with Badges", 2026-10-16): the SVG paths
/// on its 48x48 grid, painted directly because the app has no SVG package.

/// The pictures' shades, built around the Settings button's violet
/// (`0xff954ef3`, [_violet500]) — warmer than Stitch's indigo, picked by the
/// owner 2026-10-16. Lightest to darkest.
const _violet50 = Color(0xfff6effe);
const _violet100 = Color(0xffeee2fd);
const _violet200 = Color(0xffdcc4fb);
const _violet500 = Color(0xff954ef3);
const _violet600 = Color(0xff7c3ad6);

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
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _DocumentPainter(look));
}

/// A folder's picture, 48x48 by default.
class FolderPicture extends StatelessWidget {
  const FolderPicture({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _FolderPainter());
}

/// One corner badge: Q in a circle, a white clapperboard on violet, or a
/// picture frame. 16 wide; the movie badge is 14 high, the others 16.
class SourceBadgePicture extends StatelessWidget {
  const SourceBadgePicture(this.badge, {super.key});

  final SourceBadge badge;

  @override
  Widget build(BuildContext context) {
    switch (badge) {
      case SourceBadge.quizlet:
        return Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _violet500),
          ),
          child: const Text(
            'Q',
            style: TextStyle(
              fontSize: 8.5,
              height: 1,
              fontWeight: FontWeight.w700,
              color: _violet600,
            ),
          ),
        );
      case SourceBadge.movie:
        return Container(
          width: 16,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _violet500,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white),
          ),
          child: const CustomPaint(
              size: Size.square(10),
              painter: _GlyphPainter(_movieGlyph, Colors.white)),
        );
      case SourceBadge.image:
        return Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: _violet500),
          ),
          child: const CustomPaint(
              size: Size.square(10),
              painter: _GlyphPainter(_imageGlyph, _violet600)),
        );
    }
  }
}

class _DocumentPainter extends CustomPainter {
  const _DocumentPainter(this.look);

  final DocumentLook look;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    final current = look == DocumentLook.current;
    final edge = switch (look) {
      DocumentLook.plain => _violet200,
      DocumentLook.current => _violet600,
    };
    final edgeWidth = switch (look) {
      DocumentLook.plain => 1.5,
      DocumentLook.current => 1.8,
    };
    const r = Radius.circular(3.5);
    // The sheet behind.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(11, 7, 26, 34), r),
      Paint()
        ..color = (current ? _violet200 : _violet100)
            .withValues(alpha: current ? 0.9 : 0.7),
    );
    // The front sheet.
    final front = RRect.fromRectAndRadius(const Rect.fromLTWH(9, 9, 26, 34), r);
    canvas.drawRRect(front, Paint()..color = Colors.white);
    canvas.drawRRect(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..color = edge,
    );
    // The text lines.
    final lines = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = current ? 2 : 1.75
      ..color = current ? _violet600 : _violet500;
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
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = current ? 1.8 : 1.5
        ..color = current ? _violet600 : _violet200,
    );
    canvas.drawPath(
      Path()
        ..moveTo(28, 9)
        ..lineTo(35, 16)
        ..lineTo(30, 16)
        ..arcToPoint(const Offset(28, 14), radius: const Radius.circular(2))
        ..close(),
      Paint()..color = current ? _violet200 : _violet50,
    );
  }

  @override
  bool shouldRepaint(_DocumentPainter old) => old.look != look;
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    // The back with its tab.
    canvas.drawPath(
      Path()
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
        ..close(),
      Paint()..color = _violet200,
    );
    // The paper inside.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, 15, 24, 12), const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    // The front.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 16, 32, 21), const Radius.circular(3)),
      Paint()..color = _violet500,
    );
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
      Paint()..color = _violet100.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_FolderPainter old) => false;
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
