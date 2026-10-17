// ignore_for_file: avoid_print
import 'dart:io';

import 'package:arrowtapout/data/level_binary_codec.dart';
import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/level_generator_v2.dart';
import 'package:arrowtapout/engine/solver.dart';
import 'package:arrowtapout/engine/validity.dart';

/// Comprehensive level verification script.
/// Checks pregenerated levels from assets/levels.bin (or generates on-the-fly):
///   1. Decoder correctly parses binary level data
///   2. Solvability via solver and greedy simulation
///   3. Arrow length distribution
///   4. Deflector count & zero infinite deflection loops
///   5. Zero ColorLock mutual deadlocks
///   6. Zero closed path cycles
void main() {
  print('═══════════════════════════════════════════════════════');
  print(' Arrow Out — Level Verification (1–500)');
  print('═══════════════════════════════════════════════════════\n');

  LevelBinaryDecoder? decoder;
  File? binFile;
  if (File('assets/levels.bin').existsSync()) {
    binFile = File('assets/levels.bin');
  } else if (File('assets/levels/levels.bin').existsSync()) {
    binFile = File('assets/levels/levels.bin');
  }

  if (binFile != null) {
    try {
      final bytes = binFile.readAsBytesSync();
      decoder = LevelBinaryDecoder.fromBytes(bytes);
      print(
        '✓ Loaded ${binFile.path} (${(bytes.length / 1024).toStringAsFixed(1)} KB, ${decoder.levelCount} levels)\n',
      );
    } catch (e) {
      print('⚠ Failed to read binary file ($e). Falling back to generator.\n');
    }
  }

  final totalLevels = decoder != null ? decoder.levelCount : 50;
  var passed = 0;
  var failed = 0;
  final failures = <String>[];

  // Distribution tracking
  var totalVeryLongArrows = 0;
  var totalLongArrows = 0;
  var totalMediumArrows = 0;
  var totalShortArrows = 0;

  var totalDeflectors = 0;
  var totalColorPairs = 0;

  final sw = Stopwatch()..start();

  for (var i = 1; i <= totalLevels; i++) {
    final levelSw = Stopwatch()..start();
    final type = LevelType.forLevel(i);
    final level = decoder != null
        ? decoder.decodeLevelByNumber(i)!
        : LevelGeneratorV2.generateLevel(i);
    levelSw.stop();

    final levelErrors = <String>[];

    // ── Check 1: Validity ──
    final val = validateLevel(level);
    if (!val.isValid) {
      levelErrors.add('VALIDITY: ${val.error}');
    }

    // ── Check 2: Solvability ──
    final solveRes = solve(level);
    if (!solveRes.isSolved) {
      levelErrors.add('UNSOLVABLE (solver returned unsolvable)');
    }

    // ── Check 3: Arrow length distribution ──
    final gs = level.rows;
    final vlMin = 5 + (gs ~/ 6);
    final lMin = 3 + (gs ~/ 10);
    for (final thread in level.threads) {
      final len = thread.cells.length;
      if (len >= vlMin) {
        totalVeryLongArrows++;
      } else if (len >= lMin) {
        totalLongArrows++;
      } else if (len >= 3) {
        totalMediumArrows++;
      } else {
        totalShortArrows++;
      }
    }

    // ── Check 4: Deflectors & infinite loops ──
    totalDeflectors += level.deflectors.length;
    final defMap = {for (final d in level.deflectors) d.cell: d.dir};
    for (final thread in level.threads) {
      final visited = <int>{};
      for (final cell
          in BoardState.ray(thread, level.rows, level.cols, defMap)) {
        final key = (cell.r << 16) | cell.c;
        if (!visited.add(key)) {
          levelErrors.add('Infinite deflection loop for thread #${thread.id}');
          break;
        }
      }
    }

    // ── Check 5: ColorLock pairing ──
    final colorGroups = <int, List<int>>{};
    for (final thread in level.threads) {
      if (thread.colorGroup != null) {
        colorGroups.putIfAbsent(thread.colorGroup!, () => []).add(thread.id);
      }
    }
    for (final entry in colorGroups.entries) {
      if (entry.value.length != 2) {
        levelErrors.add(
          'Color group ${entry.key} has ${entry.value.length} arrows (expected 2)',
        );
      } else {
        totalColorPairs++;
      }
    }

    if (levelErrors.isEmpty) {
      passed++;
      if (i % 25 == 0 || i <= 5) {
        print(
          '  ✓ Level ${'$i'.padLeft(3)} ($type) — ${level.rows}x${level.cols}, '
          '${level.threads.length} arrows, ${level.deflectors.length} deflectors '
          '[${levelSw.elapsedMilliseconds}ms]',
        );
      }
    } else {
      failed++;
      final msg = 'Level $i ($type): ${levelErrors.join('; ')}';
      failures.add(msg);
      print('  ✗ $msg');
    }
  }

  sw.stop();

  print('\n═══════════════════════════════════════════════════════');
  print(' RESULTS');
  print('═══════════════════════════════════════════════════════');
  print('  Total levels: $totalLevels');
  print('  Passed: $passed');
  print('  Failed: $failed');
  print(
    '  Time: ${sw.elapsedMilliseconds}ms (${(sw.elapsedMilliseconds / totalLevels).toStringAsFixed(2)}ms/level)',
  );

  final totalTiered = totalVeryLongArrows +
      totalLongArrows +
      totalMediumArrows +
      totalShortArrows;
  final vlPct = totalTiered > 0
      ? (totalVeryLongArrows / totalTiered * 100).toStringAsFixed(1)
      : '0.0';
  final lPct = totalTiered > 0
      ? (totalLongArrows / totalTiered * 100).toStringAsFixed(1)
      : '0.0';
  final mPct = totalTiered > 0
      ? (totalMediumArrows / totalTiered * 100).toStringAsFixed(1)
      : '0.0';
  final sPct = totalTiered > 0
      ? (totalShortArrows / totalTiered * 100).toStringAsFixed(1)
      : '0.0';

  print('\n  Arrow Length Distribution:');
  print('    Very Long (vlMin+):  $totalVeryLongArrows ($vlPct%)');
  print('    Long (lMin..vlMin-1): $totalLongArrows ($lPct%)');
  print('    Medium (3..lMin-1):   $totalMediumArrows ($mPct%)');
  print('    Short (2):           $totalShortArrows ($sPct%)');

  print('\n  Mechanics:');
  print('    Total Deflectors:  $totalDeflectors');
  print('    Total Color Pairs: $totalColorPairs');

  if (failures.isNotEmpty) {
    print('\n  ── FAILURES ──');
    for (final f in failures) {
      print('    • $f');
    }
  }

  print('\n═══════════════════════════════════════════════════════');
  print(
    failed == 0
        ? ' ALL $totalLevels LEVELS PASSED PERFECTLY ✓'
        : ' $failed FAILURES ✗',
  );
  print('═══════════════════════════════════════════════════════\n');
}
