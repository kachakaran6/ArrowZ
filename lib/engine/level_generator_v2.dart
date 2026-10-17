import 'dart:collection';
import 'dart:math';

import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/deflector.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/mask_generator.dart';
import 'package:arrowtapout/engine/solver.dart';
import 'package:arrowtapout/engine/thread.dart';

/// Level category archetype.
enum LevelType {
  tutorial,
  normal,
  boss,
  god;

  static LevelType forLevel(int levelNumber) {
    if (levelNumber <= 3) return LevelType.tutorial;
    final mod7 = (levelNumber - 1) % 7;
    if (mod7 == 6) return LevelType.god; // 7th in 7-cycle
    if (mod7 == 2 || mod7 == 5) return LevelType.boss; // 3rd, 6th
    return LevelType.normal;
  }
}

/// Advanced level generator adhering to 4-tier length distribution,
/// progressive tangle factor, anti-square constraints, deflector placement,
/// color pairing, and guaranteed solvability.
class LevelGeneratorV2 {
  LevelGeneratorV2._();

  static final ListQueue<String> _bossShapeHistory = ListQueue<String>();
  static final ListQueue<String> _godShapeHistory = ListQueue<String>();
  static const int _shapeHistoryMaxLen = 5;

  /// Determines the canvas grid dimension for a given level index.
  static int gridSizeForLevel(int levelNumber) {
    if (levelNumber <= 3) return 10;
    if (levelNumber <= 10) return 10;
    if (levelNumber <= 20) return 12;
    if (levelNumber <= 40) return 14;
    if (levelNumber <= 70) return 16;
    if (levelNumber <= 100) return 18;
    if (levelNumber <= 150) return 20;
    if (levelNumber <= 200) return 22;
    if (levelNumber <= 300) return 25;
    if (levelNumber <= 400) return 28;
    return 30;
  }

  /// Generates a fully solvable, high-quality [Level] seeded by [levelNumber].
  static Level generateLevel(int levelNumber) {
    if (levelNumber == 1) return _buildTutorial1();
    if (levelNumber == 2) return _buildTutorial2();
    if (levelNumber == 3) return _buildTutorial3();

    final type = LevelType.forLevel(levelNumber);
    final gridSize = gridSizeForLevel(levelNumber);

    final seed = levelNumber * 103 + 51;
    final rng = Random(seed);

    final shape = _shapeFor(type, rng);
    final mask = MaskGenerator.shapeByName(shape, gridSize, rng);

    Level? level;
    final isLargeGrid = gridSize > 20;
    final maxAttempts = isLargeGrid ? (type == LevelType.normal ? 60 : 90) : 60;

    for (var attempt = 0; attempt < maxAttempts && level == null; attempt++) {
      level = _attempt(
        levelNumber: levelNumber,
        gridSize: gridSize,
        mask: mask,
        type: type,
        rng: rng,
        shapeName: shape,
        attempt: attempt,
      );
    }

    if (level != null && !isLargeGrid) {
      final solveRes = solve(level);
      if (!solveRes.isSolved) {
        level = null;
      }
    }

    return level ?? _fallback(levelNumber, gridSize, mask, type);
  }

  // ── Tutorials ─────────────────────────────────────────────────────────────

  static Level _buildTutorial1() {
    final threads = [
      Thread(1, [const Cell(4, 4), const Cell(4, 5)]), // points right
      Thread(2, [const Cell(6, 5), const Cell(5, 5)]), // points up
      Thread(3, [const Cell(8, 5), const Cell(7, 5)]), // points up
    ];
    return Level(
      id: 1,
      rows: 10,
      cols: 10,
      threads: threads,
      shape: 'square',
      chapter: 1,
      par: 3,
    );
  }

  static Level _buildTutorial2() {
    final threads = [
      Thread(
        1,
        [const Cell(6, 4), const Cell(5, 4)],
        colorGroup: 0,
      ), // points up
      Thread(
        2,
        [const Cell(5, 5), const Cell(5, 6)],
        colorGroup: 0,
      ), // points right
      Thread(
        3,
        [const Cell(4, 5), const Cell(4, 4)],
      ), // points left
    ];
    return Level(
      id: 2,
      rows: 10,
      cols: 10,
      threads: threads,
      shape: 'square',
      chapter: 1,
      par: 3,
    );
  }

  static Level _buildTutorial3() {
    final threads = [
      Thread(1, [const Cell(7, 4), const Cell(6, 4)]), // points up
      Thread(2, [const Cell(3, 6), const Cell(4, 6)]), // points down
    ];
    final deflectors = [
      const Deflector(cell: Cell(5, 4), dir: Dir.right),
    ];
    return Level(
      id: 3,
      rows: 10,
      cols: 10,
      threads: threads,
      deflectors: deflectors,
      shape: 'square',
      chapter: 1,
      par: 2,
    );
  }

  // ── Single Generation Attempt ─────────────────────────────────────────────

  static Level? _attempt({
    required int levelNumber,
    required int gridSize,
    required Set<String> mask,
    required LevelType type,
    required Random rng,
    required String shapeName,
    required int attempt,
  }) {
    final placedRawPaths = <_RawArrow>[];
    final occupiedPacked = <int>{};
    int counter = 1;

    final maskCells = mask.map((k) {
      final p = k.split(',');
      return [int.parse(p[0]), int.parse(p[1])];
    }).toList();

    final maskPacked = <int>{};
    for (final cell in maskCells) {
      maskPacked.add(cell[0] * 1000 + cell[1]);
    }

    final bool fillEntireGrid = type != LevelType.tutorial &&
        levelNumber <= 150 &&
        (shapeName == 'square' || shapeName == 'longRectangle') &&
        attempt < 10;
    final int targetOccupied = fillEntireGrid
        ? mask.length
        : (mask.length * (0.80 - (attempt * 0.02)).clamp(0.60, 0.90)).round();

    // ── Phase 1: 4-Tier Arrow Placement ─────────────────────────────────────
    {
      int failures = 0;
      int veryLongCount = 0;
      int longCount = 0;
      int medCount = 0;
      int shortCount = 0;
      final maxFailures = type == LevelType.tutorial ? 40 : 60;
      final tangleFactor = _tangleFactorFor(levelNumber, type);

      var veryLongMin = 5 + (gridSize ~/ 6);
      var longMin = 3 + (gridSize ~/ 10);
      var veryLongMax = max(
        veryLongMin + 1,
        (veryLongMin + 4).clamp(veryLongMin + 1, mask.length),
      );

      if (shapeName != 'square' && shapeName != 'longRectangle') {
        veryLongMin = max(5, (veryLongMin * 0.8).round());
        longMin = max(3, (longMin * 0.8).round());
        veryLongMax = max(veryLongMin + 1, (veryLongMax * 0.8).round());
      }

      const maxAllowedBlocks = 0;

      while (failures < maxFailures && occupiedPacked.length < targetOccupied) {
        final candidates = _exitCandidates(
          maskCells,
          occupiedPacked,
          gridSize,
          maxAllowedBlocks,
          rng,
        );
        if (candidates.isEmpty) break;

        // Check if >= 3 cell arrow can fit
        var canFit3 = false;
        for (final cell in maskCells) {
          final r = cell[0], c = cell[1];
          if (occupiedPacked.contains(r * 1000 + c)) continue;
          var freeNb = 0;
          for (final nb in [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1]
          ]) {
            final np = (r + nb[0]) * 1000 + (c + nb[1]);
            if (maskPacked.contains(np) && !occupiedPacked.contains(np)) {
              freeNb++;
            }
          }
          if (freeNb >= 2) {
            canFit3 = true;
            break;
          }
        }
        if (!canFit3) break;

        _shuffleCandidates(candidates, gridSize, rng);

        final tier = _selectTier(
          veryLongCount: veryLongCount,
          longCount: longCount,
          medCount: medCount,
          shortCount: shortCount,
        );

        _Cand? bestCand;
        List<List<int>>? bestPath;

        for (final cand in candidates.take(15)) {
          final len = _lengthForTier(
            tier,
            veryLongMin,
            veryLongMax,
            longMin,
            rng,
          );

          final path = _growPath(
            startRow: cand.row,
            startCol: cand.col,
            exitDir: cand.dir,
            maskPacked: maskPacked,
            occupiedPacked: occupiedPacked,
            targetLen: len,
            rng: rng,
            gridSize: gridSize,
            tangleFactor: tier == _LenTier.veryLong ? tangleFactor : 0.0,
          );

          final minLen = _minLenForTier(tier, veryLongMin, longMin);
          if (path != null && path.length >= minLen) {
            bestCand = cand;
            bestPath = path;
            break;
          }
        }

        // Fallback cascade: try shorter tiers if requested tier did not fit
        if (bestPath == null && type != LevelType.tutorial) {
          if (tier == _LenTier.veryLong) {
            for (final cand in candidates.take(15)) {
              final len = _lengthForTier(
                  _LenTier.long, veryLongMin, veryLongMax, longMin, rng);
              final path = _growPath(
                startRow: cand.row,
                startCol: cand.col,
                exitDir: cand.dir,
                maskPacked: maskPacked,
                occupiedPacked: occupiedPacked,
                targetLen: len,
                rng: rng,
                gridSize: gridSize,
              );
              if (path != null && path.length >= longMin) {
                bestCand = cand;
                bestPath = path;
                break;
              }
            }
          }
          if (bestPath == null &&
              (tier == _LenTier.veryLong || tier == _LenTier.long)) {
            for (final cand in candidates.take(15)) {
              final len = 3 + rng.nextInt(3);
              final path = _growPath(
                startRow: cand.row,
                startCol: cand.col,
                exitDir: cand.dir,
                maskPacked: maskPacked,
                occupiedPacked: occupiedPacked,
                targetLen: len,
                rng: rng,
                gridSize: gridSize,
              );
              if (path != null && path.length >= 3) {
                bestCand = cand;
                bestPath = path;
                break;
              }
            }
          }
          if (bestPath == null) {
            for (final cand in candidates.take(15)) {
              final path = _growPath(
                startRow: cand.row,
                startCol: cand.col,
                exitDir: cand.dir,
                maskPacked: maskPacked,
                occupiedPacked: occupiedPacked,
                targetLen: 2,
                rng: rng,
                gridSize: gridSize,
              );
              if (path != null && path.length == 2) {
                bestCand = cand;
                bestPath = path;
                break;
              }
            }
          }
        }

        if (bestCand != null && bestPath != null) {
          placedRawPaths.add(
            _RawArrow(
              id: counter++,
              path: bestPath,
              dir: bestCand.dir,
            ),
          );
          for (final pt in bestPath) {
            occupiedPacked.add(pt[0] * 1000 + pt[1]);
          }

          if (bestPath.length >= veryLongMin) {
            veryLongCount++;
          } else if (bestPath.length >= longMin) {
            longCount++;
          } else if (bestPath.length >= 3) {
            medCount++;
          } else {
            shortCount++;
          }
          failures = 0;
        } else {
          failures++;
        }
      }
    }

    // ── Phase 2: 2-Cell Gap Filling ─────────────────────────────────────────
    if (type != LevelType.tutorial) {
      const maxAllowedBlocks = 0;
      var failures = 0;

      while (failures < 40 && occupiedPacked.length < targetOccupied) {
        final candidates = _exitCandidates(
          maskCells,
          occupiedPacked,
          gridSize,
          maxAllowedBlocks,
          rng,
        );
        if (candidates.isEmpty) break;
        _shuffleCandidates(candidates, gridSize, rng);

        _Cand? bestCand;
        List<List<int>>? bestPath;

        for (final cand in candidates.take(15)) {
          final path = _growPath(
            startRow: cand.row,
            startCol: cand.col,
            exitDir: cand.dir,
            maskPacked: maskPacked,
            occupiedPacked: occupiedPacked,
            targetLen: 2,
            rng: rng,
            gridSize: gridSize,
          );
          if (path != null && path.length == 2) {
            bestCand = cand;
            bestPath = path;
            break;
          }
        }

        if (bestCand != null && bestPath != null) {
          placedRawPaths.add(
            _RawArrow(
              id: counter++,
              path: bestPath,
              dir: bestCand.dir,
            ),
          );
          for (final pt in bestPath) {
            occupiedPacked.add(pt[0] * 1000 + pt[1]);
          }
          failures = 0;
        } else {
          failures++;
        }
      }

      // Greedy adjacent-pair sweep with clean exit
      var progress = true;
      while (progress && occupiedPacked.length < targetOccupied) {
        progress = false;
        final emptyCells = maskCells
            .where((c) => !occupiedPacked.contains(c[0] * 1000 + c[1]))
            .toList()
          ..shuffle(rng);

        for (final cell in emptyCells) {
          final r = cell[0], c = cell[1];
          if (occupiedPacked.contains(r * 1000 + c)) continue;

          final nbOffsets = [
            [-1, 0],
            [1, 0],
            [0, -1],
            [0, 1]
          ]..shuffle(rng);
          for (final nb in nbOffsets) {
            final tr = r + nb[0], tc = c + nb[1];
            if (!maskPacked.contains(tr * 1000 + tc)) continue;
            if (occupiedPacked.contains(tr * 1000 + tc)) continue;

            final Dir dir1, dir2;
            if (nb[0] == 1) {
              dir1 = Dir.up;
              dir2 = Dir.down;
            } else if (nb[0] == -1) {
              dir1 = Dir.down;
              dir2 = Dir.up;
            } else if (nb[1] == 1) {
              dir1 = Dir.left;
              dir2 = Dir.right;
            } else {
              dir1 = Dir.right;
              dir2 = Dir.left;
            }

            int hr, hc, trr, tcc;
            Dir chosenDir;

            if (_canExitClean(r, c, dir1, occupiedPacked, gridSize)) {
              hr = r;
              hc = c;
              trr = tr;
              tcc = tc;
              chosenDir = dir1;
            } else if (_canExitClean(tr, tc, dir2, occupiedPacked, gridSize)) {
              hr = tr;
              hc = tc;
              trr = r;
              tcc = c;
              chosenDir = dir2;
            } else {
              continue;
            }

            placedRawPaths.add(
              _RawArrow(
                id: counter++,
                path: [
                  [hr, hc],
                  [trr, tcc]
                ],
                dir: chosenDir,
              ),
            );
            occupiedPacked.add(r * 1000 + c);
            occupiedPacked.add(tr * 1000 + tc);
            progress = true;
            break;
          }
        }
      }
    }

    if (placedRawPaths.isEmpty) return null;
    if (placedRawPaths.length < 5 ||
        occupiedPacked.length < (mask.length * 0.15).floor().clamp(10, 100)) {
      return null;
    }

    // Convert raw paths to ArrowZ Threads (cells ordered tail-to-head!)
    final threads = <Thread>[];
    for (final raw in placedRawPaths) {
      final cells = raw.path.reversed
          .map((p) => Cell(p[0], p[1]))
          .toList(growable: false);
      threads.add(Thread(raw.id, cells));
    }

    // ── Phase 4: Deflectors (Level >= 16) ───────────────────────────────────
    final deflectors = <Deflector>[];
    if (levelNumber >= 16) {
      final emptyPacked =
          maskPacked.where((cp) => !occupiedPacked.contains(cp)).toSet();

      final deflectorMap = <Cell, Dir>{};
      final colorProb = _colorProbFor(levelNumber, type);
      final maxDeflectors = (gridSize ~/ 3).clamp(2, 8);

      for (var i = threads.length - 1;
          i >= 0 && deflectorMap.length < maxDeflectors;
          i--) {
        final t = threads[i];
        var curDir = t.dir;
        var r = t.head.r + curDir.dr;
        var c = t.head.c + curDir.dc;
        final visited = <int>{};

        while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
          final pk = r * 1000 + c;
          if (!visited.add(pk)) break;

          if (emptyPacked.contains(pk)) {
            final cell = Cell(r, c);
            if (!deflectorMap.containsKey(cell)) {
              if (rng.nextDouble() < colorProb) {
                // Manhattan spacing >= 2 check
                var tooClose = false;
                for (final existing in deflectorMap.keys) {
                  if ((existing.r - r).abs() + (existing.c - c).abs() < 2) {
                    tooClose = true;
                    break;
                  }
                }

                if (!tooClose) {
                  final turns = rng.nextBool()
                      ? [
                          _turnRight(curDir),
                          _turnLeft(curDir),
                        ]
                      : [
                          _turnLeft(curDir),
                          _turnRight(curDir),
                        ];

                  for (final candDir in turns) {
                    deflectorMap[cell] = candDir;
                    final tempLevel = Level(
                      id: levelNumber,
                      rows: gridSize,
                      cols: gridSize,
                      threads: threads,
                      deflectors: deflectorMap.entries
                          .map((e) => Deflector(cell: e.key, dir: e.value))
                          .toList(),
                    );
                    if (!_hasDeflectionLoop(threads, deflectorMap, gridSize) &&
                        _isLevelSolvable(tempLevel, gridSize)) {
                      curDir = candDir;
                      break;
                    } else {
                      deflectorMap.remove(cell);
                    }
                  }
                }
              }
            } else {
              curDir = deflectorMap[cell]!;
            }
          }

          r += curDir.dr;
          c += curDir.dc;
        }
      }

      deflectorMap.forEach((cell, dir) {
        deflectors.add(Deflector(cell: cell, dir: dir));
      });
    }

    // ── Phase 5: ColorLock Pairs (Level >= 16) ──────────────────────────────
    if (levelNumber >= 16 && threads.length >= 4) {
      _applyColorPairs(threads, levelNumber, type, rng, gridSize, deflectors);
    }

    final candidateLevel = Level(
      id: levelNumber,
      rows: gridSize,
      cols: gridSize,
      threads: threads,
      deflectors: deflectors,
      shape: shapeName,
      chapter: ((levelNumber - 1) ~/ 20) + 1,
      par: threads.length,
    );

    final defMap = {for (final d in deflectors) d.cell: d.dir};
    if (!_hasDeflectionLoop(threads, defMap, gridSize) &&
        _isLevelSolvable(candidateLevel, gridSize)) {
      return candidateLevel;
    }
    return null;
  }

  // ── Color Pairing ─────────────────────────────────────────────────────────

  static void _applyColorPairs(
    List<Thread> threads,
    int levelNumber,
    LevelType type,
    Random rng,
    int gridSize,
    List<Deflector> deflectors,
  ) {
    int targetPairs;
    if (type == LevelType.god) {
      targetPairs = (threads.length * 0.20).floor().clamp(2, 6);
    } else if (type == LevelType.boss) {
      targetPairs = (threads.length * 0.15).floor().clamp(1, 4);
    } else {
      targetPairs = (threads.length * 0.10).floor().clamp(1, 3);
    }

    final defMap = {for (final d in deflectors) d.cell: d.dir};
    final available = List<int>.generate(threads.length, (i) => i)
      ..shuffle(rng);
    var pairsCount = 0;

    for (var i = 0; i < available.length && pairsCount < targetPairs; i++) {
      final idx1 = available[i];
      if (threads[idx1].colorGroup != null) continue;

      for (var j = i + 1; j < available.length; j++) {
        final idx2 = available[j];
        if (threads[idx2].colorGroup != null) continue;

        final t1 = threads[idx1];
        final t2 = threads[idx2];

        // Spatial separation
        final dist =
            (t1.head.r - t2.head.r).abs() + (t1.head.c - t2.head.c).abs();
        if (dist < min(gridSize * 0.25, 12)) continue;

        // Verify mutual exit clearance
        final t1Cells = t1.cells.toSet();
        final t2Cells = t2.cells.toSet();

        var t1HitsT2 = false;
        for (final c in BoardState.ray(t1, gridSize, gridSize, defMap)) {
          if (t2Cells.contains(c)) {
            t1HitsT2 = true;
            break;
          }
        }
        var t2HitsT1 = false;
        for (final c in BoardState.ray(t2, gridSize, gridSize, defMap)) {
          if (t1Cells.contains(c)) {
            t2HitsT1 = true;
            break;
          }
        }
        if (t1HitsT2 || t2HitsT1) continue;

        // Apply pair tentatively
        threads[idx1] = Thread(t1.id, t1.cells, colorGroup: pairsCount);
        threads[idx2] = Thread(t2.id, t2.cells, colorGroup: pairsCount);

        final testLevel = Level(
          id: levelNumber,
          rows: gridSize,
          cols: gridSize,
          threads: threads,
          deflectors: deflectors,
        );

        if (_isLevelSolvable(testLevel, gridSize)) {
          pairsCount++;
          break;
        } else {
          // Revert
          threads[idx1] = t1;
          threads[idx2] = t2;
        }
      }
    }
  }

  static bool _hasDeflectionLoop(
    List<Thread> threads,
    Map<Cell, Dir> deflectors,
    int gridSize,
  ) {
    if (deflectors.isEmpty) return false;
    for (final t in threads) {
      final visited = <int>{};
      var curDir = t.dir;
      var r = t.head.r + curDir.dr;
      var c = t.head.c + curDir.dc;
      while (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
        final key = (r << 16) | c;
        if (!visited.add(key)) {
          return true;
        }
        final cell = Cell(r, c);
        if (deflectors.containsKey(cell)) {
          curDir = deflectors[cell]!;
        }
        r += curDir.dr;
        c += curDir.dc;
      }
    }
    return false;
  }

  // ── Solvability Checker ───────────────────────────────────────────────────

  static bool _isLevelSolvable(Level level, int gridSize) {
    if (gridSize <= 20) {
      return solve(level).isSolved;
    }
    // Fast greedy simulation for large grids
    final board = BoardState(level);
    while (board.active.isNotEmpty) {
      final free = board.freeThreads();
      if (free.isEmpty) return false;
      for (final id in free) {
        board.remove(id);
      }
    }
    return true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _tangleFactorFor(int level, LevelType type) {
    if (type == LevelType.tutorial) return 0.0;
    double base;
    if (level <= 6) {
      base = 0.35;
    } else if (level <= 15) {
      base = 0.55;
    } else if (level <= 40) {
      base = 0.75;
    } else {
      base = 1.0;
    }
    if (type == LevelType.boss) base = (base + 0.15).clamp(0.4, 1.0);
    if (type == LevelType.god) base = (base + 0.25).clamp(0.6, 1.0);
    return base;
  }

  static double _colorProbFor(int level, LevelType type) {
    if (level <= 15) return 0.0;
    if (type == LevelType.god) return 0.70;
    if (type == LevelType.boss) return 0.50;
    if (level <= 40) return 0.25;
    return 0.45;
  }

  static _LenTier _selectTier({
    required int veryLongCount,
    required int longCount,
    required int medCount,
    required int shortCount,
  }) {
    final total = veryLongCount + longCount + medCount + shortCount;
    if (total == 0) return _LenTier.veryLong;
    final vl = veryLongCount / total;
    final l = longCount / total;
    final m = medCount / total;

    if (vl < 0.35) return _LenTier.veryLong;
    if (l < 0.30) return _LenTier.long;
    if (m < 0.25) return _LenTier.medium;
    return _LenTier.short;
  }

  static int _lengthForTier(
    _LenTier tier,
    int veryLongMin,
    int veryLongMax,
    int longMin,
    Random rng,
  ) {
    switch (tier) {
      case _LenTier.veryLong:
        final range = max(1, veryLongMax - veryLongMin + 1);
        return veryLongMin + rng.nextInt(range);
      case _LenTier.long:
        final longMax = max(longMin, veryLongMin - 1);
        final range = max(1, longMax - longMin + 1);
        return longMin + rng.nextInt(range);
      case _LenTier.medium:
        return 3 + rng.nextInt(3);
      case _LenTier.short:
        return 2;
    }
  }

  static int _minLenForTier(_LenTier tier, int veryLongMin, int longMin) {
    switch (tier) {
      case _LenTier.veryLong:
        return veryLongMin;
      case _LenTier.long:
        return longMin;
      case _LenTier.medium:
        return 3;
      case _LenTier.short:
        return 2;
    }
  }

  static List<_Cand> _exitCandidates(
    List<List<int>> maskCells,
    Set<int> occupiedPacked,
    int gridSize,
    int maxAllowedBlocks, [
    Random? rng,
  ]) {
    final emptyCells = <List<int>>[];
    for (final cell in maskCells) {
      if (!occupiedPacked.contains(cell[0] * 1000 + cell[1])) {
        emptyCells.add(cell);
      }
    }
    if (emptyCells.isEmpty) return const [];

    final Iterable<List<int>> sample;
    if (rng != null && emptyCells.length > 120) {
      emptyCells.shuffle(rng);
      sample = emptyCells.take(120);
    } else {
      sample = emptyCells;
    }

    final out = <_Cand>[];
    for (final cell in sample) {
      final r = cell[0], c = cell[1];
      for (final dir in Dir.values) {
        var nr = r + dir.dr;
        var nc = c + dir.dc;
        var blocks = 0;
        while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
          if (occupiedPacked.contains(nr * 1000 + nc)) blocks++;
          nr += dir.dr;
          nc += dir.dc;
        }
        if (blocks <= maxAllowedBlocks) {
          out.add(_Cand(r, c, dir, blockedCount: blocks));
        }
      }
    }

    if (out.isEmpty && emptyCells.length > 120) {
      for (final cell in emptyCells) {
        final r = cell[0], c = cell[1];
        for (final dir in Dir.values) {
          var nr = r + dir.dr;
          var nc = c + dir.dc;
          var blocks = 0;
          while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
            if (occupiedPacked.contains(nr * 1000 + nc)) blocks++;
            nr += dir.dr;
            nc += dir.dc;
          }
          if (blocks <= maxAllowedBlocks) {
            out.add(_Cand(r, c, dir, blockedCount: blocks));
          }
        }
      }
    }
    return out;
  }

  static void _shuffleCandidates(
    List<_Cand> candidates,
    int gridSize,
    Random rng,
  ) {
    final center = gridSize / 2.0;
    candidates.sort((a, b) {
      final distA = (a.row - center).abs() + (a.col - center).abs();
      final distB = (b.row - center).abs() + (b.col - center).abs();
      final scoreA = distA + a.blockedCount * 3.0 + (rng.nextDouble() * 2 - 1);
      final scoreB = distB + b.blockedCount * 3.0 + (rng.nextDouble() * 2 - 1);
      return scoreA.compareTo(scoreB);
    });
  }

  static List<List<int>>? _growPath({
    required int startRow,
    required int startCol,
    required Dir exitDir,
    required Set<int> maskPacked,
    required Set<int> occupiedPacked,
    required int targetLen,
    required Random rng,
    required int gridSize,
    double tangleFactor = 0.0,
  }) {
    final exitPath = _getExitPathPacked(startRow, startCol, exitDir, gridSize);
    final path = <List<int>>[
      [startRow, startCol]
    ];
    final pathPacked = <int>{startRow * 1000 + startCol};
    var cr = startRow, cc = startCol;
    var growDir = exitDir.opposite;
    var straight = 0;

    final turnBias = 0.65 + tangleFactor * 0.20;
    final maxStraight = tangleFactor >= 0.7 ? 2 : 3;

    for (var step = 1; step < targetLen; step++) {
      final valid = <Dir>[];
      for (final d in Dir.values) {
        if (d == growDir.opposite) continue;
        final nr = cr + d.dr;
        final nc = cc + d.dc;
        final np = nr * 1000 + nc;
        if (!maskPacked.contains(np)) continue;
        if (occupiedPacked.contains(np)) continue;
        if (exitPath.contains(np)) continue;
        if (pathPacked.contains(np)) continue;

        // Anti-square / closed-loop rejection
        var wouldLoop = false;
        for (final nb in Dir.values) {
          final adjP = (nr + nb.dr) * 1000 + (nc + nb.dc);
          if (adjP != cr * 1000 + cc && pathPacked.contains(adjP)) {
            wouldLoop = true;
            break;
          }
        }
        if (wouldLoop) continue;
        valid.add(d);
      }

      if (valid.isEmpty) break;
      if (step == 1 && !valid.contains(growDir)) return null;

      final mustTurn = straight >= maxStraight;
      final turns = valid.where((d) => d != growDir).toList();
      final straights = valid.where((d) => d == growDir).toList();

      Dir chosen;
      if (step == 1) {
        chosen = growDir;
      } else if (mustTurn && turns.isNotEmpty) {
        chosen = turns[rng.nextInt(turns.length)];
      } else if (valid.length == 1) {
        chosen = valid[0];
      } else if (rng.nextDouble() < turnBias && turns.isNotEmpty) {
        chosen = turns[rng.nextInt(turns.length)];
      } else if (straights.isNotEmpty) {
        chosen = straights[0];
      } else {
        chosen = turns[rng.nextInt(turns.length)];
      }

      straight = chosen == growDir ? straight + 1 : 0;
      cr += chosen.dr;
      cc += chosen.dc;
      path.add([cr, cc]);
      pathPacked.add(cr * 1000 + cc);
      growDir = chosen;
    }

    return path.length >= 2 ? path : null;
  }

  static Set<int> _getExitPathPacked(
    int startRow,
    int startCol,
    Dir exitDir,
    int gridSize,
  ) {
    final path = <int>{};
    var nr = startRow + exitDir.dr;
    var nc = startCol + exitDir.dc;
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      path.add(nr * 1000 + nc);
      nr += exitDir.dr;
      nc += exitDir.dc;
    }
    return path;
  }

  static bool _canExitClean(
    int r,
    int c,
    Dir dir,
    Set<int> occupiedPacked,
    int gridSize,
  ) {
    var nr = r + dir.dr;
    var nc = c + dir.dc;
    while (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
      if (occupiedPacked.contains(nr * 1000 + nc)) return false;
      nr += dir.dr;
      nc += dir.dc;
    }
    return true;
  }

  static Dir _turnRight(Dir d) => switch (d) {
        Dir.up => Dir.right,
        Dir.right => Dir.down,
        Dir.down => Dir.left,
        Dir.left => Dir.up,
      };

  static Dir _turnLeft(Dir d) => switch (d) {
        Dir.up => Dir.left,
        Dir.left => Dir.down,
        Dir.down => Dir.right,
        Dir.right => Dir.up,
      };

  static String _shapeFor(LevelType type, Random rng) {
    switch (type) {
      case LevelType.tutorial:
      case LevelType.normal:
        return 'square';
      case LevelType.boss:
        return _pickShape(
          MaskGenerator.bossShapeNames,
          _bossShapeHistory,
          rng,
        );
      case LevelType.god:
        return _pickShape(
          MaskGenerator.godShapeNames,
          _godShapeHistory,
          rng,
        );
    }
  }

  static String _pickShape(
    List<String> shapes,
    ListQueue<String> history,
    Random rng,
  ) {
    final pool = shapes.where((s) => !history.contains(s)).toList();
    final chosen = pool.isNotEmpty
        ? pool[rng.nextInt(pool.length)]
        : shapes[rng.nextInt(shapes.length)];
    history.addLast(chosen);
    if (history.length > _shapeHistoryMaxLen) history.removeFirst();
    return chosen;
  }

  static Level _fallback(
    int levelNumber,
    int gridSize,
    Set<String> mask,
    LevelType type,
  ) {
    final threads = <Thread>[];
    final mid = gridSize ~/ 2;
    var count = 1;
    for (var c = 0; c < gridSize - 2 && count <= 4; c += 2) {
      threads.add(
        Thread(count++, [
          Cell(mid, c),
          Cell(mid, c + 1),
        ]), // points right
      );
    }
    return Level(
      id: levelNumber,
      rows: gridSize,
      cols: gridSize,
      threads: threads,
      shape: 'square',
      chapter: ((levelNumber - 1) ~/ 20) + 1,
    );
  }
}

enum _LenTier { veryLong, long, medium, short }

class _Cand {
  const _Cand(this.row, this.col, this.dir, {this.blockedCount = 0});
  final int row;
  final int col;
  final Dir dir;
  final int blockedCount;
}

class _RawArrow {
  _RawArrow({required this.id, required this.path, required this.dir});
  final int id;
  final List<List<int>> path;
  final Dir dir;
}
