import 'dart:convert';
import 'dart:io';

import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/hit_tester.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tap Acceptance Test (Step 5)', () {
    final levelsToTest = [1, 25, 50, 100, 150, 200];
    final loadedLevels = <int, Level>{};

    setUpAll(() {
      for (final id in levelsToTest) {
        final chapter = ((id - 1) ~/ 20) + 1;
        final numStr = chapter.toString().padLeft(2, '0');
        final file = File('assets/levels/chapter_$numStr.json');
        final jsonMap =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final levelsRaw = jsonMap['levels'] as List<dynamic>;
        final raw = levelsRaw.firstWhere((r) => r['id'] == id);
        loadedLevels[id] =
            Level.fromJson(raw as Map<String, dynamic>, chapter: chapter);
      }
    });

    for (final levelId in levelsToTest) {
      test('Level $levelId: 10 positions along every thread stroke and arrowhead resolve 100% and animation record exists', () {
        final level = loadedLevels[levelId]!;
        final hitTester = BoardHitTester(level);
        final animator = BoardAnimator(vsync: FakeTickerProvider());
        const cellSize = 22.0;
        animator.setLevel(level, cellSize);

        final activeIds = {for (final t in level.threads) t.id};
        int totalProbes = 0;
        int correctResolutions = 0;

        for (final thread in level.threads) {
          // Probe 8 positions along the stroke segments
          for (var i = 0; i < thread.cells.length - 1; i++) {
            final c1 = thread.cells[i];
            final c2 = thread.cells[i + 1];
            final p1 = Offset(c1.c * cellSize, c1.r * cellSize);
            final p2 = Offset(c2.c * cellSize, c2.r * cellSize);

            for (var frac in [0.15, 0.50, 0.85]) {
              final probe = Offset.lerp(p1, p2, frac)!;
              totalProbes++;
              final hit = hitTester.hitTest(
                localPosition: probe,
                cellSize: cellSize,
                activeThreadIds: activeIds,
              );
              if (hit == thread.id) {
                correctResolutions++;
              }
            }
          }

          // Probe 2 positions along the arrowhead chevron
          final head = thread.head;
          final headPos = Offset(head.c * cellSize, head.r * cellSize);
          const armLen = 0.23 * cellSize;
          final tipProbe = headPos +
              Offset(thread.dir.dx * armLen * 0.5,
                  thread.dir.dy * armLen * 0.5);
          totalProbes++;
          final tipHit = hitTester.hitTest(
            localPosition: tipProbe,
            cellSize: cellSize,
            activeThreadIds: activeIds,
          );
          if (tipHit == thread.id) correctResolutions++;

          totalProbes++;
          final headHit = hitTester.hitTest(
            localPosition: headPos,
            cellSize: cellSize,
            activeThreadIds: activeIds,
          );
          if (headHit == thread.id) correctResolutions++;

          // Verify animation record creation
          animator.triggerExit(thread.id, reduceMotion: false);
          expect(animator.exits.containsKey(thread.id), isTrue,
              reason: 'Animation record must exist immediately upon trigger');
        }

        expect(totalProbes, greaterThanOrEqualTo(level.threads.length * 4));
        final percent = (correctResolutions / totalProbes) * 100.0;
        expect(percent, equals(100.0),
            reason: 'Level $levelId probe hit accuracy must be 100%');

        animator.dispose();
      });
    }
  });
}
