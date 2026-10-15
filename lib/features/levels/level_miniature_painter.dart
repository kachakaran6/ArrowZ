import 'dart:ui' as ui;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:flutter/material.dart';

/// Global LRU / static cache for level miniature Pictures to guarantee 0 per-frame overhead.
final Map<String, ui.Picture> _pictureCache = {};

ui.Picture getOrCreateMiniaturePicture({
  required Level level,
  required AppTokens tokens,
  required double size,
}) {
  final cacheKey = '${level.id}_${tokens.id}_${size.toInt()}';
  final cached = _pictureCache[cacheKey];
  if (cached != null) return cached;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

  _paintLevelMiniature(canvas, size, level, tokens);

  final picture = recorder.endRecording();
  _pictureCache[cacheKey] = picture;
  return picture;
}

void _paintLevelMiniature(
  Canvas canvas,
  double size,
  Level level,
  AppTokens tokens,
) {
  final rows = level.rows;
  final cols = level.cols;
  if (rows <= 0 || cols <= 0 || level.threads.isEmpty) return;

  const pad = 6.0;
  final drawW = size - pad * 2;
  final drawH = size - pad * 2;

  final cellW = drawW / cols;
  final cellH = drawH / rows;
  final cellMin = math.min(cellW, cellH);

  // Proportional stroke and arrowhead calculation so miniature never degrades into a black smudge
  final strokeW = (cellMin * 0.28).clamp(0.85, 1.6);
  final isDense = cellMin < 3.8 || level.threads.length > 25;

  final threadPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeW
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = tokens.isDark
        ? tokens.thread.withValues(alpha: isDense ? 0.55 : 0.75)
        : tokens.ink.withValues(alpha: isDense ? 0.35 : 0.55);

  final chevronPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = (strokeW * 1.05).clamp(0.85, 1.8)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = tokens.accent;

  for (final thread in level.threads) {
    if (thread.cells.isEmpty) continue;

    final path = Path();
    for (var i = 0; i < thread.cells.length; i++) {
      final cell = thread.cells[i];
      final x = pad + (cell.c + 0.5) * cellW;
      final y = pad + (cell.r + 0.5) * cellH;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, threadPaint);

    // Chevron on head pointing in exit direction
    final head = thread.cells.last;
    final hx = pad + (head.c + 0.5) * cellW;
    final hy = pad + (head.r + 0.5) * cellH;
    final dir = thread.dir;

    const armLen = 3.2;
    final cPath = Path();

    switch (dir) {
      case Dir.up:
        cPath.moveTo(hx - armLen, hy + armLen * 0.7);
        cPath.lineTo(hx, hy - armLen * 0.3);
        cPath.lineTo(hx + armLen, hy + armLen * 0.7);
        break;
      case Dir.down:
        cPath.moveTo(hx - armLen, hy - armLen * 0.7);
        cPath.lineTo(hx, hy + armLen * 0.3);
        cPath.lineTo(hx + armLen, hy - armLen * 0.7);
        break;
      case Dir.left:
        cPath.moveTo(hx + armLen * 0.7, hy - armLen);
        cPath.lineTo(hx - armLen * 0.3, hy);
        cPath.lineTo(hx + armLen * 0.7, hy + armLen);
        break;
      case Dir.right:
        cPath.moveTo(hx - armLen * 0.7, hy - armLen);
        cPath.lineTo(hx + armLen * 0.3, hy);
        cPath.lineTo(hx - armLen * 0.7, hy + armLen);
        break;
    }
    canvas.drawPath(cPath, chevronPaint);
  }
}

typedef LevelMiniatureTile = LevelMiniatureWidget;

class LevelMiniatureWidget extends StatelessWidget {
  const LevelMiniatureWidget({
    super.key,
    required this.level,
    this.isLocked = false,
    this.size = 56.0,
  });

  final Level? level;
  final bool isLocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (level == null) {
      return SizedBox(
        width: size,
        height: size,
      );
    }

    final tokens = context.tokens;
    final picture = getOrCreateMiniaturePicture(
      level: level!,
      tokens: tokens,
      size: size,
    );

    return Opacity(
      opacity: isLocked ? 0.18 : 1.0,
      child: CustomPaint(
        size: Size(size, size),
        painter: _PicturePainter(picture),
      ),
    );
  }
}

class _PicturePainter extends CustomPainter {
  _PicturePainter(this.picture);

  final ui.Picture picture;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant _PicturePainter oldDelegate) {
    return oldDelegate.picture != picture;
  }
}
