import 'dart:math' as math;
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';

/// 2D point in board coordinate space (where node (r,c) is at (c, r)).
class BoardPoint {
  const BoardPoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(BoardPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => 'Point($x, $y)';
}

/// A line segment between two board points (e.g. consecutive nodes or arrowhead chevron arms).
class BoardSegment {
  const BoardSegment(this.p1, this.p2, this.threadId);

  final BoardPoint p1;
  final BoardPoint p2;
  final int threadId;

  /// Computes the minimum distance from [p] to this line segment, and whether
  /// the projection falls strictly inside the segment interior.
  (double distance, bool isInterior) distanceToPoint(BoardPoint p) {
    final l2 = (p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y);
    if (l2 == 0) {
      return (p.distanceTo(p1), false);
    }
    // Projection factor t on segment [0, 1]
    final t =
        ((p.x - p1.x) * (p2.x - p1.x) + (p.y - p1.y) * (p2.y - p1.y)) / l2;
    if (t <= 0.0) {
      return (p.distanceTo(p1), false);
    }
    if (t >= 1.0) {
      return (p.distanceTo(p2), false);
    }
    final proj = BoardPoint(p1.x + t * (p2.x - p1.x), p1.y + t * (p2.y - p1.y));
    return (p.distanceTo(proj), true);
  }
}

/// Spatial index for fast O(1) hit testing on the board.
///
/// Indexes thread centre-line segments AND arrowhead chevron arms, with padding
/// bucket support so edge taps and dense lattice taps resolve reliably.
class SpatialHitIndex {
  SpatialHitIndex(Level level)
      : rows = level.rows,
        cols = level.cols {
    _buildIndex(level);
  }

  final int rows;
  final int cols;
  final Map<Cell, List<BoardSegment>> _cellBuckets = {};

  void _buildIndex(Level level) {
    for (final thread in level.threads) {
      // 1. Thread body segments between consecutive nodes
      for (var i = 0; i < thread.cells.length - 1; i++) {
        final c1 = thread.cells[i];
        final c2 = thread.cells[i + 1];
        final p1 = BoardPoint(c1.c.toDouble(), c1.r.toDouble());
        final p2 = BoardPoint(c2.c.toDouble(), c2.r.toDouble());
        final seg = BoardSegment(p1, p2, thread.id);

        _bucketSegment(c1, seg);
        _bucketSegment(c2, seg);
      }

      // 2. Arrowhead chevron arms at the head node
      final head = thread.head;
      final headTip = BoardPoint(head.c.toDouble(), head.r.toDouble());
      final angle = _dirToAngle(thread.dir);
      const armLengthCells = 0.23; // Spec 13: 0.23 * cell
      const halfAngleRad = 40.0 * math.pi / 180.0;

      final arm1End = BoardPoint(
        headTip.x - math.cos(angle - halfAngleRad) * armLengthCells,
        headTip.y - math.sin(angle - halfAngleRad) * armLengthCells,
      );
      final arm2End = BoardPoint(
        headTip.x - math.cos(angle + halfAngleRad) * armLengthCells,
        headTip.y - math.sin(angle + halfAngleRad) * armLengthCells,
      );

      final armSeg1 = BoardSegment(headTip, arm1End, thread.id);
      final armSeg2 = BoardSegment(headTip, arm2End, thread.id);

      _bucketSegment(head, armSeg1);
      _bucketSegment(head, armSeg2);
    }
  }

  void _bucketSegment(Cell cell, BoardSegment seg) {
    // Add to target cell and surrounding neighbourhood (including negative padding cells)
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = cell.r + dr;
        final c = cell.c + dc;
        if (r >= -2 && r <= rows + 1 && c >= -2 && c <= cols + 1) {
          final bucket = _cellBuckets.putIfAbsent(Cell(r, c), () => []);
          if (!bucket.contains(seg)) {
            bucket.add(seg);
          }
        }
      }
    }
  }

  /// Finds the closest active thread to [tapPoint] within [tapToleranceCells].
  ///
  /// Ties: smaller distance wins, then interior projection wins, then lower ID.
  int? findHitThread({
    required BoardPoint tapPoint,
    required Set<int> activeThreadIds,
    double tapToleranceCells = 0.5,
  }) {
    final cr = tapPoint.y.floor();
    final cc = tapPoint.x.floor();

    // Query 3x3 neighbourhood around tap point to cover boundary edges & padding
    final candidates = <BoardSegment>{};
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final bucket = _cellBuckets[Cell(cr + dr, cc + dc)];
        if (bucket != null) {
          candidates.addAll(bucket);
        }
      }
    }

    if (candidates.isEmpty) return null;

    int? bestThreadId;
    var bestDistance = double.infinity;
    var bestIsInterior = false;

    for (final seg in candidates) {
      if (!activeThreadIds.contains(seg.threadId)) continue;

      final (dist, isInterior) = seg.distanceToPoint(tapPoint);
      if (dist > tapToleranceCells) continue;

      if (dist < bestDistance - 1e-6) {
        bestDistance = dist;
        bestIsInterior = isInterior;
        bestThreadId = seg.threadId;
      } else if ((dist - bestDistance).abs() <= 1e-6) {
        // Tie break: interior projection over endpoint
        if (isInterior && !bestIsInterior) {
          bestDistance = dist;
          bestIsInterior = isInterior;
          bestThreadId = seg.threadId;
        } else if (isInterior == bestIsInterior) {
          // Tie break: lower thread ID
          if (bestThreadId == null || seg.threadId < bestThreadId) {
            bestThreadId = seg.threadId;
          }
        }
      }
    }

    return bestThreadId;
  }

  static double _dirToAngle(Dir dir) => switch (dir) {
        Dir.right => 0.0,
        Dir.down => math.pi / 2.0,
        Dir.left => math.pi,
        Dir.up => -math.pi / 2.0,
      };
}
