import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class FakeAudio extends AudioService {
  @override
  void play(SoundEvent e) {}
  @override
  void playPull() {}
  @override
  void playBlock() {}
  @override
  void playComplete() {}
}

void main() {
  group('Stuck Animation Test (Step 5)', () {
    testWidgets('irregular frame gaps (including a 2s gap) and pumpAndSettle: no record remains, ticker inactive, level completes', (tester) async {
      final level = Level(
        id: 998,
        rows: 5,
        cols: 5,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(1, 0), const Cell(1, 1)]),
        ],
      );

      final container = ProviderContainer();
      final vsync = FakeTickerProvider();
      final animator = BoardAnimator(vsync: vsync);
      animator.setLevel(level, 20.0);

      final controller = GameController(
        level: level,
        animator: animator,
        audio: FakeAudio(),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      // Tap both threads
      controller.handleThreadTap(1, 20.0);
      controller.handleThreadTap(2, 20.0);

      expect(animator.exits.length, equals(2));
      expect(controller.currentState.activeIds.isEmpty, isTrue);

      // Simulate irregular frame gap (e.g. 50ms, then a 2000ms hitch)
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();

      // Finalize running animations cleanly
      animator.finalizeAllRunningAnimations();

      expect(animator.exits.isEmpty, isTrue,
          reason: 'No animation record remains after elapsed duration');
      expect(animator.hasActiveAnimations, isFalse,
          reason: 'Ticker must be inactive when all animations finalize');

      animator.dispose();
      controller.dispose();
      container.dispose();
    });

    testWidgets('app pause in the middle instantly finalizes all animations so none survive', (tester) async {
      final level = Level(
        id: 997,
        rows: 5,
        cols: 5,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(2, 0), const Cell(2, 1)]),
        ],
      );

      final container = ProviderContainer();
      final vsync = FakeTickerProvider();
      final animator = BoardAnimator(vsync: vsync);
      animator.setLevel(level, 20.0);

      final controller = GameController(
        level: level,
        animator: animator,
        audio: FakeAudio(),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      controller.handleThreadTap(1, 20.0);
      expect(animator.exits.containsKey(1), isTrue);

      // App lifecycle pauses: finalise all running animations instantly
      animator.finalizeAllRunningAnimations();

      expect(animator.exits.isEmpty, isTrue,
          reason: 'App pause instantly clears all running animations');
      expect(animator.hasActiveAnimations, isFalse,
          reason: 'Ticker stops immediately on app pause');

      animator.dispose();
      controller.dispose();
      container.dispose();
    });
  });
}
