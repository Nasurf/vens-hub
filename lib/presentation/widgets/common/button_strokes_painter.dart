import 'dart:math' as math;
import 'package:flutter/material.dart';

class ButtonStrokesPainter extends CustomPainter {
  final double? cornerRadius;
  final double? strokeWidth;
  final Color color;

  const ButtonStrokesPainter({
    this.cornerRadius,
    this.strokeWidth,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double r = math.min(cornerRadius ?? size.height / 2, size.height / 2);
    // For a pill, the side corners lie on semicircles centered at mid-height
    final Offset rightCenter = Offset(size.width - r, size.height / 2);
    final Offset leftCenter = Offset(r, size.height / 2);

    // Position the arc slightly inside the outer edge
    final double inset = r * 0.28;
    final double arcRadius = (r - inset).clamp(0.0, r);
    final double sw = (strokeWidth ?? (size.height * 0.05)).clamp(1.6, 2.6);

    final Paint strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round;

    // Arc parameters tuned to match reference
    const double startOffset = 0.30; // radians from the apex
    const double sweep = 0.92; // length of the arc segment

    // Top-right arc: around the right semicircle near its top
    final Rect trRect = Rect.fromCircle(center: rightCenter, radius: arcRadius);
    canvas.drawArc(
      trRect,
      -math.pi / 2 + startOffset,
      sweep,
      false,
      strokePaint,
    );

    // Bottom-left arc: around the left semicircle near its bottom
    final Rect blRect = Rect.fromCircle(center: leftCenter, radius: arcRadius);
    canvas.drawArc(
      blRect,
      math.pi / 2 + startOffset,
      sweep,
      false,
      strokePaint,
    );

    // Dot on the top-right arc a bit beyond its end
    final double dotAngle = -math.pi / 2 + startOffset + sweep + 0.08;
    final Offset dotPos = Offset(
      rightCenter.dx + arcRadius * math.cos(dotAngle),
      rightCenter.dy + arcRadius * math.sin(dotAngle),
    );
    final double dotR = sw * 0.8;
    final Paint dotPaint = Paint()..color = color;
    canvas.drawCircle(dotPos, dotR, dotPaint);
  }

  @override
  bool shouldRepaint(covariant ButtonStrokesPainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}
