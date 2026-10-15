import 'package:arrowtapout/design/app_tokens.dart';
import 'package:flutter/material.dart';

/// A custom-painted flame icon drawn in the theme accent color.
/// Never uses emojis.
class StreakFlame extends StatelessWidget {
  const StreakFlame({
    super.key,
    this.size = 20.0,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final flameColor = color ?? tokens.accent;

    return CustomPaint(
      size: Size(size, size),
      painter: _StreakFlamePainter(color: flameColor),
    );
  }
}

class _StreakFlamePainter extends CustomPainter {
  const _StreakFlamePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer flame silhouette
    final path = Path();
    path.moveTo(w * 0.5, 0.0);
    // Right curve down
    path.cubicTo(w * 0.65, h * 0.25, w * 0.95, h * 0.5, w * 0.85, h * 0.78);
    path.cubicTo(w * 0.78, h * 0.95, w * 0.55, h * 1.0, w * 0.5, h * 1.0);
    path.cubicTo(w * 0.45, h * 1.0, w * 0.22, h * 0.95, w * 0.15, h * 0.78);
    path.cubicTo(w * 0.05, h * 0.5, w * 0.35, h * 0.25, w * 0.5, 0.0);
    path.close();

    // Inner teardrop core
    final core = Path();
    core.moveTo(w * 0.5, h * 0.45);
    core.cubicTo(w * 0.62, h * 0.6, w * 0.72, h * 0.75, w * 0.5, h * 0.92);
    core.cubicTo(w * 0.28, h * 0.75, w * 0.38, h * 0.6, w * 0.5, h * 0.45);
    core.close();

    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final corePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, outerPaint);
    canvas.drawPath(core, corePaint);
  }

  @override
  bool shouldRepaint(covariant _StreakFlamePainter oldDelegate) =>
      oldDelegate.color != color;
}
