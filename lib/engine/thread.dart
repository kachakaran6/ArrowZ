import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/dir.dart';

/// A thread path on the grid, oriented from tail to head.
///
/// The head carries an arrowhead pointing along [dir].
class Thread {
  Thread(this.id, List<Cell> cells, {this.colorGroup})
      : cells = List.unmodifiable(cells) {
    if (cells.length < 2) {
      throw ArgumentError('Thread must contain at least 2 cells.');
    }
  }

  /// Unique identifier of this thread within its level.
  final int id;

  /// Optional color pair group ID. Paired threads share the same group ID.
  final int? colorGroup;

  /// Ordered cells from tail (`cells.first`) to head (`cells.last`).
  final List<Cell> cells;

  /// The head cell carrying the arrowhead.
  Cell get head => cells.last;

  /// The tail cell at the beginning of the thread.
  Cell get tail => cells.first;

  /// Number of cells in the thread polyline.
  int get length => cells.length;

  /// Exit direction determined by the final segment ending at [head].
  Dir get dir {
    final a = cells[cells.length - 2];
    final b = cells.last;
    if (b.r < a.r) return Dir.up;
    if (b.r > a.r) return Dir.down;
    return b.c > a.c ? Dir.right : Dir.left;
  }

  /// Checks if consecutive cells are orthogonally adjacent.
  bool get isOrthogonallyConnected {
    for (var i = 0; i < cells.length - 1; i++) {
      final a = cells[i];
      final b = cells[i + 1];
      final dr = (b.r - a.r).abs();
      final dc = (b.c - a.c).abs();
      if ((dr + dc) != 1) return false;
    }
    return true;
  }

  /// Checks if the path does not intersect itself.
  bool get isSelfAvoiding {
    final seen = <Cell>{};
    for (final c in cells) {
      if (!seen.add(c)) return false;
    }
    return true;
  }

  @override
  String toString() => 'Thread#$id(len: $length, head: $head, dir: $dir)';
}
