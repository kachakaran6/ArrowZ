import 'dart:convert';
import 'dart:io';

import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/solver.dart';
import 'package:arrowtapout/engine/validity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Asset Levels 1 to 200 Verification', () {
    final allLevels = <Level>[];

    setUpAll(() {
      for (var ch = 1; ch <= 10; ch++) {
        final numStr = ch.toString().padLeft(2, '0');
        final file = File('assets/levels/chapter_$numStr.json');
        expect(file.existsSync(), isTrue,
            reason: 'Chapter $numStr JSON must exist');

        final jsonMap =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(jsonMap['chapter'], equals(ch));
        final levelsRaw = jsonMap['levels'] as List<dynamic>;
        expect(levelsRaw.length, equals(20),
            reason: 'Chapter $ch must have 20 levels');

        for (final raw in levelsRaw) {
          final level =
              Level.fromJson(raw as Map<String, dynamic>, chapter: ch);
          allLevels.add(level);
        }
      }
    });

    test('exactly 200 levels loaded with contiguous IDs from 1 to 200', () {
      expect(allLevels.length, equals(200));
      for (var i = 0; i < 200; i++) {
        expect(allLevels[i].id, equals(i + 1));
      }
    });

    test(
        'every level passes all validity rules and is solvable by greedy solver',
        () {
      for (final level in allLevels) {
        final val = validateLevel(level);
        expect(
          val.isValid,
          isTrue,
          reason:
              'Level #${level.id} (Ch ${level.chapter}) failed validation: ${val.error}',
        );

        final solveRes = solve(level);
        expect(
          solveRes.isSolved,
          isTrue,
          reason: 'Level #${level.id} (Ch ${level.chapter}) must be solvable',
        );
        expect(
          solveRes.initialFreeCount,
          greaterThanOrEqualTo(1),
          reason:
              'Level #${level.id} must have at least 1 free thread initially',
        );
        expect(
          solveRes.removalOrder.length,
          equals(level.threads.length),
          reason:
              'Level #${level.id} solve removal order must include all threads',
        );
      }
    });

    test('conveyor_level_01.json passes validation and is solvable', () {
      final file = File('assets/levels/conveyor_level_01.json');
      expect(file.existsSync(), isTrue);
      final jsonMap =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final level = Level.fromJson(jsonMap);

      final val = validateLevel(level);
      expect(val.isValid, isTrue,
          reason: 'conveyor_level_01 validation failed: ${val.error}');

      final solveRes = solve(level);
      expect(solveRes.isSolved, isTrue,
          reason: 'conveyor_level_01 must be solvable');
      expect(solveRes.initialFreeCount, greaterThanOrEqualTo(1));
      expect(solveRes.removalOrder.length, equals(level.threads.length));
    });
  });
}
