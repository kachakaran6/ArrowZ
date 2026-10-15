import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/solver.dart';

/// Result of level validation.
class ValidityResult {
  const ValidityResult.valid(
      {required this.depth, required this.initialFreeCount})
      : isValid = true,
        error = null;

  const ValidityResult.invalid(this.error)
      : isValid = false,
        depth = 0,
        initialFreeCount = 0;

  final bool isValid;
  final String? error;
  final int depth;
  final int initialFreeCount;

  @override
  String toString() => isValid
      ? 'Valid(depth: $depth, initFree: $initialFreeCount)'
      : 'Invalid($error)';
}

/// Validates all engine and visual rules for a [Level].
ValidityResult validateLevel(Level level) {
  if (level.threads.isEmpty) {
    return const ValidityResult.invalid('Level contains no threads.');
  }

  final occupiedCells = <Cell, int>{};

  for (final t in level.threads) {
    // 1. Minimum length >= 2
    if (t.cells.length < 2) {
      return ValidityResult.invalid('Thread #${t.id} has length < 2.');
    }

    // Orthogonality
    if (!t.isOrthogonallyConnected) {
      return ValidityResult.invalid(
          'Thread #${t.id} has non-orthogonal steps.');
    }

    // Self-avoidance
    if (!t.isSelfAvoiding) {
      return ValidityResult.invalid('Thread #${t.id} intersects itself.');
    }

    // Grid bounds check
    for (final c in t.cells) {
      if (c.r < 0 || c.r >= level.rows || c.c < 0 || c.c >= level.cols) {
        return ValidityResult.invalid(
          'Thread #${t.id} cell $c is out of bounds [${level.rows}x${level.cols}].',
        );
      }
      // 2. No shared cells
      if (occupiedCells.containsKey(c)) {
        return ValidityResult.invalid(
          'Threads #${occupiedCells[c]} and #${t.id} share cell $c.',
        );
      }
      occupiedCells[c] = t.id;
    }

    // 3. No thread's ray intersects its own cells
    final deflectorMap = {for (final d in level.deflectors) d.cell: d.dir};
    final ownCells = t.cells.toSet();
    for (final rayCell in BoardState.ray(t, level.rows, level.cols, deflectorMap)) {
      if (ownCells.contains(rayCell)) {
        return ValidityResult.invalid(
          'Thread #${t.id} ray intersects its own body at $rayCell.',
        );
      }
    }
  }

  // 4. Solvability by greedy solver
  final solveRes = solve(level);
  if (!solveRes.isSolved) {
    return const ValidityResult.invalid('Level is unsolvable.');
  }

  return ValidityResult.valid(
    depth: solveRes.depth,
    initialFreeCount: solveRes.initialFreeCount,
  );
}
