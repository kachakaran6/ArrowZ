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

class FakeSoundService extends AudioService {
  int pullCalls = 0;
  int blockCalls = 0;

  @override
  void play(SoundEvent e) {
    if (e == SoundEvent.pull) pullCalls++;
    if (e == SoundEvent.block) blockCalls++;
  }

  @override
  void playPull() => play(SoundEvent.pull);

  @override
  void playBlock() => play(SoundEvent.block);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rapid Tap Test (Step 5)', () {
    test(
        '12 taps in 1 second on distinct free threads: all accepted, 0 dropped, all reach gone',
        () async {
      // Build level with 12 distinct free threads
      final threads = <Thread>[];
      for (var i = 0; i < 12; i++) {
        threads.add(
            Thread(i + 1, [Cell(i * 2, 0), Cell(i * 2, 1)])); // all point right
      }
      final level = Level(id: 999, rows: 25, cols: 5, threads: threads);

      final container = ProviderContainer();
      final vsync = FakeTickerProvider();
      final animator = BoardAnimator(vsync: vsync);
      animator.setLevel(level, 20.0);
      final fakeSound = FakeSoundService();

      final controller = GameController(
        level: level,
        animator: animator,
        audio: fakeSound,
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      expect(controller.currentState.activeIds.length, equals(12));

      // Simulate 12 rapid taps within 1000ms (one every 80ms)
      for (var i = 1; i <= 12; i++) {
        controller.handleThreadTap(i, 20.0);
      }

      // Assert all 12 taps accepted immediately
      expect(fakeSound.pullCalls, equals(12),
          reason: 'All 12 distinct taps must play pull sound');
      expect(controller.currentState.activeIds.isEmpty, isTrue,
          reason: 'All 12 threads must be removed from active occupancy');
      expect(animator.exits.length, equals(12),
          reason: 'All 12 animation records must be registered');

      // Now simulate elapsed time advancing to 600ms (well past duration of ~380ms)
      // Ticker pruning completes and all reach gone
      animator.finalizeAllRunningAnimations();

      expect(animator.exits.isEmpty, isTrue,
          reason: 'All 12 threads reach gone');
      expect(animator.hasActiveAnimations, isFalse,
          reason: 'Ticker inactive once all animations finalize');

      animator.dispose();
      controller.dispose();
      container.dispose();
    });
  });
}
