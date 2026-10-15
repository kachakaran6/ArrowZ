import 'package:flutter/material.dart';

/// A 48 dp tall row of mini thread motifs drawn in the theme accent colour at 30%.
class ChapterArtStrip extends StatelessWidget {
  const ChapterArtStrip({
    super.key,
    required this.chapterId,
    required this.accentColor,
    this.height = 48.0,
  });

  final int chapterId;
  final Color accentColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _ChapterArtStripPainter(
          chapterId: chapterId,
          color: accentColor.withValues(alpha: 0.30),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ChapterArtStripPainter extends CustomPainter {
  const _ChapterArtStripPainter({
    required this.chapterId,
    required this.color,
  });

  final int chapterId;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const step = 44.0;
    final count = (size.width / step).ceil() + 1;
    final midY = size.height / 2.0;

    for (var i = 0; i < count; i++) {
      final cx = i * step + 20.0;
      final seed = (chapterId * 37 + i * 19) % 5;

      final path = Path();
      switch (seed) {
        case 0:
          // Right arrow chevron motif
          path.moveTo(cx - 10, midY - 8);
          path.lineTo(cx + 2, midY);
          path.lineTo(cx - 10, midY + 8);
          // Tail
          path.moveTo(cx - 16, midY);
          path.lineTo(cx + 2, midY);
          break;
        case 1:
          // Corner motif (turns down)
          path.moveTo(cx - 12, midY - 8);
          path.lineTo(cx + 4, midY - 8);
          path.lineTo(cx + 4, midY + 8);
          // Arrowhead
          path.moveTo(cx, midY + 3);
          path.lineTo(cx + 4, midY + 8);
          path.lineTo(cx + 8, midY + 3);
          break;
        case 2:
          // S-curve motif
          path.moveTo(cx - 12, midY + 6);
          path.lineTo(cx - 4, midY + 6);
          path.lineTo(cx + 4, midY - 6);
          path.lineTo(cx + 12, midY - 6);
          break;
        case 3:
          // Up chevron motif
          path.moveTo(cx - 8, midY + 8);
          path.lineTo(cx, midY - 6);
          path.lineTo(cx + 8, midY + 8);
          break;
        case 4:
        default:
          // Double chevron
          path.moveTo(cx - 12, midY - 6);
          path.lineTo(cx - 4, midY);
          path.lineTo(cx - 12, midY + 6);

          path.moveTo(cx - 2, midY - 6);
          path.lineTo(cx + 6, midY);
          path.lineTo(cx - 2, midY + 6);
          break;
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChapterArtStripPainter oldDelegate) {
    return oldDelegate.chapterId != chapterId || oldDelegate.color != color;
  }
}
