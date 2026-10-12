import 'package:arrowtapout/engine/hit_test_geometry.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:flutter/widgets.dart';

/// Converts screen-space touch coordinates into board-space hits.
class BoardHitTester {
  BoardHitTester(Level level) : _spatialIndex = SpatialHitIndex(level);

  final SpatialHitIndex _spatialIndex;

  /// Hit-tests a local tap position in board pixel coordinates.
  int? hitTest({
    required Offset localPosition,
    required double cellSize,
    required Set<int> activeThreadIds,
    double tapToleranceCells = 0.65,
  }) {
    if (cellSize <= 0) return null;

    final boardPoint = BoardPoint(
      localPosition.dx / cellSize,
      localPosition.dy / cellSize,
    );

    return _spatialIndex.findHitThread(
      tapPoint: boardPoint,
      activeThreadIds: activeThreadIds,
      tapToleranceCells: tapToleranceCells,
    );
  }
}
