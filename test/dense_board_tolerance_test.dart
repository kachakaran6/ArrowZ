import 'dart:convert';
import 'dart:io';

import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/hit_tester.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dense Board Tolerance & Resolution Tests (Step 5)', () {
    late Level level200;

    setUpAll(() {
      final file = File('assets/levels/chapter_10.json');
      final jsonMap =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final levelsRaw = jsonMap['levels'] as List<dynamic>;
      final raw200 = levelsRaw.firstWhere((r) => r['id'] == 200);
      level200 = Level.fromJson(raw200 as Map<String, dynamic>, chapter: 10);
    });

    test('on level 200 with cell ~15 dp, tolerance is at least 14 dp', () {
      const cellSize = 15.0;

      // Hit tolerance must be max(0.5 * cell, 14.0) -> at least 14.0 dp
      final tolerance = BoardHitTester.computeToleranceDp(cellSize);
      expect(tolerance, greaterThanOrEqualTo(14.0));
      expect(tolerance, equals(14.0));
    });

    test('two adjacent parallel threads resolve to the nearer one', () {
      const cellSize = 15.0;
      final tester = BoardHitTester(level200);
      final activeIds = {for (final t in level200.threads) t.id};

      // Find two parallel threads in level 200 that are adjacent
      for (final t1 in level200.threads) {
        for (final t2 in level200.threads) {
          if (t1.id >= t2.id) continue;
          if (t1.dir != t2.dir) continue;

          // Check if heads or stroke segments are 1 cell apart
          final headDist = (t1.head.r - t2.head.r).abs() + (t1.head.c - t2.head.c).abs();
          if (headDist == 1) {
            final p1 = Offset(t1.head.c * cellSize, t1.head.r * cellSize);
            final p2 = Offset(t2.head.c * cellSize, t2.head.r * cellSize);

            // Point slightly closer to t1 (40% between p1 and p2)
            final tapNearT1 = Offset.lerp(p1, p2, 0.40)!;
            final hit1 = tester.hitTest(
              localPosition: tapNearT1,
              cellSize: cellSize,
              activeThreadIds: activeIds,
            );
            expect(hit1, equals(t1.id),
                reason: 'Tap 40% towards t2 from t1 must resolve to t1');

            // Point slightly closer to t2 (60% between p1 and p2)
            final tapNearT2 = Offset.lerp(p1, p2, 0.60)!;
            final hit2 = tester.hitTest(
              localPosition: tapNearT2,
              cellSize: cellSize,
              activeThreadIds: activeIds,
            );
            expect(hit2, equals(t2.id),
                reason: 'Tap 60% towards t2 from t1 must resolve to t2');
            return;
          }
        }
      }
    });
  });
}
