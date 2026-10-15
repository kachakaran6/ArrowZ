import 'dart:math' as math;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:flutter/material.dart';

/// The raised console plate housing the board.
///
/// Features:
/// - Surface color, radius 28, 1 dp hairline in line.
/// - Inner padding 16 dp.
/// - Soft inner top highlight.
/// - Edge pulse on chain milestones (5, 10, 15).
/// - 500 ms accent perimeter sweep on level complete.
class BoardPlate extends StatelessWidget {
  const BoardPlate({
    super.key,
    required this.child,
    this.chainPulseProgress = 0.0,
    this.completeSweepProgress = 0.0,
  });

  final Widget child;
  final double chainPulseProgress; // 0.0 to 1.0
  final double completeSweepProgress; // 0.0 to 1.0

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(Primitives.radius28);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: radius,
        border: Border.all(
          color: chainPulseProgress > 0.0
              ? Color.lerp(tokens.line, tokens.accent, chainPulseProgress)!
              : tokens.line,
          width: chainPulseProgress > 0.0 ? 1.5 + chainPulseProgress * 0.5 : 1.0,
        ),
        boxShadow: [
          if (chainPulseProgress > 0.0)
            BoxShadow(
              color: tokens.accent.withValues(alpha: 0.3 * chainPulseProgress),
              blurRadius: 16.0 * chainPulseProgress,
              spreadRadius: 1.0,
            ),
          // Subtle ambient elevation
          BoxShadow(
            color: tokens.bg.withValues(alpha: tokens.isDark ? 0.6 : 0.06),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner top highlight
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.25],
                    colors: [
                      tokens.ink.withValues(alpha: tokens.isDark ? 0.05 : 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Board content with inner padding 16
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),

          // Level complete 500ms perimeter sweep
          if (completeSweepProgress > 0.0)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: CustomPaint(
                  painter: _PerimeterSweepPainter(
                    progress: completeSweepProgress,
                    color: tokens.accent,
                    radius: Primitives.radius28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PerimeterSweepPainter extends CustomPainter {
  _PerimeterSweepPainter({
    required this.progress,
    required this.color,
    required this.radius,
  });

  final double progress;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLen = metrics.first.length;
    final headDist = totalLen * progress.clamp(0.0, 1.0);
    final tailDist = math.max(0.0, headDist - totalLen * 0.35);

    final sweepPath = metrics.first.extractPath(tailDist, headDist);

    final sweepPaint = Paint()
      ..color =
          color.withValues(alpha: (1.0 - progress * 0.3).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(sweepPath, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _PerimeterSweepPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.radius != radius;
  }
}
