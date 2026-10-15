import 'dart:io';

import 'package:arrowtapout/data/daily_thread_service.dart';
import 'package:arrowtapout/data/level_binary_codec.dart';
import 'package:arrowtapout/engine/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daily Thread: 8 board symmetries preserve solvability across levels', () async {
    final file = File('assets/levels.bin');
    expect(file.existsSync(), isTrue);

    final bytes = await file.readAsBytes();
    final decoder = LevelBinaryDecoder.fromBytes(bytes);
    final levels = decoder.decodeAll();
    expect(levels.length, greaterThanOrEqualTo(200));

    // Test all 8 symmetries across levels (sample key levels and showpieces)
    final testLevels = [1, 2, 5, 10, 20, 36, 50, 100, 150, 200];

    for (final id in testLevels) {
      final level = levels.firstWhere((l) => l.id == id);
      for (var sym = 0; sym < 8; sym++) {
        final transformed = DailyThreadService.applySymmetry(level, sym);
        expect(transformed.threads.length, level.threads.length);
        final solution = solve(transformed);
        expect(solution.isSolved, isTrue,
            reason: 'Level $id with symmetry $sym must be solvable');
      }
    }
  });

  test('Daily Thread deterministic date hashing', () {
    final d1 = DateTime(2026, 10, 15);
    final d2 = DateTime(2026, 10, 15);
    final d3 = DateTime(2026, 10, 16);

    expect(DailyThreadService.getDailyLevelId(d1), DailyThreadService.getDailyLevelId(d2));
    expect(DailyThreadService.getDailyLevelId(d1), inInclusiveRange(1, 200));
    expect(DailyThreadService.getDailySymmetryIndex(d1), inInclusiveRange(0, 7));
    expect(DailyThreadService.getDailyLevelId(d1) != DailyThreadService.getDailyLevelId(d3) ||
           DailyThreadService.getDailySymmetryIndex(d1) != DailyThreadService.getDailySymmetryIndex(d3), isTrue);
  });
}
