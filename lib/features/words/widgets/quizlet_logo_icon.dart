import 'package:flutter/material.dart';

/// A plain "Q" drawn like Quizlet's logo mark: a round ring with a short
/// diagonal tail at the lower right. Takes its colour and size from the
/// surrounding [IconTheme], so in the + menu it is white like the other icons.
/// Drawn by hand: there is no Quizlet icon in Material and no new packages.
class QuizletLogoIcon extends StatelessWidget {
  const QuizletLogoIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    return Semantics(
      label: 'Quizlet',
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(
          painter: _QuizletQPainter(color ?? theme.color ?? Colors.white),
        ),
      ),
    );
  }
}

class _QuizletQPainter extends CustomPainter {
  _QuizletQPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.14
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final center = Offset(s * 0.46, s * 0.46);
    canvas.drawCircle(center, s * 0.30, paint);
    // The tail starts inside the ring and runs out past it.
    canvas.drawLine(Offset(s * 0.56, s * 0.58), Offset(s * 0.84, s * 0.88),
        paint);
  }

  @override
  bool shouldRepaint(_QuizletQPainter oldDelegate) =>
      oldDelegate.color != color;
}
