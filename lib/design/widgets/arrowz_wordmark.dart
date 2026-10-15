import 'dart:math' as math;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:flutter/material.dart';

/// The signature ArrowZ wordmark:
/// "Arrow" in w800 display font + custom-painted animated thread "Z" with arrowhead in accent.
class ArrowZWordmark extends StatefulWidget {
  const ArrowZWordmark({
    super.key,
    this.fontSize = 44.0,
    this.animateOnLaunch = true,
    this.showTagline = false,
  });

  final double fontSize;
  final bool animateOnLaunch;
  final bool showTagline;

  @override
  State<ArrowZWordmark> createState() => _ArrowZWordmarkState();
}

class _ArrowZWordmarkState extends State<ArrowZWordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.animateOnLaunch) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final zSize = widget.fontSize * 0.85;

    return Semantics(
      label: 'ArrowZ',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Arrow',
                style: TextStyle(
                  fontFamily: Primitives.fontDisplay,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: tokens.ink,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4.0),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(zSize * 0.82, zSize),
                    painter: _ZThreadPainter(
                      progress: _controller.value,
                      color: tokens.accent,
                      strokeWidth: math.max(2.5, widget.fontSize * 0.08),
                    ),
                  );
                },
              ),
            ],
          ),
          if (widget.showTagline) ...[
            const SizedBox(height: 8.0),
            Text(
              'Pull every thread free.',
              style: tokens.typography.body.copyWith(
                color: tokens.inkMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZThreadPainter extends CustomPainter {
  _ZThreadPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pad = strokeWidth * 0.6;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final p0 = Offset(pad, pad + 2.0); // Top left
    final p1 = Offset(pad + w, pad + 2.0); // Top right
    final p2 = Offset(pad, pad + h - 2.0); // Bottom left
    final p3 = Offset(pad + w, pad + h - 2.0); // Bottom right

    final seg1Len = (p1 - p0).distance;
    final seg2Len = (p2 - p1).distance;
    final seg3Len = (p3 - p2).distance;
    final totalLen = seg1Len + seg2Len + seg3Len;

    final drawLen = totalLen * progress.clamp(0.0, 1.0);

    // Segment 1: top bar
    if (drawLen <= seg1Len) {
      final t = drawLen / seg1Len;
      canvas.drawLine(p0, Offset.lerp(p0, p1, t)!, paint);
      return;
    } else {
      canvas.drawLine(p0, p1, paint);
    }

    // Segment 2: diagonal
    final remAfter1 = drawLen - seg1Len;
    if (remAfter1 <= seg2Len) {
      final t = remAfter1 / seg2Len;
      canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, paint);
      return;
    } else {
      canvas.drawLine(p1, p2, paint);
    }

    // Segment 3: bottom bar
    final remAfter2 = remAfter1 - seg2Len;
    final t3 = (remAfter2 / seg3Len).clamp(0.0, 1.0);
    final curP3 = Offset.lerp(p2, p3, t3)!;
    canvas.drawLine(p2, curP3, paint);

    // Chevron Arrowhead on the final tip pointing right
    if (t3 > 0.85) {
      final arrowOpacity = ((t3 - 0.85) / 0.15).clamp(0.0, 1.0);
      final arrowPaint = Paint()
        ..color = color.withValues(alpha: arrowOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final armLen = strokeWidth * 2.2;
      final arrowTip = curP3;
      final arm1 = arrowTip + Offset(-armLen * 0.866, -armLen * 0.7);
      final arm2 = arrowTip + Offset(-armLen * 0.866, armLen * 0.7);

      final path = Path()
        ..moveTo(arm1.dx, arm1.dy)
        ..lineTo(arrowTip.dx, arrowTip.dy)
        ..lineTo(arm2.dx, arm2.dy);
      canvas.drawPath(path, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZThreadPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
