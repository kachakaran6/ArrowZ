import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';

/// Classification status for level solvability audit.
enum SolvabilityStatus {
  solved,
  immediateDeadlock,
  circularDeadlock,
  unsolvableWithoutDeflectors,
  searchLimitExceeded,
  invalidLevelData,
  engineDiscrepancy,
  error,
}

/// Detailed result of evaluating a single level's solvability.
class SolvabilityReport {
  const SolvabilityReport({
    required this.levelId,
    required this.chapter,
    required this.shape,
    required this.threadCount,
    required this.deflectorCount,
    required this.colorPairCount,
    required this.status,
    required this.initialFreeCount,
    required this.initialFreeThreads,
    required this.solutionPath,
    required this.requiresDeflectors,
    required this.exploredStates,
    required this.durationMs,
    required this.verifiedAgainstEngine,
    this.failureReason,
    this.deadlockCycle = const [],
    this.diagnostics = const {},
  });

  final int levelId;
  final int chapter;
  final String shape;
  final int threadCount;
  final int deflectorCount;
  final int colorPairCount;
  final SolvabilityStatus status;
  final int initialFreeCount;
  final List<int> initialFreeThreads;
  final List<int> solutionPath;
  final bool requiresDeflectors;
  final int exploredStates;
  final double durationMs;
  final bool verifiedAgainstEngine;
  final String? failureReason;
  final List<int> deadlockCycle;
  final Map<String, dynamic> diagnostics;

  bool get isPassed =>
      status == SolvabilityStatus.solved && verifiedAgainstEngine;

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'chapter': chapter,
        'shape': shape,
        'threadCount': threadCount,
        'deflectorCount': deflectorCount,
        'colorPairCount': colorPairCount,
        'status': status.name,
        'isPassed': isPassed,
        'initialFreeCount': initialFreeCount,
        'initialFreeThreads': initialFreeThreads,
        'solutionLength': solutionPath.length,
        'solutionPath': solutionPath,
        'requiresDeflectors': requiresDeflectors,
        'exploredStates': exploredStates,
        'durationMs': durationMs,
        'verifiedAgainstEngine': verifiedAgainstEngine,
        'failureReason': failureReason,
        'deadlockCycle': deadlockCycle,
        'diagnostics': diagnostics,
      };
}

/// Master Solvability Engine that analyzes ArrowZ levels.
class SolvabilityEngine {
  const SolvabilityEngine({
    this.maxStates = 50000,
    this.timeoutMs = 15000,
  });

  final int maxStates;
  final int timeoutMs;

  /// Validates pure geometric and structural integrity of a level definition.
  static String? validateStructure(Level level) {
    if (level.threads.isEmpty) {
      return 'Level contains no threads.';
    }

    final occupiedCells = <Cell, int>{};

    for (final t in level.threads) {
      if (t.cells.length < 2) {
        return 'Thread #${t.id} has length < 2.';
      }
      if (!t.isOrthogonallyConnected) {
        return 'Thread #${t.id} has non-orthogonal steps.';
      }
      if (!t.isSelfAvoiding) {
        return 'Thread #${t.id} intersects itself.';
      }
      for (final c in t.cells) {
        if (c.r < 0 || c.r >= level.rows || c.c < 0 || c.c >= level.cols) {
          return 'Thread #${t.id} cell $c is out of bounds [${level.rows}x${level.cols}].';
        }
        if (occupiedCells.containsKey(c)) {
          return 'Threads #${occupiedCells[c]} and #${t.id} share cell $c.';
        }
        occupiedCells[c] = t.id;
      }

      final defMap = {for (final d in level.deflectors) d.cell: d.dir};
      final ownCells = t.cells.toSet();
      for (final rayCell in BoardState.ray(t, level.rows, level.cols, defMap)) {
        if (ownCells.contains(rayCell)) {
          return 'Thread #${t.id} ray intersects its own body at $rayCell.';
        }
      }
    }
    return null;
  }

  /// Analyzes a [level] comprehensively.
  SolvabilityReport auditLevel(Level level) {
    final sw = Stopwatch()..start();

    // 1. Structural validity check (independent of solvability)
    final structureError = validateStructure(level);
    if (structureError != null) {
      sw.stop();
      return SolvabilityReport(
        levelId: level.id,
        chapter: level.chapter,
        shape: level.shape,
        threadCount: level.threads.length,
        deflectorCount: level.deflectors.length,
        colorPairCount: _countColorPairs(level),
        status: SolvabilityStatus.invalidLevelData,
        initialFreeCount: 0,
        initialFreeThreads: const [],
        solutionPath: const [],
        requiresDeflectors: false,
        exploredStates: 0,
        durationMs: sw.elapsedMicroseconds / 1000.0,
        verifiedAgainstEngine: false,
        failureReason: 'Structural validity failure: $structureError',
      );
    }

    final initialBoard = BoardState(level);
    final initialFree = initialBoard.freeThreads();

    // 2. Check immediate deadlock
    if (initialFree.isEmpty && level.threads.isNotEmpty) {
      sw.stop();
      final cycle = _detectDeadlockCycle(level, initialBoard);
      return SolvabilityReport(
        levelId: level.id,
        chapter: level.chapter,
        shape: level.shape,
        threadCount: level.threads.length,
        deflectorCount: level.deflectors.length,
        colorPairCount: _countColorPairs(level),
        status: SolvabilityStatus.immediateDeadlock,
        initialFreeCount: 0,
        initialFreeThreads: const [],
        solutionPath: const [],
        requiresDeflectors: level.deflectors.isNotEmpty,
        exploredStates: 1,
        durationMs: sw.elapsedMicroseconds / 1000.0,
        verifiedAgainstEngine: false,
        deadlockCycle: cycle,
        failureReason:
            'Immediate deadlock: zero legal moves available on initial board. Blocking cycle: $cycle',
      );
    }

    // 3. Search for solution using Authoritative BoardState rules
    final board = BoardState(level);
    final solution = <int>[];
    var statesExplored = 0;

    while (board.active.isNotEmpty) {
      statesExplored++;
      if (statesExplored > maxStates || sw.elapsedMilliseconds > timeoutMs) {
        sw.stop();
        return SolvabilityReport(
          levelId: level.id,
          chapter: level.chapter,
          shape: level.shape,
          threadCount: level.threads.length,
          deflectorCount: level.deflectors.length,
          colorPairCount: _countColorPairs(level),
          status: SolvabilityStatus.searchLimitExceeded,
          initialFreeCount: initialFree.length,
          initialFreeThreads: initialFree,
          solutionPath: solution,
          requiresDeflectors: level.deflectors.isNotEmpty,
          exploredStates: statesExplored,
          durationMs: sw.elapsedMicroseconds / 1000.0,
          verifiedAgainstEngine: false,
          failureReason:
              'Search limit exceeded ($statesExplored states explored)',
        );
      }

      final free = board.freeThreads();
      if (free.isEmpty) {
        sw.stop();
        final cycle = _detectDeadlockCycle(level, board);
        return SolvabilityReport(
          levelId: level.id,
          chapter: level.chapter,
          shape: level.shape,
          threadCount: level.threads.length,
          deflectorCount: level.deflectors.length,
          colorPairCount: _countColorPairs(level),
          status: SolvabilityStatus.circularDeadlock,
          initialFreeCount: initialFree.length,
          initialFreeThreads: initialFree,
          solutionPath: solution,
          requiresDeflectors: level.deflectors.isNotEmpty,
          exploredStates: statesExplored,
          durationMs: sw.elapsedMicroseconds / 1000.0,
          verifiedAgainstEngine: false,
          deadlockCycle: cycle,
          failureReason:
              'Circular deadlock reached after ${solution.length} moves. Remaining active: ${board.active.length}, cycle: $cycle',
        );
      }

      // Greedy removal: remove the first free thread
      // (due to monotonicity, any free thread removal preserves unblocked status of others)
      final chosen = free.first;
      solution.add(chosen);
      board.remove(chosen);
    }

    // 4. Differential test: does level require deflectors to be solved?
    var requiresDeflectors = false;
    if (level.deflectors.isNotEmpty) {
      final noDefLevel = Level(
        id: level.id,
        rows: level.rows,
        cols: level.cols,
        threads: level.threads,
        deflectors: const [],
        shape: level.shape,
        chapter: level.chapter,
        par: level.par,
      );
      final noDefBoard = BoardState(noDefLevel);
      var noDefSolvable = true;
      while (noDefBoard.active.isNotEmpty) {
        final f = noDefBoard.freeThreads();
        if (f.isEmpty) {
          noDefSolvable = false;
          break;
        }
        noDefBoard.remove(f.first);
      }
      requiresDeflectors = !noDefSolvable;
    }

    // 5. Differential engine verification:
    // Replay the solution step-by-step through a brand new BoardState
    // and verify every move is legal and board reaches empty state.
    final verifyBoard = BoardState(level);
    var verified = true;
    String? engineError;

    for (var step = 0; step < solution.length; step++) {
      final threadId = solution[step];
      if (!verifyBoard.active.contains(threadId)) {
        verified = false;
        engineError = 'Step $step: Thread $threadId is not active';
        break;
      }
      if (!verifyBoard.canExit(threadId)) {
        verified = false;
        final blocker = verifyBoard.firstBlocker(threadId);
        engineError =
            'Step $step: Thread $threadId cannot legally exit. Blocker: $blocker';
        break;
      }
      verifyBoard.remove(threadId);
    }

    if (verified && verifyBoard.active.isNotEmpty) {
      verified = false;
      engineError =
          'Final board state not empty: ${verifyBoard.active.length} remain';
    }

    sw.stop();
    final elapsedMs = sw.elapsedMicroseconds / 1000.0;

    if (!verified) {
      return SolvabilityReport(
        levelId: level.id,
        chapter: level.chapter,
        shape: level.shape,
        threadCount: level.threads.length,
        deflectorCount: level.deflectors.length,
        colorPairCount: _countColorPairs(level),
        status: SolvabilityStatus.engineDiscrepancy,
        initialFreeCount: initialFree.length,
        initialFreeThreads: initialFree,
        solutionPath: solution,
        requiresDeflectors: requiresDeflectors,
        exploredStates: statesExplored,
        durationMs: elapsedMs,
        verifiedAgainstEngine: false,
        failureReason: 'Engine verification discrepancy: $engineError',
      );
    }

    return SolvabilityReport(
      levelId: level.id,
      chapter: level.chapter,
      shape: level.shape,
      threadCount: level.threads.length,
      deflectorCount: level.deflectors.length,
      colorPairCount: _countColorPairs(level),
      status: SolvabilityStatus.solved,
      initialFreeCount: initialFree.length,
      initialFreeThreads: initialFree,
      solutionPath: solution,
      requiresDeflectors: requiresDeflectors,
      exploredStates: statesExplored,
      durationMs: elapsedMs,
      verifiedAgainstEngine: true,
      diagnostics: {
        'totalMoves': solution.length,
        'par': level.par,
      },
    );
  }

  static int _countColorPairs(Level level) {
    final groups = <int>{};
    for (final t in level.threads) {
      if (t.colorGroup != null) groups.add(t.colorGroup!);
    }
    return groups.length;
  }

  /// Finds a cycle of blocking dependencies among active threads using DFS.
  static List<int> _detectDeadlockCycle(Level level, BoardState board) {
    final active = board.active.toList();
    final adj = <int, List<int>>{};

    for (final id in active) {
      final blocker = board.firstBlocker(id);
      if (blocker != null && board.active.contains(blocker.id)) {
        adj.putIfAbsent(id, () => []).add(blocker.id);
      }
    }

    // Standard cycle finding in directed graph
    final visited = <int, int>{}; // 0 = unvisited, 1 = visiting, 2 = visited
    final parent = <int, int>{};
    final cycle = <int>[];

    bool dfs(int u) {
      visited[u] = 1;
      for (final v in adj[u] ?? const <int>[]) {
        if (visited[v] == 1) {
          // Cycle detected: backtrack from u to v
          cycle.add(v);
          var curr = u;
          while (curr != v && parent.containsKey(curr)) {
            cycle.add(curr);
            curr = parent[curr]!;
          }
          cycle.add(v);
          return true;
        }
        if (visited[v] == null || visited[v] == 0) {
          parent[v] = u;
          if (dfs(v)) return true;
        }
      }
      visited[u] = 2;
      return false;
    }

    for (final id in active) {
      if (visited[id] == null || visited[id] == 0) {
        if (dfs(id)) {
          return cycle.reversed.toList();
        }
      }
    }

    return active.take(5).toList();
  }
}
