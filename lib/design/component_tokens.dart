import 'dart:math' as math;

/// Component-level geometry and measurement calculations according to Revision 2.
abstract final class ComponentTokens {
  static const double pagePadding = 20.0;
  static const double boardVerticalPad = 12.0;
  static const double maxCellSize = 46.0;
  static const double zoomThresholdCellSize = 16.0;
  static const double minTapTargetSize = 48.0;
  static const double mistakeDotSize = 8.0;
  static const double mistakeDotGap = 10.0;
  static const double heartSize = 20.0;
  static const double heartGap = 6.0;

  /// Computes the thread stroke width for a given [cellSize] in logical pixels.
  static double threadStroke(double cellSize) {
    return (cellSize * 0.06).clamp(1.6, 2.4);
  }

  /// Computes the chevron arrowhead arm length for a given [cellSize].
  static double arrowheadArm(double cellSize) {
    return (cellSize * 0.23).clamp(4.0, 9.0);
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
  /// `cell = (screenWidth - 2*pagePad) / (cols - 1)`, clamped to at most
  /// `(boardRegionHeight - 2*12dp) / (rows - 1)`, at most 46dp, snapped to whole physical pixel.
  static double computeLatticeCellSize({
    required double screenWidth,
    required double boardRegionHeight,
    required int rows,
    required int cols,
    double devicePixelRatio = 1.0,
    bool isInnerContainer = false,
  }) {
    final denomW = math.max(1, cols - 1);
    final denomH = math.max(1, rows - 1);

    final padW = isInnerContainer ? 4.0 : 2 * pagePadding;
    final padH = isInnerContainer ? 4.0 : 2 * boardVerticalPad;

    final rawW = (screenWidth - padW) / denomW;
    final maxH = (boardRegionHeight - padH) / denomH;

    final rawCell = math.min(rawW, maxH).clamp(0.0, maxCellSize);
    return snapCellSize(rawCell, devicePixelRatio);
  }
}
