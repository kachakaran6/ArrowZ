import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:arrowtapout/engine/arrow_extraction_engine.dart';
import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/deflector.dart';
import 'package:arrowtapout/engine/dir.dart';
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
    this.deflectors = const [],
  }) : track = ExtractionTrack(
          thread: thread,
          cellSize: cellSize,
          rows: rows,
          cols: cols,
          deflectors: deflectors,
        ) {
    _buildBasePath();
  }

  final Thread thread;
  final double cellSize;
  final int rows;
  final int cols;
  final List<Deflector> deflectors;
  final ExtractionTrack track;

  late final ui.Path basePath;
  late final ui.Offset headOffset;
  late final double headAngle;

  void _buildBasePath() {
    basePath = ui.Path();
    final first = thread.cells.first;
    basePath.moveTo(first.c * cellSize, first.r * cellSize);
    for (var i = 1; i < thread.cells.length; i++) {
      final c = thread.cells[i];
      basePath.lineTo(c.c * cellSize, c.r * cellSize);
    }
    headOffset = ui.Offset(thread.head.c * cellSize, thread.head.r * cellSize);
    headAngle = switch (thread.dir) {
      Dir.right => 0.0,
      Dir.down => math.pi / 2.0,
      Dir.left => math.pi,
      Dir.up => -math.pi / 2.0,
    };
  }
}

/// Active exit animation state for one thread driving path-aware extraction.
class ActiveExit {
  ActiveExit({
    required this.threadId,
    required ThreadGeometry geometry,
    required this.startTimeMs,
    required this.reduceMotion,
  })  : _geometry = geometry,
        durationMs = reduceMotion ? 180.0 : geometry.track.durationMs;

  final int threadId;
  ThreadGeometry _geometry;
  ThreadGeometry get geometry => _geometry;
  double durationMs;
  final double startTimeMs;
  final bool reduceMotion;

  /// Updates the underlying geometry while preserving elapsed animation progress.
  void updateGeometry(ThreadGeometry newGeometry) {
    _geometry = newGeometry;
    durationMs = reduceMotion ? 180.0 : newGeometry.track.durationMs;
  }

  double progress(double nowMs) {
    if (durationMs <= 0) return 1.0;
    return ((nowMs - startTimeMs) / durationMs).clamp(0.0, 1.0);
  }

  ExtractedGeometry sampleGeometry(double nowMs) {
    final p = progress(nowMs);
    if (p > 0.0) {
      Diagnostics.instance.recordFirstMotion(threadId);
    }
    return _geometry.track.sample(p, reduceMotion: reduceMotion);
  }

  bool isDone(double nowMs) => progress(nowMs) >= 1.0;
}

/// Active wrong move animation driving temporary red highlight and controlled shake.
class ActiveWrongMove {
  ActiveWrongMove({
    required this.threadId,
    required this.dir,
    required this.startTimeMs,
    required this.reduceMotion,
    this.durationMs = 240.0,
    this.maxDisplacementPx = 4.0,
  });

  final int threadId;
  final Dir dir;
  final double startTimeMs;
  final bool reduceMotion;
  final double durationMs;
  final double maxDisplacementPx;

  double progress(double nowMs) {
    if (durationMs <= 0) return 1.0;
    return ((nowMs - startTimeMs) / durationMs).clamp(0.0, 1.0);
  }

  bool isDone(double nowMs) => (nowMs - startTimeMs) >= durationMs;

  /// Returns perpendicular shake offset in logical pixels.
  /// 3 full cycles with smooth decay to 0.
  ui.Offset shakeOffset(double nowMs) {
    if (reduceMotion) return ui.Offset.zero;
    final p = progress(nowMs);
    if (p >= 1.0) return ui.Offset.zero;

    final decay = 1.0 - p;
    final wave = math.sin(p * 6.0 * math.pi);
    final displacement = maxDisplacementPx * wave * decay;

    final perpX = dir.dy.abs();
    final perpY = dir.dx.abs();

    return ui.Offset(perpX * displacement, perpY * displacement);
  }

  /// Danger color lerp factor in [0.0, 1.0].
  /// Arrow turns visibly red immediately, then fades smoothly back to theme color.
  double dangerLerp(double nowMs) {
    final p = progress(nowMs);
    if (p >= 1.0) return 0.0;
    if (p <= 0.6) return 1.0;
    return (1.0 - p) / 0.4;
  }
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

  Level? _currentLevel;
  double _currentCellSize = 0.0;

  Level? get currentLevel => _currentLevel;
  double get currentCellSize => _currentCellSize;

  bool get hasActiveExits => exits.isNotEmpty;
  int get activeExitCount => exits.length;

  /// Callback fired when an exit animation finishes naturally along its track.
  void Function(int threadId)? onExitCompleted;

  /// Callback fired when all active in-flight exit animations have completed.
  ui.VoidCallback? onAllExitsCompleted;

  // Reusable scratch buffers to eliminate allocations during tight 60/120 Hz ticker loops
  final List<int> _scratchCompletedExits = [];
  final List<int> _scratchCompletedWrongMoves = [];
  final List<int> _scratchCompletedBlockeds = [];
  final List<int> _scratchStuckExits = [];
  final List<int> _scratchStuckBlockeds = [];

  final Map<int, ThreadGeometry> geometries = {};
  final Map<int, ActiveExit> exits = {};
  final Map<int, ActiveBlocked> blockeds = {};
  final Map<int, ActiveWrongMove> wrongMoves = {};

  int? hintedThreadId;
  double? hintStartTimeMs;

  double? enterStartTimeMs;
  double enterTotalMs = 0.0;

  double? _testClockMs;

  double get nowMs => _testClockMs ?? (_stopwatch.elapsedMicroseconds / 1000.0);

  /// Sets a deterministic clock for automated testing.
  @visibleForTesting
  void setTestClockMs(double ms) {
    _testClockMs = ms;
  }

  /// Advances the test clock by [deltaMs] and evaluates a tick.
  @visibleForTesting
  void stepTimeMs(double deltaMs) {
    _testClockMs = nowMs + deltaMs;
    _handleTick(Duration(microseconds: (_testClockMs! * 1000).round()));
  }

  bool get hasActiveAnimations =>
      exits.isNotEmpty ||
      blockeds.isNotEmpty ||
      wrongMoves.isNotEmpty ||
      hintedThreadId != null ||
      (enterStartTimeMs != null && (nowMs - enterStartTimeMs!) < enterTotalMs);

  void setLevel(Level level, double cellSize) {
    _currentLevel = level;
    _currentCellSize = cellSize;
    geometries.clear();
    exits.clear();
    blockeds.clear();
    wrongMoves.clear();
    hintedThreadId = null;
    hintStartTimeMs = null;
    enterStartTimeMs = null;

    for (final t in level.threads) {
      geometries[t.id] = ThreadGeometry(
        thread: t,
        cellSize: cellSize,
        rows: level.rows,
        cols: level.cols,
        deflectors: level.deflectors,
      );
    }
  }

  /// Updates cell size across the active board (e.g. on orientation change, window resize,
  /// or system insets change) without wiping or interrupting active exit animations.
  void updateCellSize(double newCellSize) {
    if (_currentLevel == null ||
        newCellSize <= 0 ||
        (_currentCellSize - newCellSize).abs() < 1e-4) {
      return;
    }
    _currentCellSize = newCellSize;
    final level = _currentLevel!;

    for (final t in level.threads) {
      final newGeom = ThreadGeometry(
        thread: t,
        cellSize: newCellSize,
        rows: level.rows,
        cols: level.cols,
        deflectors: level.deflectors,
      );
      geometries[t.id] = newGeom;

      // Update in-flight active exit tracks with recalculated metric while preserving normalized progress
      final activeExit = exits[t.id];
      if (activeExit != null) {
        activeExit.updateGeometry(newGeom);
      }
    }

    notifyListeners();
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

    wrongMoves.remove(threadId);

    if (hintedThreadId == threadId) {
      hintedThreadId = null;
    }

    _ensureTicker();
    notifyListeners();
  }

  void triggerWrongMove({
    required int threadId,
    required Dir dir,
    required bool reduceMotion,
  }) {
    wrongMoves[threadId] = ActiveWrongMove(
      threadId: threadId,
      dir: dir,
      startTimeMs: nowMs,
      reduceMotion: reduceMotion,
    );

    _ensureTicker();
    notifyListeners();
  }

  void cancelWrongMoves() {
    wrongMoves.clear();
    notifyListeners();
  }

  /// Instantly finalizes all running animations (exits, blockeds, wrong moves)
  /// and stops the ticker so no animations survive transitions, restarts, or pauses.
  void finalizeAllRunningAnimations() {
    exits.clear();
    blockeds.clear();
    wrongMoves.clear();
    hintedThreadId = null;
    hintStartTimeMs = null;
    enterStartTimeMs = null;
    if (_ticker.isActive) {
      _ticker.stop();
    }
    Diagnostics.instance.updateAnimationStats(
      exiting: 0,
      bouncing: 0,
      oldestAgeMs: 0.0,
    );
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
    _scratchCompletedExits.clear();
    for (final exit in exits.values) {
      if (exit.isDone(currentMs)) {
        _scratchCompletedExits.add(exit.threadId);
      }
    }
    final hadExits = exits.isNotEmpty;
    for (final id in _scratchCompletedExits) {
      exits.remove(id);
      onExitCompleted?.call(id);
    }
    if (hadExits && exits.isEmpty) {
      onAllExitsCompleted?.call();
    }

    // Prune finished wrong move animations
    _scratchCompletedWrongMoves.clear();
    for (final wm in wrongMoves.values) {
      if (wm.isDone(currentMs)) {
        _scratchCompletedWrongMoves.add(wm.threadId);
      }
    }
    for (final id in _scratchCompletedWrongMoves) {
      wrongMoves.remove(id);
    }

    // Prune finished blocked bounces
    _scratchCompletedBlockeds.clear();
    for (final b in blockeds.values) {
      if (b.isDone(currentMs)) {
        _scratchCompletedBlockeds.add(b.threadId);
      }
    }
    for (final id in _scratchCompletedBlockeds) {
      blockeds.remove(id);
    }

    // Prune hint if expired (>2200ms)
    if (hintStartTimeMs != null && (currentMs - hintStartTimeMs!) >= 2200.0) {
      hintedThreadId = null;
      hintStartTimeMs = null;
    }

    // Stuck detector: any animation running longer than T + 250ms raises a logged error
    double oldestAge = 0.0;
    _scratchStuckExits.clear();
    for (final exit in exits.values) {
      final age = currentMs - exit.startTimeMs;
      if (age > oldestAge) oldestAge = age;
      final maxAllowed = exit.durationMs + 250.0;
      if (age > maxAllowed) {
        Diagnostics.instance.reportStuckAnimation(
          threadId: exit.threadId,
          state: 'exiting',
          ageMs: age,
          maxAllowedMs: maxAllowed,
        );
        _scratchStuckExits.add(exit.threadId);
      }
    }
    final hadStuckExits = _scratchStuckExits.isNotEmpty;
    for (final id in _scratchStuckExits) {
      exits.remove(id);
      onExitCompleted?.call(id);
    }
    if (hadStuckExits && exits.isEmpty) {
      onAllExitsCompleted?.call();
    }

    _scratchStuckBlockeds.clear();
    for (final b in blockeds.values) {
      final age = currentMs - b.startTimeMs;
      if (age > oldestAge) oldestAge = age;
      const maxAllowed = ActiveBlocked.totalMs + 250.0;
      if (age > maxAllowed) {
        Diagnostics.instance.reportStuckAnimation(
          threadId: b.threadId,
          state: 'bouncing',
          ageMs: age,
          maxAllowedMs: maxAllowed,
        );
        _scratchStuckBlockeds.add(b.threadId);
      }
    }
    for (final id in _scratchStuckBlockeds) {
      blockeds.remove(id);
    }

    Diagnostics.instance.updateAnimationStats(
      exiting: exits.length,
      bouncing: blockeds.length,
      oldestAgeMs: oldestAge,
    );

    notifyListeners();

    if (!hasActiveAnimations && _ticker.isActive) {
      _ticker.stop();
    }
  }

  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    super.dispose();
  }
}
