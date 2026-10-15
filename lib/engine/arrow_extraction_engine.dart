import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/thread.dart';

/// Pure mathematical evaluation for the extraction displacement along the track per Spec 13:
///
/// p(u) = D * u^2.2 - A * sin^2(pi * min(u / 0.20, 1))
double calculateExitDisplacement({
  required double u,
  required double totalDistanceD,
  double anticipationA = 0.0,
}) {
  final clampedU = u.clamp(0.0, 1.0);
  final mainSlide = totalDistanceD * math.pow(clampedU, 2.2);

  if (anticipationA <= 0.0) {
    return mainSlide;
  }

  final waveT = math.min(clampedU / 0.20, 1.0);
  final s = math.sin(math.pi * waveT);
  final anticipation = anticipationA * (s * s);

  return mainSlide - anticipation;
}

/// Instantaneous geometric state of an arrow being extracted along its path.
class ExtractedGeometry {
  const ExtractedGeometry({
    required this.visiblePath,
    required this.headPosition,
    required this.headAngleRad,
    required this.alpha,
    required this.isCompleted,
    required this.displacementPx,
  });

  /// The continuous sub-path polyline that is currently visible on the board.
  final ui.Path visiblePath;

  /// The leading position of the arrowhead tip in pixel coordinates.
  final ui.Offset headPosition;

  /// The orientation of the arrowhead in radians (tangent of the path).
  final double headAngleRad;

  /// Opacity multiplier for the thread (fades out over u from 0.85 to 1.0).
  final double alpha;

  /// Whether the arrow has completely exited the visible viewport.
  final bool isCompleted;

  /// Arc-length displacement distance traveled so far in pixels.
  final double displacementPx;
}

/// A pre-computed, continuous extraction track for an arrow polyline.
///
/// Extended path per Spec 13:
/// Virtual backward stub (0.3*cell) -> thread body -> straight ray -> (0.6*cell + L) extra straight run.
class ExtractionTrack {
  ExtractionTrack({
    required this.thread,
    required this.cellSize,
    required this.rows,
    required this.cols,
  }) {
    _buildTrack();
  }

  final Thread thread;
  final double cellSize;
  final int rows;
  final int cols;

  late final ui.Path fullTrackPath;
  late final ui.PathMetric trackMetric;
  late final double threadLengthPx;
  late final double rayLengthPx;
  late final double totalDistanceD;
  late final double anticipationA;
  late final double stubLengthPx;
  late final double durationMs;

  void _buildTrack() {
    threadLengthPx = (thread.cells.length - 1) * cellSize;

    final head = thread.head;
    rayLengthPx = switch (thread.dir) {
      Dir.up => head.r * cellSize,
      Dir.down => (rows - 1 - head.r) * cellSize,
      Dir.left => head.c * cellSize,
      Dir.right => (cols - 1 - head.c) * cellSize,
    };

    // Spec 13: D = ray + L + 0.6*cell, A = 0.16*cell
    final extraRun = 0.6 * cellSize + threadLengthPx;
    totalDistanceD = rayLengthPx + extraRun;
    anticipationA = 0.16 * cellSize;
    stubLengthPx = 0.3 * cellSize;

    // Spec 13: T = clamp(300ms + 9ms * (D / cell), 340ms, 820ms)
    durationMs = (300.0 + 9.0 * (totalDistanceD / cellSize)).clamp(340.0, 820.0);

    // Build the continuous polyline track:
    // Virtual backward stub (0.3*cell) -> tail -> vertices -> head -> grid edge -> extra run
    fullTrackPath = ui.Path();

    final c0 = thread.cells[0];
    final c1 = thread.cells[1];
    final stubDirX = (c0.c - c1.c).toDouble().sign;
    final stubDirY = (c0.r - c1.r).toDouble().sign;

    final stubX = c0.c * cellSize + stubDirX * stubLengthPx;
    final stubY = c0.r * cellSize + stubDirY * stubLengthPx;

    fullTrackPath.moveTo(stubX, stubY);
    fullTrackPath.lineTo(c0.c * cellSize, c0.r * cellSize);

    for (var i = 1; i < thread.cells.length; i++) {
      final c = thread.cells[i];
      fullTrackPath.lineTo(c.c * cellSize, c.r * cellSize);
    }

    // Edge node coordinate along exit ray
    final edgeNodeC = switch (thread.dir) {
      Dir.left => 0.0,
      Dir.right => (cols - 1).toDouble(),
      _ => head.c.toDouble(),
    };
    final edgeNodeR = switch (thread.dir) {
      Dir.up => 0.0,
      Dir.down => (rows - 1).toDouble(),
      _ => head.r.toDouble(),
    };
    fullTrackPath.lineTo(edgeNodeC * cellSize, edgeNodeR * cellSize);

    // Final off-screen point
    final finalX = edgeNodeC * cellSize + thread.dir.dx * extraRun;
    final finalY = edgeNodeR * cellSize + thread.dir.dy * extraRun;
    fullTrackPath.lineTo(finalX, finalY);

    final metrics = fullTrackPath.computeMetrics().toList();
    trackMetric = metrics.first;
  }

  /// Samples the path-aware extracted geometry at normalized animation progress [progress] (0.0 to 1.0).
  ExtractedGeometry sample(
    double progress, {
    bool reduceMotion = false,
  }) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    if (reduceMotion) {
      // In reduced motion mode, linear slide with fade
      final alpha = (1.0 - clampedProgress).clamp(0.0, 1.0);
      final head = thread.head;
      final headPos = ui.Offset(head.c * cellSize, head.r * cellSize);
      final angle = _dirToAngle(thread.dir);

      final basePath = ui.Path();
      basePath.moveTo(
          thread.cells.first.c * cellSize, thread.cells.first.r * cellSize);
      for (var i = 1; i < thread.cells.length; i++) {
        basePath.lineTo(
            thread.cells[i].c * cellSize, thread.cells[i].r * cellSize);
      }

      return ExtractedGeometry(
        visiblePath: basePath,
        headPosition: headPos,
        headAngleRad: angle,
        alpha: alpha,
        isCompleted: clampedProgress >= 1.0,
        displacementPx: 0.0,
      );
    }

    final p = calculateExitDisplacement(
      u: clampedProgress,
      totalDistanceD: totalDistanceD,
      anticipationA: anticipationA,
    );

    // Visible window is [stubLength + p, stubLength + p + L] along extended path
    final startOffset = (stubLengthPx + p).clamp(0.0, trackMetric.length);
    final endOffset =
        (stubLengthPx + p + threadLengthPx).clamp(0.0, trackMetric.length);

    // Extract continuous sub-path polyline
    final visiblePath = (endOffset > startOffset)
        ? trackMetric.extractPath(startOffset, endOffset)
        : ui.Path();

    // Sample tangent for chevron arrowhead
    final sampleOffset = endOffset.clamp(0.001, trackMetric.length - 0.001);
    final tangent = trackMetric.getTangentForOffset(sampleOffset);

    final headPos = tangent?.position ??
        ui.Offset(thread.head.c * cellSize, thread.head.r * cellSize);

    final headAngle = tangent != null
        ? math.atan2(tangent.vector.dy, tangent.vector.dx)
        : _dirToAngle(thread.dir);

    // Spec 13: Fade alpha multiplies 1 to 0 over u from 0.85 to 1.0
    final alpha = clampedProgress >= 0.85
        ? ((1.0 - clampedProgress) / 0.15).clamp(0.0, 1.0)
        : 1.0;

    return ExtractedGeometry(
      visiblePath: visiblePath,
      headPosition: headPos,
      headAngleRad: headAngle,
      alpha: alpha,
      isCompleted: clampedProgress >= 1.0,
      displacementPx: p,
    );
  }

  static double _dirToAngle(Dir dir) => switch (dir) {
        Dir.right => 0.0,
        Dir.down => math.pi / 2.0,
        Dir.left => math.pi,
        Dir.up => -math.pi / 2.0,
      };
}
