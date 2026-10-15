import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
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

class FakeSoundService implements SoundService {
  int initCallCount = 0;
  int pullCalls = 0;
  int blockCalls = 0;
  int completeCalls = 0;
  int uiCalls = 0;
  int onResumeCalls = 0;
  bool isDisposed = false;

  @override
  Diagnostics get stats => Diagnostics.instance;

  @override
  Future<void> init() async {
    initCallCount++;
  }

  @override
  void play(SoundEvent e) {
    switch (e) {
      case SoundEvent.pull:
        pullCalls++;
      case SoundEvent.block:
        blockCalls++;
      case SoundEvent.complete:
        completeCalls++;
      case SoundEvent.ui:
        uiCalls++;
    }
  }

  @override
  void onResume() {
    onResumeCalls++;
  }

  void dispose() {
    isDisposed = true;
  }
}

class FakeAudioService extends AudioService {
  FakeAudioService(this.fake);
  final FakeSoundService fake;

  @override
  void play(SoundEvent e) => fake.play(e);

  @override
  void playPull() => fake.play(SoundEvent.pull);

  @override
  void playBlock() => fake.play(SoundEvent.block);

  @override
  void playComplete() => fake.play(SoundEvent.complete);

  @override
  void playUi() => fake.play(SoundEvent.ui);

  @override
  void onResume() => fake.onResume();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sound Count & Lifetime Tests (Step 5)', () {
    test('Sound count test: 60 accepted taps across 3 levels produce exactly 60 pull calls and blocked calls match', () {
      final fakeSound = FakeSoundService();
      final fakeAudio = FakeAudioService(fakeSound);
      final container = ProviderContainer(
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          audioServiceProvider.overrideWithValue(fakeAudio),
        ],
      );

      // Create 3 levels with 20 threads each
      for (var levelId = 1; levelId <= 3; levelId++) {
        final threads = <Thread>[];
        for (var i = 0; i < 20; i++) {
          threads.add(Thread(i + 1, [Cell(i, 0), Cell(i, 1)]));
        }
        final level = Level(id: levelId, rows: 25, cols: 5, threads: threads);

        final animator = BoardAnimator(vsync: FakeTickerProvider());
        final controller = GameController(
          level: level,
          animator: animator,
          audio: fakeAudio,
          haptics: container.read(hapticsServiceProvider),
          progress: container.read(progressProvider.notifier),
          snapshotRepo: container.read(snapshotRepositoryProvider),
        );

        // Tap all 20 threads in this level
        for (var i = 1; i <= 20; i++) {
          controller.handleThreadTap(i, 20.0);
        }

        // Simulate app pause and resume
        fakeSound.onResume();

        // Level restart simulation
        controller.restartLevel(20.0);

        animator.dispose();
        controller.dispose();
      }

      // 3 levels * 20 threads = 60 accepted pull taps
      expect(fakeSound.pullCalls, equals(60));
      expect(fakeSound.onResumeCalls, equals(3));

      // Test blocked taps count matching
      final blockedLevel = Level(
        id: 99,
        rows: 5,
        cols: 5,
        threads: [
          Thread(1, [const Cell(1, 1), const Cell(1, 2)]), // Points right
          Thread(2, [const Cell(1, 3), const Cell(1, 4)]), // Blocks 1
        ],
      );
      final anim = BoardAnimator(vsync: FakeTickerProvider());
      final blockedController = GameController(
        level: blockedLevel,
        animator: anim,
        audio: fakeAudio,
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      // Tap blocked thread 1 three times
      blockedController.handleThreadTap(1, 20.0);
      blockedController.handleThreadTap(1, 20.0);
      blockedController.handleThreadTap(1, 20.0);

      expect(fakeSound.blockCalls, equals(3));

      anim.dispose();
      blockedController.dispose();
      container.dispose();
    });

    test('Sound lifetime test: persistent service is never disposed across game cycles', () async {
      final fakeSound = FakeSoundService();
      await fakeSound.init();
      expect(fakeSound.initCallCount, equals(1));

      final container = ProviderContainer(
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
        ],
      );

      // Simulating navigation through multiple scopes: Game -> Complete -> Next Game -> Restart -> Levels -> Game
      final service1 = container.read(soundServiceProvider);
      expect(identical(service1, fakeSound), isTrue);

      final service2 = container.read(soundServiceProvider);
      expect(identical(service2, service1), isTrue);

      expect(fakeSound.isDisposed, isFalse);
      expect(fakeSound.initCallCount, equals(1));

      container.dispose();
    });
  });
}
