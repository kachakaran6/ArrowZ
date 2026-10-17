import 'dart:math' as math;

import 'package:arrowtapout/engine/arrow_extraction_engine.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArrowExtractionEngine & ExtractionTrack Geometry Tests', () {
    const double cellSize = 30.0;
    const int rows = 8;
    const int cols = 8;

    test('Straight horizontal arrow extraction (pointing right)', () {
      final thread = Thread(1, [
        const Cell(2, 1),
        const Cell(2, 2),
        const Cell(2, 3),
        const Cell(2, 4),
      ]);
      expect(thread.dir, Dir.right);

      final track = ExtractionTrack(
        thread: thread,
        cellSize: cellSize,
        rows: rows,
        cols: cols,
      );

      // At start (progress = 0)
      final startGeom = track.sample(0.0);
      expect(startGeom.isCompleted, isFalse);
      expect(startGeom.headPosition.dx, closeTo(4 * cellSize, 1e-3));
      expect(startGeom.headPosition.dy, closeTo(2 * cellSize, 1e-3));
      expect(startGeom.headAngleRad, closeTo(0.0, 1e-3)); // Right
      expect(startGeom.alpha, closeTo(1.0, 1e-3));

      // At middle (progress = 0.5)
      final midGeom = track.sample(0.5);
      expect(midGeom.headPosition.dx, greaterThan(startGeom.headPosition.dx));
      expect(midGeom.headPosition.dy, closeTo(2 * cellSize, 1e-3));
      expect(midGeom.headAngleRad, closeTo(0.0, 1e-3));

      // At end (progress = 1.0)
      final endGeom = track.sample(1.0);
      expect(endGeom.isCompleted, isTrue);
      expect(endGeom.alpha, closeTo(0.0, 1e-3));
    });

    test('L-shaped arrow with a 90-degree bend (pointing down)', () {
      final thread = Thread(2, [
        const Cell(1, 1),
        const Cell(1, 2),
        const Cell(1, 3),
        const Cell(1, 4), // horizontal segment
        const Cell(2, 4),
        const Cell(3, 4),
        const Cell(4, 4), // vertical segment pointing down
      ]);
      expect(thread.dir, Dir.down);

      final track = ExtractionTrack(
        thread: thread,
        cellSize: cellSize,
        rows: rows,
        cols: cols,
      );

      // At start
      final startGeom = track.sample(0.0);
      expect(startGeom.headPosition.dx, closeTo(4 * cellSize, 1e-3));
      expect(startGeom.headPosition.dy, closeTo(4 * cellSize, 1e-3));
      expect(startGeom.headAngleRad, closeTo(math.pi / 2.0, 1e-3)); // Down

      // Spec 13 anticipation: thread pulls back gently during [0, 0.2], then advances downwards
      final dipGeom = track.sample(0.10);
      expect(dipGeom.displacementPx,
          lessThan(0.0)); // Negative displacement (pull back)
      expect(dipGeom.headPosition.dy,
          lessThanOrEqualTo(startGeom.headPosition.dy + 1e-6));

      // After anticipation (from progress = 0.25 onward), head advances downwards monotonically
      var prevHeadY = track.sample(0.25).headPosition.dy;
      var prevDisplacement = track.sample(0.25).displacementPx;

      for (var i = 6; i <= 20; i++) {
        final progress = i / 20.0;
        final geom = track.sample(progress);
        expect(geom.headPosition.dy, greaterThanOrEqualTo(prevHeadY - 1e-6));
        expect(
            geom.displacementPx, greaterThanOrEqualTo(prevDisplacement - 1e-6));
        prevHeadY = geom.headPosition.dy;
        prevDisplacement = geom.displacementPx;
      }
    });

    test('U-shaped arrow with multiple corners (pointing up)', () {
      final thread = Thread(3, [
        const Cell(1, 2),
        const Cell(2, 2),
        const Cell(3, 2),
        const Cell(4, 2),
        const Cell(5, 2), // segment 1: down
        const Cell(5, 3),
        const Cell(5, 4),
        const Cell(5, 5), // segment 2: right
        const Cell(4, 5),
        const Cell(3, 5),
        const Cell(2, 5), // segment 3: up
      ]);
      expect(thread.dir, Dir.up);

      final track = ExtractionTrack(
        thread: thread,
        cellSize: cellSize,
        rows: rows,
        cols: cols,
      );

      final startGeom = track.sample(0.0);
      expect(startGeom.headAngleRad, closeTo(-math.pi / 2.0, 1e-3)); // Up

      // At progress = 1.0, completed
      final endGeom = track.sample(1.0);
      expect(endGeom.isCompleted, isTrue);
    });

    test('All 4 cardinal exit directions have exact tangents', () {
      final upThread = Thread(10, [const Cell(4, 3), const Cell(1, 3)]);
      final downThread = Thread(11, [const Cell(1, 3), const Cell(4, 3)]);
      final leftThread = Thread(12, [const Cell(3, 4), const Cell(3, 1)]);
      final rightThread = Thread(13, [const Cell(3, 1), const Cell(3, 4)]);

      final upTrack = ExtractionTrack(
          thread: upThread, cellSize: cellSize, rows: rows, cols: cols);
      final downTrack = ExtractionTrack(
          thread: downThread, cellSize: cellSize, rows: rows, cols: cols);
      final leftTrack = ExtractionTrack(
          thread: leftThread, cellSize: cellSize, rows: rows, cols: cols);
      final rightTrack = ExtractionTrack(
          thread: rightThread, cellSize: cellSize, rows: rows, cols: cols);

      expect(upTrack.sample(0.0).headAngleRad, closeTo(-math.pi / 2.0, 1e-3));
      expect(downTrack.sample(0.0).headAngleRad, closeTo(math.pi / 2.0, 1e-3));
      expect(leftTrack.sample(0.0).headAngleRad, closeTo(math.pi, 1e-3));
      expect(rightTrack.sample(0.0).headAngleRad, closeTo(0.0, 1e-3));
    });

    test('Reduced motion mode keeps polyline stationary and fades alpha', () {
      final thread = Thread(20, [const Cell(2, 2), const Cell(2, 5)]);
      final track = ExtractionTrack(
          thread: thread, cellSize: cellSize, rows: rows, cols: cols);

      final startGeom = track.sample(0.0, reduceMotion: true);
      expect(startGeom.displacementPx, 0.0);
      expect(startGeom.alpha, 1.0);

      final midGeom = track.sample(0.5, reduceMotion: true);
      expect(midGeom.displacementPx, 0.0);
      expect(midGeom.alpha, closeTo(0.5, 1e-3));

      final endGeom = track.sample(1.0, reduceMotion: true);
      expect(endGeom.alpha, 0.0);
      expect(endGeom.isCompleted, isTrue);
    });
  });
}
