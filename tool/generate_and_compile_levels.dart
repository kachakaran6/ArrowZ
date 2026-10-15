// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:arrowtapout/data/level_binary_codec.dart';
import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/level_generator_v2.dart';
import 'package:arrowtapout/engine/solver.dart';
import 'package:arrowtapout/engine/validity.dart';

void main(List<String> args) async {
  int startLevel = 1;
  int endLevel = 500;
  bool compileOnly = false;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--start' && i + 1 < args.length) {
      startLevel = int.parse(args[i + 1]);
    } else if (args[i] == '--end' && i + 1 < args.length) {
      endLevel = int.parse(args[i + 1]);
    } else if (args[i] == '--compile') {
      compileOnly = true;
    }
  }

  final logFile = File('log.txt');

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '[$timestamp] [Range $startLevel-$endLevel] $message';
    print(formatted);
    logFile.writeAsStringSync('$formatted\n', mode: FileMode.append);
  }

  if (compileOnly) {
    log('─────────────────────────────────────────────────────────────');
    log(' Compiling all cached levels (1–500) into assets/levels.bin');
    log('─────────────────────────────────────────────────────────────');
    final levels = <Level>[];
    for (var i = 1; i <= 500; i++) {
      final cacheFile = File('assets/levels_cache/level_$i.json');
      if (cacheFile.existsSync()) {
        final level =
            Level.fromJson(jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>);
        levels.add(level);
      } else {
        log('WARNING: Missing cache file for Level $i');
      }
    }
    log('Encoding ${levels.length} levels into assets/levels.bin...');
    final encodeSw = Stopwatch()..start();
    final bytes = encodeLevels(levels);
    encodeSw.stop();

    final outDir = Directory('assets');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    File('assets/levels.bin').writeAsBytesSync(bytes);
    final levelsSubDir = Directory('assets/levels');
    if (levelsSubDir.existsSync()) {
      File('assets/levels/levels.bin').writeAsBytesSync(bytes);
    }
    final kbSize = (bytes.length / 1024).toStringAsFixed(1);
    log('SUCCESS! Written assets/levels.bin ($kbSize KB, ${bytes.length} bytes in ${encodeSw.elapsedMilliseconds}ms)');

    // Also synchronize all 25 chapter JSON files for seamless fallback
    final chapterNames = [
      'First Threads',
      'Loose Ends',
      'Straight Talk',
      'Corners',
      'Spirals',
      'Crosscurrents',
      'Dense Weave',
      'Labyrinth',
      'Long Form',
      'Masterworks',
      'Convergences',
      'Vortex',
      'Tanglewood',
      'Circuitry',
      'Echo Chamber',
      'Iron Lattice',
      'Shadow Labyrinth',
      'Zenith',
      'Grand Tapestry',
      'Quantum Threads',
      'Nexus',
      'Infinity Grid',
      'Celestial Knot',
      'Apex Legends',
      'Grand Ascendance',
    ];

    final levelsDir = Directory('assets/levels');
    if (!levelsDir.existsSync()) {
      levelsDir.createSync(recursive: true);
    }

    for (var ch = 1; ch <= 25; ch++) {
      final startIdx = (ch - 1) * 20;
      final chLevels = levels.skip(startIdx).take(20).toList();
      if (chLevels.isEmpty) continue;

      final chNumStr = ch.toString().padLeft(2, '0');
      final chName = ch <= chapterNames.length ? chapterNames[ch - 1] : 'Chapter $ch';
      final chJson = {
        'v': 1,
        'chapter': ch,
        'name': chName,
        'levels': chLevels.map((l) => l.toJson()).toList(),
      };
      File('assets/levels/chapter_$chNumStr.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(chJson),
      );
    }
    log('SUCCESS! Exported 25 chapter JSON files (assets/levels/chapter_01.json .. chapter_25.json)');
    return;
  }

  log('─────────────────────────────────────────────────────────────');
  log(' Arrow Puzzle — Level Generator & Verifier (Range $startLevel to $endLevel)');
  log('─────────────────────────────────────────────────────────────');

  var loadedFromCache = 0;
  var newlyGenerated = 0;
  var skippedCount = 0;

  final cacheDir = Directory('assets/levels_cache');
  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }

  final sw = Stopwatch()..start();

  for (var i = startLevel; i <= endLevel; i++) {
    final cacheFile = File('assets/levels_cache/level_$i.json');
    Level? validLevel;

    // 1. Check disk cache first
    if (cacheFile.existsSync()) {
      try {
        final jsonStr = cacheFile.readAsStringSync();
        final level = Level.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
        final errors = _verifyLevel(level);
        if (errors.isEmpty) {
          validLevel = level;
          loadedFromCache++;
          log('Level ${'$i'.padLeft(3)} / $endLevel: LOADED FROM CACHE — ${level.threads.length} arrows (${level.rows}x${level.cols})');
        } else {
          log('Level ${'$i'.padLeft(3)} / $endLevel: Cached level invalid (${errors.join("; ")}), regenerating...');
          cacheFile.deleteSync();
        }
      } catch (e) {
        log('Level ${'$i'.padLeft(3)} / $endLevel: Failed to read cache, regenerating...');
      }
    }

    // 2. Generate and verify on-the-fly if not loaded from cache (max 3 attempts)
    if (validLevel == null) {
      for (var attempt = 1; attempt <= 3; attempt++) {
        final levelSw = Stopwatch()..start();
        final level = LevelGeneratorV2.generateLevel(i);
        levelSw.stop();

        final errors = _verifyLevel(level);
        if (errors.isEmpty) {
          validLevel = level;
          newlyGenerated++;
          // Save to individual level cache
          cacheFile.parent.createSync(recursive: true);
          cacheFile.writeAsStringSync(jsonEncode(level.toJson()));
          log('Level ${'$i'.padLeft(3)} / $endLevel: GENERATED & SOLVED (Attempt $attempt in ${levelSw.elapsedMilliseconds}ms) — ${level.threads.length} arrows (${level.rows}x${level.cols})');
          break;
        } else {
          log('Level ${'$i'.padLeft(3)} / $endLevel: Attempt $attempt FAILED verification (${errors.join("; ")})');
        }
      }
    }

    if (validLevel == null) {
      skippedCount++;
      log('Level ${'$i'.padLeft(3)} / $endLevel: SKIPPED (failed 3 generation attempts)');
    }
  }

  sw.stop();
  log('Range $startLevel-$endLevel finished in ${sw.elapsed.inSeconds}s (Cache: $loadedFromCache | New: $newlyGenerated | Skipped: $skippedCount)');
}

/// Comprehensive level verification rules for ArrowZ.
List<String> _verifyLevel(Level level) {
  final errors = <String>[];

  if (level.threads.length <= 4 && level.rows >= 12) {
    errors.add('Fallback level with <= 4 arrows');
  }

  final val = validateLevel(level);
  if (!val.isValid) {
    errors.add('Validity error: ${val.error}');
  }

  final sol = solve(level);
  if (!sol.isSolved) {
    errors.add('UNSOLVABLE (solver returned unsolvable)');
  }

  final defMap = {for (final d in level.deflectors) d.cell: d.dir};
  for (final thread in level.threads) {
    final visited = <int>{};
    for (final cell in BoardState.ray(thread, level.rows, level.cols, defMap)) {
      final key = (cell.r << 16) | cell.c;
      if (!visited.add(key)) {
        errors.add('Infinite deflection loop for thread #${thread.id}');
        break;
      }
    }
  }

  return errors;
}
