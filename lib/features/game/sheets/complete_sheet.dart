import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
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
    this.bestChain = 0,
    required this.onNextLevel,
    required this.onReplay,
    required this.onLevels,
  });

  final int levelId;
  final String chapterName;
  final bool isChapterFinale;
  final int stars; // 1, 2, or 3
  final int threadsCleared;
  final int mistakes;
  final int bestChain;
  final VoidCallback onNextLevel;
  final VoidCallback onReplay;
  final VoidCallback onLevels;

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
    if (widget.mistakes == 0) {
      title = 'Clean sweep';
    } else if (isFinalGameLevel) {
      title = 'Nothing left to unwind';
    } else if (widget.isChapterFinale) {
      title = '${widget.chapterName} complete';
    } else {
      title = 'Level complete';
    }

    final chapterLevelNum = ((widget.levelId - 1) % 20) + 1;

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
            const SizedBox(height: Primitives.space8),
            Center(
              child: Text(
                '${widget.chapterName} · $chapterLevelNum of 20',
                style: tokens.typography.caption.copyWith(color: tokens.inkMuted),
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
            const SizedBox(height: Primitives.space20),
            // Stats row (threads, mistakes, best chain)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: tokens.surfaceRaised,
                borderRadius: BorderRadius.circular(AppTokens.radius16),
                border: Border.all(color: tokens.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatColumn(
                      label: 'Threads',
                      value: '${widget.threadsCleared}',
                      tokens: tokens,
                    ),
                  ),
                  Container(width: 1, height: 28, color: tokens.line),
                  Expanded(
                    child: _StatColumn(
                      label: 'Mistakes',
                      value: '${widget.mistakes}',
                      tokens: tokens,
                    ),
                  ),
                  if (widget.bestChain > 1) ...[
                    Container(width: 1, height: 28, color: tokens.line),
                    Expanded(
                      child: _StatColumn(
                        label: 'Best Chain',
                        value: 'x${widget.bestChain}',
                        tokens: tokens,
                        isAccent: true,
                      ),
                    ),
                  ],
                ],
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
                  minimumSize: const Size.fromHeight(52.0),
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
                      widget.onReplay();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.ink,
                      side: BorderSide(color: tokens.line),
                      minimumSize: const Size.fromHeight(48.0),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    child: Text('Replay', style: tokens.typography.label),
                  ),
                ),
                const SizedBox(width: Primitives.space12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onLevels();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.ink,
                      side: BorderSide(color: tokens.line),
                      minimumSize: const Size.fromHeight(48.0),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    child: Text('Levels', style: tokens.typography.label),
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

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.tokens,
    this.isAccent = false,
  });

  final String label;
  final String value;
  final AppTokens tokens;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: tokens.typography.heading.copyWith(
            color: isAccent ? tokens.accent : tokens.ink,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: tokens.typography.caption.copyWith(color: tokens.inkMuted),
        ),
      ],
    );
  }
}
