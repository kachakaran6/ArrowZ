import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';

/// Blocker details for a blocked thread tap.
class Blocker {
  const Blocker({
    required this.id,
    required this.distanceCells,
    required this.hitCell,
  });

  /// The ID of the blocking thread.
  final int id;

  /// The distance in grid cells from the head of the blocked thread to the blocker cell.
  final int distanceCells;

  /// The exact grid cell where collision occurs.
  final Cell hitCell;

  @override
  String toString() =>
      'Blocker(thread: $id, dist: $distanceCells, cell: $hitCell)';
}

/// Mutable engine state tracking cell occupancy and active threads.
class BoardState {
  BoardState(this.level)
      : rows = level.rows,
        cols = level.cols,
        threads = {for (final t in level.threads) t.id: t},
        active = {for (final t in level.threads) t.id},
        deflectorMap = {for (final d in level.deflectors) d.cell: d.dir},
        occupancy = {} {
    _initOccupancy();
  }

  /// Copy constructor for solver / simulation branching.
  BoardState.clone(BoardState other)
      : level = other.level,
        rows = other.rows,
        cols = other.cols,
        threads = other.threads,
        active = Set<int>.of(other.active),
        deflectorMap = other.deflectorMap,
        occupancy = Map<Cell, int>.of(other.occupancy);

  final Level level;
  final int rows;
  final int cols;
  final Map<int, Thread> threads;
  final Set<int> active;
  final Map<Cell, Dir> deflectorMap;
  final Map<Cell, int> occupancy;

  final Map<int, int> colorPartners = {};

  void _initOccupancy() {
    final groupToThread = <int, int>{};
    for (final t in level.threads) {
      for (final cell in t.cells) {
        occupancy[cell] = t.id;
      }
      if (t.colorGroup != null) {
        final g = t.colorGroup!;
        if (groupToThread.containsKey(g)) {
          final other = groupToThread[g]!;
          colorPartners[t.id] = other;
          colorPartners[other] = t.id;
        } else {
          groupToThread[g] = t.id;
        }
      }
    }
  }

  /// Generates the sequence of cells in the trajectory forward from [t.head]
  /// until leaving the bounding grid, redirecting at any deflectors encountered.
  static Iterable<Cell> ray(
    Thread t,
    int rows,
    int cols, [
    Map<Cell, Dir>? deflectors,
  ]) sync* {
    var curDir = t.dir;
    var r = t.head.r + curDir.dr;
    var c = t.head.c + curDir.dc;
    final visited = <int>{};

    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      final cell = Cell(r, c);
      yield cell;

      if (deflectors != null && deflectors.containsKey(cell)) {
        curDir = deflectors[cell]!;
        final key = (r << 16) | (c << 2) | curDir.index;
        if (!visited.add(key)) {
          break; // Infinite deflection loop protection
        }
      }

      r += curDir.dr;
      c += curDir.dc;
    }
  }

  /// Returns the ray cells for thread with [id].
  Iterable<Cell> rayFor(int id) {
    final t = threads[id];
    if (t == null) return const [];
    return ray(t, rows, cols, deflectorMap);
  }

  /// Checks if the thread with [id] has an unobstructed exit path.
  bool canExit(int id) {
    if (!active.contains(id)) return false;
    final t = threads[id]!;
    for (final cell in ray(t, rows, cols, deflectorMap)) {
      if (occupancy.containsKey(cell)) {
        return false;
      }
    }
    return true;
  }

  /// Finds the first blocking thread along the exit path of thread [id].
  Blocker? firstBlocker(int id) {
    if (!active.contains(id)) return null;
    final t = threads[id]!;
    var dist = 1;
    for (final cell in ray(t, rows, cols, deflectorMap)) {
      final blockerId = occupancy[cell];
      if (blockerId != null) {
        return Blocker(
          id: blockerId,
          distanceCells: dist,
          hitCell: cell,
        );
      }
      dist++;
    }
    return null;
  }

  /// Removes the thread with [id] from the board and frees its occupied cells.
  void remove(int id) {
    if (!active.remove(id)) return;
    final t = threads[id];
    if (t == null) return;
    for (final cell in t.cells) {
      occupancy.remove(cell);
    }
  }

  /// Returns all currently active thread IDs that can exit without obstruction.
  List<int> freeThreads() {
    final result = <int>[];
    for (final id in active) {
      final partnerId = colorPartners[id];
      if (partnerId != null && active.contains(partnerId)) {
        if (canExit(id) && canExit(partnerId)) {
          result.add(id);
        }
        continue;
      }
      if (canExit(id)) {
        result.add(id);
      }
    }
    return result;
  }

  /// Computes for a given free thread how many other active threads' exit rays
  /// it is currently blocking.
  int blockedRaysFreedBy(int id) {
    if (!active.contains(id)) return 0;
    final t = threads[id]!;
    final threadCells = t.cells.toSet();

    var count = 0;
    for (final otherId in active) {
      if (otherId == id) continue;
      final other = threads[otherId]!;
      for (final rayCell in ray(other, rows, cols, deflectorMap)) {
        if (threadCells.contains(rayCell)) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  /// Selects the optimal hint thread (frees most other threads, tie-broken by lowest id).
  int? chooseHintThread() {
    final frees = freeThreads();
    if (frees.isEmpty) return null;

    var bestId = frees.first;
    var bestCount = -1;

    for (final id in frees) {
      final count = blockedRaysFreedBy(id);
      if (count > bestCount || (count == bestCount && id < bestId)) {
        bestCount = count;
        bestId = id;
      }
    }
    return bestId;
  }
}
