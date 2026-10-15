import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/deflector.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/solver.dart';
import 'package:arrowtapout/engine/thread.dart';

/// Offline deterministic daily thread service with 8 board symmetries.
class DailyThreadService {
  const DailyThreadService._();

  static int hashDate(DateTime date) {
    final y = date.year;
    final m = date.month;
    final d = date.day;
    var hash = 2166136261;
    hash = (hash ^ y) * 16777619;
    hash = (hash ^ m) * 16777619;
    hash = (hash ^ d) * 16777619;
    return hash.abs();
  }

  /// Returns deterministic level ID (1 to 200) for the given date.
  static int getDailyLevelId([DateTime? date]) {
    final d = date ?? DateTime.now();
    final h = hashDate(d);
    return (h % 200) + 1;
  }

  /// Returns deterministic symmetry index (0 to 7) for the given date.
  static int getDailySymmetryIndex([DateTime? date]) {
    final d = date ?? DateTime.now();
    final h = hashDate(d);
    return (h >> 8) % 8;
  }

  /// Applies one of the 8 symmetries to the given level.
  /// Solvability is topologically invariant under rigid reflections and rotations.
  static Level applySymmetry(Level level, int symmetryIndex) {
    if (symmetryIndex == 0) return level;

    final mirrorH = (symmetryIndex & 4) != 0;
    final rotations = symmetryIndex & 3; // 0, 1, 2, or 3 (90 deg clockwise each)

    var curRows = level.rows;
    var curCols = level.cols;

    List<Thread> transformedThreads = level.threads.map((t) {
      return Thread(
        t.id,
        List<Cell>.from(t.cells),
        colorGroup: t.colorGroup,
      );
    }).toList();

    List<Deflector> transformedDeflectors = List<Deflector>.from(level.deflectors);

    // 1. Mirror horizontally if requested
    if (mirrorH) {
      transformedThreads = transformedThreads.map((t) {
        final newCells = t.cells.map((c) => Cell(c.r, curCols - 1 - c.c)).toList();
        return Thread(t.id, newCells, colorGroup: t.colorGroup);
      }).toList();

      transformedDeflectors = transformedDeflectors.map((d) {
        final newCell = Cell(d.cell.r, curCols - 1 - d.cell.c);
        final newDir = switch (d.dir) {
          Dir.left => Dir.right,
          Dir.right => Dir.left,
          Dir.up => Dir.up,
          Dir.down => Dir.down,
        };
        return Deflector(cell: newCell, dir: newDir);
      }).toList();
    }

    // 2. Apply clockwise 90 degree rotations
    for (var rot = 0; rot < rotations; rot++) {
      final oldRows = curRows;
      final oldCols = curCols;
      curRows = oldCols;
      curCols = oldRows;

      transformedThreads = transformedThreads.map((t) {
        final newCells = t.cells.map((c) => Cell(c.c, oldRows - 1 - c.r)).toList();
        return Thread(t.id, newCells, colorGroup: t.colorGroup);
      }).toList();

      transformedDeflectors = transformedDeflectors.map((d) {
        final newCell = Cell(d.cell.c, oldRows - 1 - d.cell.r);
        final newDir = switch (d.dir) {
          Dir.up => Dir.right,
          Dir.right => Dir.down,
          Dir.down => Dir.left,
          Dir.left => Dir.up,
        };
        return Deflector(cell: newCell, dir: newDir);
      }).toList();
    }

    final transformedLevel = Level(
      id: level.id,
      chapter: level.chapter,
      rows: curRows,
      cols: curCols,
      threads: transformedThreads,
      deflectors: transformedDeflectors,
    );

    // Verify solvability in debug builds
    assert(() {
      final solution = solve(transformedLevel);
      return solution.isSolved;
    }(), 'Transformed daily level must remain solvable.');

    return transformedLevel;
  }
}
