import 'dart:math' as math;
import 'dart:ui' as ui;

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
  final noseDist = armLengthPx * 0.45;
  final wingDist = armLengthPx * 0.70;
  const wingAngle = 142.0 * math.pi / 180.0;
  final notchDist = armLengthPx * 0.10;

  final tip = ui.Offset(
    headPoint.dx + math.cos(angleRad) * noseDist,
    headPoint.dy + math.sin(angleRad) * noseDist,
  );

  final leftWing = ui.Offset(
    headPoint.dx + math.cos(angleRad - wingAngle) * wingDist,
    headPoint.dy + math.sin(angleRad - wingAngle) * wingDist,
  );

  final rightWing = ui.Offset(
    headPoint.dx + math.cos(angleRad + wingAngle) * wingDist,
    headPoint.dy + math.sin(angleRad + wingAngle) * wingDist,
  );

  final notch = ui.Offset(
    headPoint.dx - math.cos(angleRad) * notchDist,
    headPoint.dy - math.sin(angleRad) * notchDist,
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

  // Stroke border for crisp rounding
  final strokeBorder = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.5, paint.strokeWidth * 0.35)
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
  })  : _maskAdjacentNodes = _computeMaskNodes(level),
        super(repaint: animator);

  final Level level;
  final Set<int> activeIds;
  final Set<int> Function()? getActiveIds;
  final double cellSize;
  final AppTokens tokens;
  final BoardAnimator animator;
  final bool reduceMotion;
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

    if (level.shape == 'rect') {
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
    final noseDist = armLengthPx * 0.45;
    final wingDist = armLengthPx * 0.70;
    const wingAngle = 142.0 * math.pi / 180.0;
    final notchDist = armLengthPx * 0.10;

    final tip = ui.Offset(
      headPoint.dx + math.cos(angleRad) * noseDist,
      headPoint.dy + math.sin(angleRad) * noseDist,
    );

    final leftWing = ui.Offset(
      headPoint.dx + math.cos(angleRad - wingAngle) * wingDist,
      headPoint.dy + math.sin(angleRad - wingAngle) * wingDist,
    );

    final rightWing = ui.Offset(
      headPoint.dx + math.cos(angleRad + wingAngle) * wingDist,
      headPoint.dy + math.sin(angleRad + wingAngle) * wingDist,
    );

    final notch = ui.Offset(
      headPoint.dx - math.cos(angleRad) * notchDist,
      headPoint.dy - math.sin(angleRad) * notchDist,
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
    _arrowStrokePaint.strokeWidth = math.max(1.5, paint.strokeWidth * 0.35);
    canvas.drawPath(_arrowPath, _arrowStrokePaint);
  }

  static Set<Cell> _computeMaskNodes(Level level) {
    if (level.shape == 'rect') {
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
        }
      } else {
        final activeWrongMove = animator.wrongMoves[tid];
        if (activeWrongMove != null) {
          final offset = activeWrongMove.shakeOffset(nowMs);
          canvas.translate(offset.dx, offset.dy);
        } else {
          final activeBlocked = animator.blockeds[tid];
          if (activeBlocked != null) {
            final dispPx = activeBlocked.displacementPx(nowMs);
            canvas.translate(thread.dir.dx * dispPx, thread.dir.dy * dispPx);
          }
        }
        _shadowPaint.color = tokens.ink.withValues(alpha: 0.12);
        canvas.drawPath(geom.basePath, _shadowPaint);
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
        _renderChevronArrowhead(
          canvas: canvas,
          headPoint: extracted.headPosition,
          angleRad: extracted.headAngleRad,
          armLengthPx: armLength,
          paint: _threadPaint,
        );
      } else if (activeWrongMove != null) {
        // --- Wrong Move Feedback: Controlled Shake & Red Highlight ---
        final offset = activeWrongMove.shakeOffset(nowMs);
        final dangerLerp = activeWrongMove.dangerLerp(nowMs);
        _threadPaint.color =
            Color.lerp(tokens.thread, tokens.danger, dangerLerp)!;

        canvas.save();
        canvas.translate(offset.dx, offset.dy);

        canvas.drawPath(geom.basePath, _threadPaint);
        _renderChevronArrowhead(
          canvas: canvas,
          headPoint: geom.headOffset,
          angleRad: geom.headAngle,
          armLengthPx: armLength,
          paint: _threadPaint,
        );

        canvas.restore();
      } else {
        // --- Idle, Blocked, or Entering thread ---
        final activeBlocked = animator.blockeds[tid];
        var blockerPulseLerp = 0.0;
        for (final b in animator.blockeds.values) {
          if (b.blockerId == tid) {
            blockerPulseLerp =
                math.max(blockerPulseLerp, b.blockerPulseLerp(nowMs));
          }
        }

        if (activeBlocked != null) {
          // Blocked tapped thread: elastic spring bump
          final dispPx = activeBlocked.displacementPx(nowMs);
          final dangerLerp = activeBlocked.tappedDangerLerp(nowMs);
          _threadPaint.color =
              Color.lerp(tokens.thread, tokens.danger, dangerLerp)!;

          canvas.save();
          canvas.translate(
            thread.dir.dx * dispPx,
            thread.dir.dy * dispPx,
          );

          canvas.drawPath(geom.basePath, _threadPaint);
          _renderChevronArrowhead(
            canvas: canvas,
            headPoint: geom.headOffset,
            angleRad: geom.headAngle,
            armLengthPx: armLength,
            paint: _threadPaint,
          );

          canvas.restore();
        } else {
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
            _renderChevronArrowhead(
              canvas: canvas,
              headPoint: geom.headOffset,
              angleRad: geom.headAngle,
              armLengthPx: armLength,
              paint: _threadPaint,
            );
          } else if (entrance > 0.0) {
            final alpha = entrance;
            _threadPaint.color = _threadPaint.color
                .withValues(alpha: _threadPaint.color.a * alpha);
            canvas.drawPath(geom.basePath, _threadPaint);
            _renderChevronArrowhead(
              canvas: canvas,
              headPoint: geom.headOffset,
              angleRad: geom.headAngle,
              armLengthPx: armLength,
              paint: _threadPaint,
            );
          }
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
        animator.hasActiveAnimations;
  }
}
