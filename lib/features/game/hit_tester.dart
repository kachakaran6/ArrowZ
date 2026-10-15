import 'dart:math' as math;
import 'package:arrowtapout/engine/hit_test_geometry.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:flutter/widgets.dart';

/// Converts screen-space touch coordinates into board-space hits.
class BoardHitTester {
  BoardHitTester(Level level) : _spatialIndex = SpatialHitIndex(level);

  final SpatialHitIndex _spatialIndex;

  /// Computes screen-space tap tolerance in logical pixels (dp).
  static double computeToleranceDp(double cellSize) =>
      math.max(0.5 * cellSize, 14.0);

  /// Hit-tests a local tap position in board pixel coordinates.
  ///
  /// Evaluates tapTolerance = max(0.5 * cell, 14 dp) in screen space.
  int? hitTest({
    required Offset localPosition,
    required double cellSize,
    required Set<int> activeThreadIds,
    double? tapToleranceCells,
  }) {
    if (cellSize <= 0) return null;

    final boardPoint = BoardPoint(
      localPosition.dx / cellSize,
      localPosition.dy / cellSize,
    );

    // Screen-space tolerance: max(0.5 * cell, 14 dp) converted to cell units
    final toleranceCells = tapToleranceCells ??
        (math.max(0.5 * cellSize, 14.0) / cellSize);

    return _spatialIndex.findHitThread(
      tapPoint: boardPoint,
      activeThreadIds: activeThreadIds,
      tapToleranceCells: toleranceCells,
    );
  }
}
