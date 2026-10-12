import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/engine/arrow_extraction_engine.dart';
import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

export 'package:arrowtapout/engine/arrow_extraction_engine.dart';

/// Cached geometry and extraction track for a thread on the board.
class ThreadGeometry {
  ThreadGeometry({
    required this.thread,
    required this.cellSize,
    required this.rows,
    required this.cols,
  }) : track = ExtractionTrack(
          thread: thread,
          cellSize: cellSize,
          rows: rows,
          cols: cols,
        ) {
    _buildBasePath();
  }

  final Thread thread;
  final double cellSize;
  final int rows;
  final int cols;
  final ExtractionTrack track;

  late final ui.Path basePath;

  void _buildBasePath() {
    basePath = ui.Path();
    final first = thread.cells.first;
    basePath.moveTo(first.c * cellSize, first.r * cellSize);
    for (var i = 1; i < thread.cells.length; i++) {
      final c = thread.cells[i];
      basePath.lineTo(c.c * cellSize, c.r * cellSize);
    }
  }
}

/// Active exit animation state for one thread driving path-aware extraction.
class ActiveExit {
  ActiveExit({
    required this.threadId,
    required this.geometry,
    required this.startTimeMs,
    required this.reduceMotion,
  }) : durationMs = reduceMotion ? 180.0 : geometry.track.durationMs;

  final int threadId;
  final ThreadGeometry geometry;
  final double durationMs;
  final double startTimeMs;
  final bool reduceMotion;

  double progress(double nowMs) {
    if (durationMs <= 0) return 1.0;
    return ((nowMs - startTimeMs) / durationMs).clamp(0.0, 1.0);
  }

  ExtractedGeometry sampleGeometry(double nowMs) {
    final p = progress(nowMs);
    return geometry.track.sample(p, reduceMotion: reduceMotion);
  }

  bool isDone(double nowMs) => progress(nowMs) >= 1.0;
}

/// Active blocked bounce animation state.
class ActiveBlocked {
  ActiveBlocked({
    required this.threadId,
    required this.blockerId,
    required this.distanceNodes,
    required this.cellSize,
    required this.startTimeMs,
    required this.reduceMotion,
  })  : maxNudgePx =
            math.min(0.35, math.max(0.12, distanceNodes - 0.7)) * cellSize,
        _spring = SpringSimulation(
          const SpringDescription(mass: 1.0, stiffness: 480.0, damping: 28.0),
          math.min(0.35, math.max(0.12, distanceNodes - 0.7)) * cellSize,
          0.0,
          0.0,
        );

  final int threadId;
  final int blockerId;
  final int distanceNodes;
  final double cellSize;
  final double startTimeMs;
  final bool reduceMotion;
  final double maxNudgePx;
  final SpringSimulation _spring;

  static const double forwardMs = 70.0;
  static const double totalMs = 320.0;

  double displacementPx(double nowMs) {
    if (reduceMotion) return 0.0;
    final elapsed = nowMs - startTimeMs;
    if (elapsed <= 0) return 0.0;

    if (elapsed < forwardMs) {
      final t = elapsed / forwardMs;
      return maxNudgePx * Curves.easeOutQuad.transform(t);
    } else {
      final springTime = (elapsed - forwardMs) / 1000.0;
      return _spring.x(springTime);
    }
  }

  double tappedDangerLerp(double nowMs) {
    final p = ((nowMs - startTimeMs) / totalMs).clamp(0.0, 1.0);
    if (p < 0.25) return (p / 0.25) * 0.35;
    return (1.0 - (p - 0.25) / 0.75) * 0.35;
  }

  double blockerPulseLerp(double nowMs) {
    final p = ((nowMs - startTimeMs) / 360.0).clamp(0.0, 1.0);
    if (p < 0.35) return (p / 0.35) * 0.50;
    return (1.0 - (p - 0.35) / 0.65) * 0.50;
  }

  bool isDone(double nowMs) => (nowMs - startTimeMs) >= 360.0;
}

/// Controller and animator driving all dynamic rendering on a single Ticker as a ChangeNotifier.
class BoardAnimator extends ChangeNotifier {
  BoardAnimator({
    required TickerProvider vsync,
  }) {
    _ticker = vsync.createTicker(_handleTick);
    _stopwatch.start();
  }

  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();

  final Map<int, ThreadGeometry> geometries = {};
  final Map<int, ActiveExit> exits = {};
  final Map<int, ActiveBlocked> blockeds = {};

  int? hintedThreadId;
  double? hintStartTimeMs;

  double? enterStartTimeMs;
  double enterTotalMs = 0.0;

  double get nowMs => _stopwatch.elapsedMicroseconds / 1000.0;

  bool get hasActiveAnimations =>
      exits.isNotEmpty ||
      blockeds.isNotEmpty ||
      hintedThreadId != null ||
      (enterStartTimeMs != null && (nowMs - enterStartTimeMs!) < enterTotalMs);

  void setLevel(Level level, double cellSize) {
    geometries.clear();
    exits.clear();
    blockeds.clear();
    hintedThreadId = null;
    hintStartTimeMs = null;
    enterStartTimeMs = null;

    for (final t in level.threads) {
      geometries[t.id] = ThreadGeometry(
        thread: t,
        cellSize: cellSize,
        rows: level.rows,
        cols: level.cols,
      );
    }
  }

  void startEntrance(int threadCount, {required bool reduceMotion}) {
    if (reduceMotion) {
      enterStartTimeMs = null;
      return;
    }
    enterTotalMs = math.min(threadCount * 8.0 + 320.0, 520.0);
    enterStartTimeMs = nowMs;
    _ensureTicker();
  }

  double entranceProgressFor(int threadIndex, {required bool reduceMotion}) {
    if (reduceMotion || enterStartTimeMs == null) return 1.0;
    final elapsed = nowMs - enterStartTimeMs!;
    final delay = threadIndex * 8.0;
    if (elapsed < delay) return 0.0;
    const duration = 320.0;
    final p = ((elapsed - delay) / duration).clamp(0.0, 1.0);
    return Primitives.curveEnter.transform(p);
  }

  void triggerExit(
    int threadId, {
    required bool reduceMotion,
    ui.Color? particleColor,
  }) {
    final geom = geometries[threadId];
    if (geom == null) return;

    exits[threadId] = ActiveExit(
      threadId: threadId,
      geometry: geom,
      startTimeMs: nowMs,
      reduceMotion: reduceMotion,
    );

    if (hintedThreadId == threadId) {
      hintedThreadId = null;
    }

    _ensureTicker();
    notifyListeners();
  }

  void triggerBlocked({
    required int threadId,
    required Blocker blocker,
    required double cellSize,
    required bool reduceMotion,
  }) {
    blockeds[threadId] = ActiveBlocked(
      threadId: threadId,
      blockerId: blocker.id,
      distanceNodes: blocker.distanceCells,
      cellSize: cellSize,
      startTimeMs: nowMs,
      reduceMotion: reduceMotion,
    );

    _ensureTicker();
    notifyListeners();
  }

  void triggerHint(int threadId) {
    hintedThreadId = threadId;
    hintStartTimeMs = nowMs;
    _ensureTicker();
    notifyListeners();
  }

  void _ensureTicker() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _handleTick(Duration elapsed) {
    final currentMs = nowMs;

    // Prune finished exits
    final completedExits = <int>[];
    for (final exit in exits.values) {
      if (exit.isDone(currentMs)) {
        completedExits.add(exit.threadId);
      }
    }
    for (final id in completedExits) {
      exits.remove(id);
    }

    // Prune finished blocked bounces
    final completedBlockeds = <int>[];
    for (final b in blockeds.values) {
      if (b.isDone(currentMs)) {
        completedBlockeds.add(b.threadId);
      }
    }
    for (final id in completedBlockeds) {
      blockeds.remove(id);
    }

    // Prune hint if expired (>2200ms)
    if (hintStartTimeMs != null && (currentMs - hintStartTimeMs!) >= 2200.0) {
      hintedThreadId = null;
      hintStartTimeMs = null;
    }

    notifyListeners();

    if (!hasActiveAnimations && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
