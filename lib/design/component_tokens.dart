import 'dart:math' as math;

/// Component-level geometry and measurement calculations according to Revision 2.
abstract final class ComponentTokens {
  static const double pagePadding = 20.0;
  static const double boardVerticalPad = 12.0;
  static const double maxCellSize = 46.0;
  static const double zoomThresholdCellSize = 32.0;
  static const double minTapTargetSize = 48.0;
  static const double mistakeDotSize = 8.0;
  static const double mistakeDotGap = 10.0;
  static const double heartSize = 20.0;
  static const double heartGap = 6.0;

  /// Computes the thread stroke width for a given [cellSize] in logical pixels.
  static double threadStroke(double cellSize) {
    return (cellSize * 0.14).clamp(3.0, 5.5);
  }

  /// Computes the chevron arrowhead arm length for a given [cellSize].
  static double arrowheadArm(double cellSize) {
    return (cellSize * 0.44).clamp(10.0, 18.0);
  }

  /// Computes the grid dot radius for a given [cellSize].
  static double gridDotRadius(double cellSize) {
    return (cellSize * 0.05).clamp(1.2, 2.2);
  }

  /// Computes the tap tolerance distance in cell units (0.5 cells).
  static const double tapToleranceCells = 0.5;

  /// Snaps [cellSize] down to whole physical pixel to maintain crisp strokes.
  static double snapCellSize(double rawCell, double devicePixelRatio) {
    if (devicePixelRatio <= 0) return rawCell;
    return (rawCell * devicePixelRatio).floorToDouble() / devicePixelRatio;
  }

  /// Computes optimal lattice cell size:
  /// Ensures the grid, hit padding, and arrowheads pointing outward from border nodes
  /// have complete clearance and never get clipped by the viewport boundaries.
  static double computeLatticeCellSize({
    required double screenWidth,
    required double boardRegionHeight,
    required int rows,
    required int cols,
    double devicePixelRatio = 1.0,
    bool isInnerContainer = false,
  }) {
    // Outermost border nodes need headroom for outward-pointing arrowheads & padding (~0.7 cell each side)
    const clearanceFactor = 1.4;
    final denomW = math.max(1.0, (cols - 1) + clearanceFactor);
    final denomH = math.max(1.0, (rows - 1) + clearanceFactor);

    const padW = 2 * pagePadding;
    const padH = 2 * boardVerticalPad;

    final rawW = math.max(0.0, (screenWidth - padW) / denomW);
    final maxH = math.max(0.0, (boardRegionHeight - padH) / denomH);

    final rawCell = math.min(rawW, maxH).clamp(0.0, maxCellSize);
    return snapCellSize(rawCell, devicePixelRatio);
  }
}
