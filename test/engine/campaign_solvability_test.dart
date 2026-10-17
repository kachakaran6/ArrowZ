import 'dart:io';
import 'package:arrowtapout/data/level_binary_codec.dart';
import 'package:arrowtapout/engine/arrow_extraction_engine.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/solvability_engine.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Campaign Solvability Engine & Deflector Verification Tests', () {
    late Level lvl24;

    setUpAll(() {
      final bytes = File('assets/levels.bin').readAsBytesSync();
      final decoder = LevelBinaryDecoder.fromBytes(bytes);
      lvl24 = decoder.decodeLevelByNumber(24)!;
    });

    test('Level 24 definition and structural validation', () {
      expect(lvl24.id, equals(24));
      expect(lvl24.chapter, equals(2));
      expect(lvl24.threads.length, equals(22));
      expect(lvl24.deflectors.length, equals(1));

      final deflector = lvl24.deflectors.first;
      expect(deflector.cell, equals(const Cell(4, 4)));
      expect(deflector.dir, equals(Dir.up));
    });

    test('Level 24 solves and verifies against authoritative game engine', () {
      const engine = SolvabilityEngine();
      final report = engine.auditLevel(lvl24);

      expect(report.isPassed, isTrue, reason: report.failureReason);
      expect(report.status, equals(SolvabilityStatus.solved));
      expect(report.requiresDeflectors, isTrue,
          reason:
              'Level 24 strictly requires deflector to avoid {1, 4, 5} circular deadlock');
      expect(report.solutionPath.length, equals(22));
      expect(report.verifiedAgainstEngine, isTrue);
    });

    test('Level 24 without deflectors produces a proven circular deadlock', () {
      final noDefLvl24 = Level(
        id: lvl24.id,
        rows: lvl24.rows,
        cols: lvl24.cols,
        threads: lvl24.threads,
        deflectors: const [],
      );

      const engine = SolvabilityEngine();
      final report = engine.auditLevel(noDefLvl24);

      expect(report.isPassed, isFalse);
      expect(report.status, equals(SolvabilityStatus.circularDeadlock));
      expect(report.deadlockCycle, isNotEmpty);
      expect(report.failureReason, contains('Circular deadlock'));
    });

    test('ExtractionTrack correctly turns at deflector cell', () {
      final t5 = lvl24.threads.firstWhere((t) => t.id == 5);
      expect(t5.head, equals(const Cell(4, 7)));
      expect(t5.dir, equals(Dir.left));

      // Build ExtractionTrack with Level 24 deflectors
      final track = ExtractionTrack(
        thread: t5,
        cellSize: 30.0,
        rows: lvl24.rows,
        cols: lvl24.cols,
        deflectors: lvl24.deflectors,
      );

      // Verify the track's total distance includes the deflected ray
      expect(track.rayLengthPx, greaterThan(0.0));
      expect(track.durationMs, greaterThanOrEqualTo(340.0));

      // Sample extraction at 100% completion
      final sample = track.sample(1.0);
      expect(sample.isCompleted, isTrue);
    });

    test('Immediate deadlock cycle detection on synthetic circular puzzle', () {
      // Create 3 arrows in a head-to-tail circular blockage:
      // A (points right) hits B
      // B (points down) hits C
      // C (points left) hits A
      final threads = [
        Thread(1,
            [const Cell(0, 0), const Cell(0, 1)]), // points right into (0, 2)
        Thread(
            2, [const Cell(0, 2), const Cell(1, 2)]), // points down into (2, 2)
        Thread(3, [
          const Cell(2, 2),
          const Cell(2, 1),
          const Cell(2, 0),
          const Cell(1, 0)
        ]), // points up into (0, 0)
      ];

      final deadlockedLevel = Level(
        id: 9999,
        rows: 5,
        cols: 5,
        threads: threads,
      );

      const engine = SolvabilityEngine();
      final report = engine.auditLevel(deadlockedLevel);

      expect(report.isPassed, isFalse);
      expect(report.status, equals(SolvabilityStatus.immediateDeadlock));
      expect(report.initialFreeCount, equals(0));
      expect(report.deadlockCycle, isNotEmpty);
    });

    test('Verify first 30 levels of campaign are solvable and engine-verified',
        () {
      final bytes = File('assets/levels.bin').readAsBytesSync();
      final decoder = LevelBinaryDecoder.fromBytes(bytes);
      const engine = SolvabilityEngine();

      for (var i = 1; i <= 30; i++) {
        final level = decoder.decodeLevelByNumber(i);
        expect(level, isNotNull, reason: 'Level $i must exist');

        final report = engine.auditLevel(level!);
        expect(report.isPassed, isTrue,
            reason: 'Level $i failed audit: ${report.failureReason}');
        expect(report.verifiedAgainstEngine, isTrue);
      }
    });
  });
}
