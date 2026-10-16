import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arrowtapout/data/arrow_skin.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/component_tokens.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:flutter/material.dart';

/// Helper to draw a sleek, solid aerodynamic chevron arrowhead.
void drawChevronArrowhead({
  required ui.Canvas canvas,
  required ui.Offset headPoint,
  required double angleRad,
  required double armLengthPx,
  required ui.Paint paint,
  ui.Paint? shadowPaint,
}) {
  final arrowLength = armLengthPx;
  final wingSpan = armLengthPx * 0.95;
  final halfWingSpan = wingSpan / 2.0;
  final wingSetback = math.max(1.5, paint.strokeWidth * 0.35);
  final notchForward = math.max(1.0, paint.strokeWidth * 0.25);

  final cosA = math.cos(angleRad);
  final sinA = math.sin(angleRad);
  final fx = cosA;
  final fy = sinA;
  final px = -sinA;
  final py = cosA;

  final tip = ui.Offset(
    headPoint.dx + fx * arrowLength,
    headPoint.dy + fy * arrowLength,
  );

  final leftWing = ui.Offset(
    headPoint.dx - fx * wingSetback + px * halfWingSpan,
    headPoint.dy - fy * wingSetback + py * halfWingSpan,
  );

  final notch = ui.Offset(
    headPoint.dx + fx * notchForward,
    headPoint.dy + fy * notchForward,
  );

  final rightWing = ui.Offset(
    headPoint.dx - fx * wingSetback - px * halfWingSpan,
    headPoint.dy - fy * wingSetback - py * halfWingSpan,
  );

  final path = ui.Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(leftWing.dx, leftWing.dy)
    ..lineTo(notch.dx, notch.dy)
    ..lineTo(rightWing.dx, rightWing.dy)
    ..close();

  if (shadowPaint != null) {
    canvas.save();
    canvas.translate(0, 2.0);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
  }

  // Draw solid filled arrow pointer
  final fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = paint.color
    ..isAntiAlias = true;
  canvas.drawPath(path, fillPaint);

  // Stroke border with rounded joins for crisp, tactile finish
  final strokeBorder = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.8, paint.strokeWidth * 0.45)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = paint.color
    ..isAntiAlias = true;
  canvas.drawPath(path, strokeBorder);
}

/// Unified Board Painter rendering lattice dots, ambient shadows, and path-aware extracted threads.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.level,
    this.activeIds = const {},
    this.getActiveIds,
    required this.cellSize,
    required this.tokens,
    required this.animator,
    required this.reduceMotion,
    this.arrowSkin = ArrowSkin.chevron,
  })  : _maskAdjacentNodes = _computeMaskNodes(level),
        super(repaint: animator);

  final Level level;
  final Set<int> activeIds;
  final Set<int> Function()? getActiveIds;
  final double cellSize;
  final AppTokens tokens;
  final BoardAnimator animator;
  final bool reduceMotion;
  final ArrowSkin arrowSkin;
  final Set<Cell> _maskAdjacentNodes;

  Set<int> get _effectiveActiveIds => getActiveIds?.call() ?? activeIds;

  final Paint _threadPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  final Paint _shadowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  final Paint _hintPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  final ui.Path _arrowPath = ui.Path();
  final Paint _arrowFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  final Paint _arrowStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  ui.Picture? _latticePicture;

  void _ensureLatticePicture(double dotRadius) {
    if (_latticePicture != null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = tokens.gridDot
      ..isAntiAlias = true;

    if (level.shape == 'rect' || level.shape == 'square') {
      for (var r = 0; r < level.rows; r++) {
        for (var c = 0; c < level.cols; c++) {
          canvas.drawCircle(
            Offset(c * cellSize, r * cellSize),
            dotRadius,
            dotPaint,
          );
        }
      }
    } else {
      for (final cell in _maskAdjacentNodes) {
        canvas.drawCircle(
          Offset(cell.c * cellSize, cell.r * cellSize),
          dotRadius,
          dotPaint,
        );
      }
    }
    _latticePicture = recorder.endRecording();
  }

  void _renderChevronArrowhead({
    required ui.Canvas canvas,
    required ui.Offset headPoint,
    required double angleRad,
    required double armLengthPx,
    required ui.Paint paint,
    ui.Paint? shadowPaint,
  }) {
    final arrowLength = armLengthPx;
    final wingSpan = armLengthPx * 0.95;
    final halfWingSpan = wingSpan / 2.0;
    final wingSetback = math.max(1.5, paint.strokeWidth * 0.35);
    final notchForward = math.max(1.0, paint.strokeWidth * 0.25);

    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    final fx = cosA;
    final fy = sinA;
    final px = -sinA;
    final py = cosA;

    final tip = ui.Offset(
      headPoint.dx + fx * arrowLength,
      headPoint.dy + fy * arrowLength,
    );

    final leftWing = ui.Offset(
      headPoint.dx - fx * wingSetback + px * halfWingSpan,
      headPoint.dy - fy * wingSetback + py * halfWingSpan,
    );

    final notch = ui.Offset(
      headPoint.dx + fx * notchForward,
      headPoint.dy + fy * notchForward,
    );

    final rightWing = ui.Offset(
      headPoint.dx - fx * wingSetback - px * halfWingSpan,
      headPoint.dy - fy * wingSetback - py * halfWingSpan,
    );

    _arrowPath.reset();
    _arrowPath.moveTo(tip.dx, tip.dy);
    _arrowPath.lineTo(leftWing.dx, leftWing.dy);
    _arrowPath.lineTo(notch.dx, notch.dy);
    _arrowPath.lineTo(rightWing.dx, rightWing.dy);
    _arrowPath.close();

    if (shadowPaint != null) {
      canvas.save();
      canvas.translate(0, 2.0);
      canvas.drawPath(_arrowPath, shadowPaint);
      canvas.restore();
    }

    _arrowFillPaint.color = paint.color;
    canvas.drawPath(_arrowPath, _arrowFillPaint);

    _arrowStrokePaint.color = paint.color;
    _arrowStrokePaint.strokeWidth = math.max(1.8, paint.strokeWidth * 0.45);
    canvas.drawPath(_arrowPath, _arrowStrokePaint);
  }

  void _renderRoundedArrowhead({
    required ui.Canvas canvas,
    required ui.Offset headPoint,
    required double angleRad,
    required double armLengthPx,
    required ui.Paint paint,
    ui.Paint? shadowPaint,
  }) {
    final arrowLength = armLengthPx;
    final wingSpan = armLengthPx * 0.95;
    final halfWingSpan = wingSpan / 2.0;
    final wingSetback = math.max(1.5, paint.strokeWidth * 0.35);

    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    final fx = cosA;
    final fy = sinA;
    final px = -sinA;
    final py = cosA;

    final tip = ui.Offset(
      headPoint.dx + fx * arrowLength,
      headPoint.dy + fy * arrowLength,
    );
    final leftWing = ui.Offset(
      headPoint.dx - fx * wingSetback + px * halfWingSpan,
      headPoint.dy - fy * wingSetback + py * halfWingSpan,
    );
    final rightWing = ui.Offset(
      headPoint.dx - fx * wingSetback - px * halfWingSpan,
      headPoint.dy - fy * wingSetback - py * halfWingSpan,
    );

    final midLeft = ui.Offset(
      headPoint.dx + fx * (arrowLength * 0.35) + px * (halfWingSpan * 0.65),
      headPoint.dy + fy * (arrowLength * 0.35) + py * (halfWingSpan * 0.65),
    );
    final midRight = ui.Offset(
      headPoint.dx + fx * (arrowLength * 0.35) - px * (halfWingSpan * 0.65),
      headPoint.dy + fy * (arrowLength * 0.35) - py * (halfWingSpan * 0.65),
    );

    _arrowPath.reset();
    _arrowPath.moveTo(tip.dx, tip.dy);
    _arrowPath.quadraticBezierTo(midLeft.dx, midLeft.dy, leftWing.dx, leftWing.dy);
    _arrowPath.lineTo(headPoint.dx, headPoint.dy);
    _arrowPath.lineTo(rightWing.dx, rightWing.dy);
    _arrowPath.quadraticBezierTo(midRight.dx, midRight.dy, tip.dx, tip.dy);
    _arrowPath.close();

    if (shadowPaint != null) {
      canvas.save();
      canvas.translate(0, 2.0);
      canvas.drawPath(_arrowPath, shadowPaint);
      canvas.restore();
    }

    _arrowFillPaint.color = paint.color;
    canvas.drawPath(_arrowPath, _arrowFillPaint);

    _arrowStrokePaint.color = paint.color;
    _arrowStrokePaint.strokeWidth = math.max(1.8, paint.strokeWidth * 0.45);
    canvas.drawPath(_arrowPath, _arrowStrokePaint);
  }

  void _renderDiamondArrowhead({
    required ui.Canvas canvas,
    required ui.Offset headPoint,
    required double angleRad,
    required double armLengthPx,
    required ui.Paint paint,
    ui.Paint? shadowPaint,
  }) {
    final arrowLength = armLengthPx * 0.95;
    final backDist = armLengthPx * 0.35;
    final sideDist = armLengthPx * 0.45;

    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    final fx = cosA;
    final fy = sinA;
    final px = -sinA;
    final py = cosA;

    final tip = ui.Offset(
      headPoint.dx + fx * arrowLength,
      headPoint.dy + fy * arrowLength,
    );
    final back = ui.Offset(
      headPoint.dx - fx * backDist,
      headPoint.dy - fy * backDist,
    );
    final leftSide = ui.Offset(
      headPoint.dx + px * sideDist,
      headPoint.dy + py * sideDist,
    );
    final rightSide = ui.Offset(
      headPoint.dx - px * sideDist,
      headPoint.dy - py * sideDist,
    );

    _arrowPath.reset();
    _arrowPath.moveTo(tip.dx, tip.dy);
    _arrowPath.lineTo(leftSide.dx, leftSide.dy);
    _arrowPath.lineTo(back.dx, back.dy);
    _arrowPath.lineTo(rightSide.dx, rightSide.dy);
    _arrowPath.close();

    if (shadowPaint != null) {
      canvas.save();
      canvas.translate(0, 2.0);
      canvas.drawPath(_arrowPath, shadowPaint);
      canvas.restore();
    }

    _arrowFillPaint.color = paint.color;
    canvas.drawPath(_arrowPath, _arrowFillPaint);

    _arrowStrokePaint.color = paint.color;
    _arrowStrokePaint.strokeWidth = math.max(1.8, paint.strokeWidth * 0.45);
    canvas.drawPath(_arrowPath, _arrowStrokePaint);
  }

  void _renderEmojiArrowhead({
    required ui.Canvas canvas,
    required ui.Offset headPoint,
    required double angleRad,
    required double size,
    required String emoji,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: size.clamp(14.0, 32.0),
          fontFamilyFallback: const [
            'Noto Color Emoji',
            'Apple Color Emoji',
            'Segoe UI Emoji',
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(headPoint.dx, headPoint.dy);
    // Align emoji facing direction
    final extraAngle = emoji == '🚀' ? (math.pi / 4) : 0.0;
    canvas.rotate(angleRad + extraAngle);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _renderArrowhead({
    required ui.Canvas canvas,
    required ui.Offset headPoint,
    required double angleRad,
    required double armLengthPx,
    required ui.Paint paint,
    required int threadId,
    ui.Paint? shadowPaint,
  }) {
    switch (arrowSkin) {
      case ArrowSkin.chevron:
        _renderChevronArrowhead(
          canvas: canvas,
          headPoint: headPoint,
          angleRad: angleRad,
          armLengthPx: armLengthPx,
          paint: paint,
          shadowPaint: shadowPaint,
        );
      case ArrowSkin.rounded:
        _renderRoundedArrowhead(
          canvas: canvas,
          headPoint: headPoint,
          angleRad: angleRad,
          armLengthPx: armLengthPx,
          paint: paint,
          shadowPaint: shadowPaint,
        );
      case ArrowSkin.diamond:
        _renderDiamondArrowhead(
          canvas: canvas,
          headPoint: headPoint,
          angleRad: angleRad,
          armLengthPx: armLengthPx,
          paint: paint,
          shadowPaint: shadowPaint,
        );
      case ArrowSkin.rockets:
        _renderEmojiArrowhead(
          canvas: canvas,
          headPoint: headPoint,
          angleRad: angleRad,
          size: armLengthPx * 2.3,
          emoji: '🚀',
        );
      case ArrowSkin.animals:
        const animals = ['🦊', '🐱', '🐶', '🐰', '🐼', '🐯', '🦁', '🐸', '🐵', '🦉'];
        final emoji = animals[threadId.abs() % animals.length];
        _renderEmojiArrowhead(
          canvas: canvas,
          headPoint: headPoint,
          angleRad: angleRad,
          size: armLengthPx * 2.3,
          emoji: emoji,
        );
      case ArrowSkin.emojis:
        const emojis = ['⚡', '⭐', '🎯', '🔥', '💎', '🌟', '🍀', '🪐', '🌈', '🔮'];
        final emoji = emojis[threadId.abs() % emojis.length];
        _renderEmojiArrowhead(
          canvas: canvas,
          headPoint: headPoint,
          angleRad: angleRad,
          size: armLengthPx * 2.3,
          emoji: emoji,
        );
      case ArrowSkin.random:
        const fun = [
          '🚀', '⚡', '⭐', '🎯', '🔥', '💎', '🌟', '🍀', '🦊', '🐱', '🐶',
          '🐰', '🪐', '🌈', '🔮', '🎈', '🍕', '⚽'
        ];
        final emoji = fun[threadId.abs() % fun.length];
        _renderEmojiArrowhead(
          canvas: canvas,
          headPoint: headPoint,
          angleRad: angleRad,
          size: armLengthPx * 2.3,
          emoji: emoji,
        );
    }
  }

  static Set<Cell> _computeMaskNodes(Level level) {
    if (level.shape == 'rect' || level.shape == 'square') {
      return const {};
    }
    final occupied = <Cell>{};
    for (final t in level.threads) {
      occupied.addAll(t.cells);
    }
    final mask = <Cell>{};
    for (final cell in occupied) {
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          final r = cell.r + dr;
          final c = cell.c + dc;
          if (r >= 0 && r < level.rows && c >= 0 && c < level.cols) {
            mask.add(Cell(r, c));
          }
        }
      }
    }
    return mask;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = ComponentTokens.threadStroke(cellSize);
    final armLength = ComponentTokens.arrowheadArm(cellSize);
    final dotRadius = ComponentTokens.gridDotRadius(cellSize);
    final nowMs = animator.nowMs;

    _threadPaint.strokeWidth = strokeWidth;
    _shadowPaint.strokeWidth = strokeWidth + 0.8;
    _shadowPaint.color = tokens.ink.withValues(alpha: 0.12);
    _shadowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    // 1. Draw lattice grid dots (recorded once into ui.Picture, 0 per-frame overhead)
    _ensureLatticePicture(dotRadius);
    canvas.drawPicture(_latticePicture!);

    // 2. Hint outline under hinted thread
    final currentActive = _effectiveActiveIds;
    final hintedId = animator.hintedThreadId;
    if (hintedId != null && animator.hintStartTimeMs != null) {
      final geom = animator.geometries[hintedId];
      if (geom != null && currentActive.contains(hintedId)) {
        final elapsed = nowMs - animator.hintStartTimeMs!;
        var pulse = 0.55 +
            0.45 * (0.5 + 0.5 * math.sin((elapsed / 1600.0) * 2 * math.pi));
        if (elapsed > 2000.0) {
          final fadeOut = (1.0 - (elapsed - 2000.0) / 200.0).clamp(0.0, 1.0);
          pulse *= fadeOut;
        }

        _hintPaint
          ..strokeWidth = strokeWidth + 4.0
          ..color = tokens.accent.withValues(alpha: pulse.clamp(0.0, 1.0));

        canvas.drawPath(geom.basePath, _hintPaint);
      }
    }

    // 3. Pass 1: Ambient Drop Shadows for all active/exiting pieces
    for (final thread in level.threads) {
      final tid = thread.id;
      final isActive = currentActive.contains(tid);
      final activeExit = animator.exits[tid];
      final geom = animator.geometries[tid];
      if (geom == null || (!isActive && activeExit == null)) continue;

      canvas.save();
      canvas.translate(0, 2.5);

      if (activeExit != null) {
        if (!reduceMotion) {
          final extracted = activeExit.sampleGeometry(nowMs);
          _shadowPaint.color =
              tokens.ink.withValues(alpha: 0.12 * extracted.alpha);
          canvas.drawPath(extracted.visiblePath, _shadowPaint);
          _renderArrowhead(
            canvas: canvas,
            headPoint: extracted.headPosition,
            angleRad: extracted.headAngleRad,
            armLengthPx: armLength,
            paint: _shadowPaint,
            threadId: tid,
          );
        }
      } else {
        final activeWrongMove = animator.wrongMoves[tid];
        final activeBlocked = animator.blockeds[tid];
        final shakeOffset =
            activeWrongMove?.shakeOffset(nowMs) ?? ui.Offset.zero;
        final dispPx = activeBlocked?.displacementPx(nowMs) ?? 0.0;

        if (shakeOffset != ui.Offset.zero || dispPx != 0.0) {
          canvas.translate(
            thread.dir.dx * dispPx + shakeOffset.dx,
            thread.dir.dy * dispPx + shakeOffset.dy,
          );
        }
        _shadowPaint.color = tokens.ink.withValues(alpha: 0.12);
        canvas.drawPath(geom.basePath, _shadowPaint);
        _renderArrowhead(
          canvas: canvas,
          headPoint: geom.headOffset,
          angleRad: geom.headAngle,
          armLengthPx: armLength,
          paint: _shadowPaint,
          threadId: tid,
        );
      }
      canvas.restore();
    }

    // 4. Pass 2: Main Thread Bodies & Arrowheads
    var threadIndex = 0;
    for (final thread in level.threads) {
      final tid = thread.id;
      final isActive = currentActive.contains(tid);
      final activeExit = animator.exits[tid];
      final activeWrongMove = animator.wrongMoves[tid];
      final geom = animator.geometries[tid];

      if (geom == null || (!isActive && activeExit == null)) {
        threadIndex++;
        continue;
      }

      if (activeExit != null) {
        // --- Path-Aware Arrow Extraction Animation ---
        final extracted = activeExit.sampleGeometry(nowMs);
        _threadPaint.color =
            tokens.thread.withValues(alpha: tokens.thread.a * extracted.alpha);

        canvas.drawPath(extracted.visiblePath, _threadPaint);
        _renderArrowhead(
          canvas: canvas,
          headPoint: extracted.headPosition,
          angleRad: extracted.headAngleRad,
          armLengthPx: armLength,
          paint: _threadPaint,
          threadId: tid,
        );
      } else if (activeWrongMove != null ||
          animator.blockeds.containsKey(tid)) {
        // --- Unified Blocked Move Feedback: Physical Nudge, Shake & Warning ---
        final activeBlocked = animator.blockeds[tid];
        final shakeOffset =
            activeWrongMove?.shakeOffset(nowMs) ?? ui.Offset.zero;
        final dispPx = activeBlocked?.displacementPx(nowMs) ?? 0.0;
        final wrongDanger = activeWrongMove?.dangerLerp(nowMs) ?? 0.0;
        final blockedDanger = activeBlocked?.tappedDangerLerp(nowMs) ?? 0.0;
        final dangerLerp = math.max(wrongDanger, blockedDanger);

        _threadPaint.color =
            Color.lerp(tokens.thread, tokens.danger, dangerLerp)!;

        canvas.save();
        canvas.translate(
          thread.dir.dx * dispPx + shakeOffset.dx,
          thread.dir.dy * dispPx + shakeOffset.dy,
        );

        canvas.drawPath(geom.basePath, _threadPaint);
        _renderArrowhead(
          canvas: canvas,
          headPoint: geom.headOffset,
          angleRad: geom.headAngle,
          armLengthPx: armLength,
          paint: _threadPaint,
          threadId: tid,
        );

        canvas.restore();
      } else {
        // --- Idle, Blocker-pulsed, or Entering thread ---
        var blockerPulseLerp = 0.0;
        for (final b in animator.blockeds.values) {
          if (b.blockerId == tid) {
            blockerPulseLerp =
                math.max(blockerPulseLerp, b.blockerPulseLerp(nowMs));
          }
        }
        // Normal idle / blocker / entrance thread
        if (blockerPulseLerp > 0.0) {
          _threadPaint.color =
              Color.lerp(tokens.thread, tokens.danger, blockerPulseLerp)!;
        } else {
          _threadPaint.color = tokens.thread;
        }

        final entrance = animator.entranceProgressFor(
          threadIndex,
          reduceMotion: reduceMotion,
        );

        if (entrance >= 1.0) {
          canvas.drawPath(geom.basePath, _threadPaint);
          _renderArrowhead(
            canvas: canvas,
            headPoint: geom.headOffset,
            angleRad: geom.headAngle,
            armLengthPx: armLength,
            paint: _threadPaint,
            threadId: tid,
          );
        } else if (entrance > 0.0) {
          final alpha = entrance;
          _threadPaint.color = _threadPaint.color
              .withValues(alpha: _threadPaint.color.a * alpha);
          canvas.drawPath(geom.basePath, _threadPaint);
          _renderArrowhead(
            canvas: canvas,
            headPoint: geom.headOffset,
            angleRad: geom.headAngle,
            armLengthPx: armLength,
            paint: _threadPaint,
            threadId: tid,
          );
        }
      }

      threadIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.activeIds != activeIds ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.tokens != tokens ||
        oldDelegate.reduceMotion != reduceMotion ||
        oldDelegate.arrowSkin != arrowSkin ||
        animator.hasActiveAnimations;
  }
}
