import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/share_service.dart';
import 'package:flutter/material.dart';

class CompleteSheet extends StatefulWidget {
  const CompleteSheet({
    super.key,
    required this.levelId,
    required this.chapterName,
    required this.isChapterFinale,
    required this.stars,
    required this.threadsCleared,
    required this.mistakes,
    required this.onNextLevel,
    required this.onLevels,
    this.elapsedSeconds,
  });

  final int levelId;
  final String chapterName;
  final bool isChapterFinale;
  final int stars; // 1, 2, or 3
  final int threadsCleared;
  final int mistakes;
  final VoidCallback onNextLevel;
  final VoidCallback onLevels;
  final int? elapsedSeconds;

  @override
  State<CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<CompleteSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Total animation: 3 stars * 120ms stagger + 320ms draw = ~680ms
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isFinalGameLevel = widget.levelId >= 200;

    String title;
    if (isFinalGameLevel) {
      title = 'Nothing left to unwind';
    } else if (widget.isChapterFinale) {
      title = '${widget.chapterName} complete';
    } else {
      title = 'Level complete';
    }

    String statsText = widget.mistakes == 0
        ? '${widget.threadsCleared} threads · zero mistakes'
        : '${widget.threadsCleared} threads · ${widget.mistakes} mistake${widget.mistakes == 1 ? '' : 's'}';

    String? formattedTime;
    if (widget.elapsedSeconds != null && widget.elapsedSeconds! > 0) {
      final m = widget.elapsedSeconds! ~/ 60;
      final s = widget.elapsedSeconds! % 60;
      formattedTime = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      statsText = '$statsText · ⏱️ $formattedTime';
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Primitives.radiusSheet),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Primitives.space24,
        vertical: Primitives.space24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                title,
                style: tokens.typography.title,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Primitives.space20),
            // Self-drawing stars
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 3; i++) ...[
                      if (i > 1) const SizedBox(width: Primitives.space16),
                      CustomPaint(
                        size: const Size(36.0, 36.0),
                        painter: StarDrawPainter(
                          earned: widget.stars >= i,
                          drawProgress: _starProgress(i - 1),
                          accentColor: tokens.accent,
                          faintColor: tokens.threadFaint,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: Primitives.space16),
            Center(
              child: Text(
                statsText,
                style: tokens.typography.body.copyWith(
                  color: tokens.inkMuted,
                  fontSize: 14.0,
                ),
              ),
            ),
            const SizedBox(height: Primitives.space24),
            if (!isFinalGameLevel) ...[
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNextLevel();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.accent,
                  foregroundColor: tokens.onAccent,
                  minimumSize: const Size.fromHeight(48.0),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(Primitives.radiusButton),
                  ),
                ),
                child: Text('Next level',
                    style: tokens.typography.label
                        .copyWith(color: tokens.onAccent)),
              ),
              const SizedBox(height: Primitives.space12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onLevels();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.ink,
                      side: BorderSide(color: tokens.threadFaint, width: 1.5),
                      minimumSize: const Size.fromHeight(48.0),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    child: Text('Levels', style: tokens.typography.label),
                  ),
                ),
                const SizedBox(width: Primitives.space12),
                OutlinedButton.icon(
                  onPressed: () {
                    ShareService.shareLevelComplete(
                      levelId: widget.levelId,
                      timeFormatted: formattedTime,
                      stars: widget.stars,
                    );
                  },
                  icon: Icon(Icons.share_rounded, size: 18.0, color: tokens.accent),
                  label: Text('Share', style: tokens.typography.label.copyWith(color: tokens.accent)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.accent,
                    side: BorderSide(color: tokens.accent.withValues(alpha: 0.5), width: 1.5),
                    minimumSize: const Size(100.0, 48.0),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(Primitives.radiusButton),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _starProgress(int starIndex) {
    final startT = (starIndex * 120.0) / 700.0;
    const durT = 320.0 / 700.0;
    final p = ((_controller.value - startT) / durT).clamp(0.0, 1.0);
    return Primitives.curveEnter.transform(p);
  }
}

/// CustomPainter drawing a star outline with PathMetric extraction.
class StarDrawPainter extends CustomPainter {
  StarDrawPainter({
    required this.earned,
    required this.drawProgress,
    required this.accentColor,
    required this.faintColor,
  });

  final bool earned;
  final double drawProgress;
  final Color accentColor;
  final Color faintColor;

  static Path? _cachedStarPath;
  static ui.PathMetric? _cachedMetric;

  static Path _getStarPath(Size size) {
    if (_cachedStarPath != null) return _cachedStarPath!;
    final path = Path();
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final outerR = size.width / 2.0 - 2.0;
    final innerR = outerR * 0.42;

    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = -math.pi / 2.0 + i * (math.pi / 5.0);
      final x = cx + math.cos(angle) * r;
      final y = cy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    _cachedStarPath = path;
    _cachedMetric = path.computeMetrics().first;
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final starPath = _getStarPath(size);
    final metric = _cachedMetric ?? starPath.computeMetrics().first;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = earned ? accentColor : faintColor.withValues(alpha: 0.5);

    if (earned && drawProgress < 1.0) {
      final drawnLen = metric.length * drawProgress;
      if (drawnLen > 0) {
        final sub = metric.extractPath(0.0, drawnLen);
        canvas.drawPath(sub, paint);
      }
    } else {
      canvas.drawPath(starPath, paint);
      if (earned) {
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = accentColor.withValues(alpha: 0.15);
        canvas.drawPath(starPath, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarDrawPainter old) =>
      old.drawProgress != drawProgress || old.earned != earned;
}
