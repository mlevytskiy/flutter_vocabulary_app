import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// The shared page's "+ Add a word" button in the app: bold blue text in a
/// 1 px dashed outline (notes-editing, owner 2026-10-15; the page's `.add`
/// style in vocab-photo-api/src/session/style.ts).
class DashedAddButton extends StatelessWidget {
  const DashedAddButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  static const color = Color(0xFF2962FF);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: CustomPaint(
          painter: const _DashedOutline(color: color, radius: 6),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: const TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ),
      );
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color || old.radius != radius;
}
