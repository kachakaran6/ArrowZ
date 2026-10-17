import 'package:arrowtapout/engine/level_generator_v2.dart';
import 'package:arrowtapout/engine/solver.dart';
import 'package:arrowtapout/engine/validity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelGeneratorV2 Tests', () {
    test('Tutorial 1 is valid, solvable, and has 3 threads', () {
      final level = LevelGeneratorV2.generateLevel(1);
      expect(level.id, equals(1));
      expect(level.threads.length, equals(3));
      expect(level.deflectors, isEmpty);

      final val = validateLevel(level);
      expect(val.isValid, isTrue, reason: val.error);

      final sol = solve(level);
      expect(sol.isSolved, isTrue);
      expect(sol.initialFreeCount, greaterThanOrEqualTo(1));
    });

    test('Tutorial 2 has colorGroup pair and is solvable', () {
      final level = LevelGeneratorV2.generateLevel(2);
      expect(level.id, equals(2));
      expect(level.threads.length, equals(3));
      final paired = level.threads.where((t) => t.colorGroup != null).toList();
      expect(paired.length, equals(2));
      expect(paired[0].colorGroup, equals(paired[1].colorGroup));

      final val = validateLevel(level);
      expect(val.isValid, isTrue, reason: val.error);

      final sol = solve(level);
      expect(sol.isSolved, isTrue);
    });

    test('Tutorial 3 has deflector and is solvable', () {
      final level = LevelGeneratorV2.generateLevel(3);
      expect(level.id, equals(3));
      expect(level.deflectors.length, equals(1));

      final val = validateLevel(level);
      expect(val.isValid, isTrue, reason: val.error);

      final sol = solve(level);
      expect(sol.isSolved, isTrue);
    });

    test(
        'Levels 4 to 10 strictly respect mechanic gate (no deflectors, no color pairs)',
        () {
      for (var lvl = 4; lvl <= 10; lvl++) {
        final level = LevelGeneratorV2.generateLevel(lvl);
        expect(level.id, equals(lvl));
        expect(level.deflectors, isEmpty,
            reason: 'Level $lvl must not contain deflectors during early gate');
        final paired = level.threads.where((t) => t.colorGroup != null);
        expect(paired, isEmpty,
            reason:
                'Level $lvl must not contain color pairs during early gate');

        final val = validateLevel(level);
        expect(val.isValid, isTrue,
            reason: 'Level $lvl failed validation: ${val.error}');

        final sol = solve(level);
        expect(sol.isSolved, isTrue, reason: 'Level $lvl must be solvable');
      }
    });

    test('Levels 16 to 22 generate valid solvable levels with mechanics', () {
      for (var lvl = 16; lvl <= 22; lvl++) {
        final level = LevelGeneratorV2.generateLevel(lvl);
        expect(level.id, equals(lvl));
        expect(level.threads.isNotEmpty, isTrue);

        final val = validateLevel(level);
        expect(val.isValid, isTrue,
            reason: 'Level $lvl failed validation: ${val.error}');

        final sol = solve(level);
        expect(sol.isSolved, isTrue, reason: 'Level $lvl must be solvable');
      }
    });
  });
}
