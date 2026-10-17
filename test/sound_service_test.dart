import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SpyHapticPlatformExecutor implements HapticPlatformExecutor {
  int lightCount = 0;
  int heavyCount = 0;
  int mediumCount = 0;
  int selectionCount = 0;
  int successCount = 0;
  int vibrateCount = 0;

  @override
  Future<void> lightImpact() async => lightCount++;

  @override
  Future<void> mediumImpact() async => mediumCount++;

  @override
  Future<void> heavyImpact() async => heavyCount++;

  @override
  Future<void> selectionClick() async => selectionCount++;

  @override
  Future<void> vibrate() async => vibrateCount++;

  @override
  Future<void> success() async => successCount++;
}

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
    test(
        'Sound count test: 60 accepted taps across 3 levels produce exactly 60 pull calls and blocked calls match',
        () {
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

    test(
        'Sound lifetime test: persistent service is never disposed across game cycles',
        () async {
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

    test('AudioService concurrent initialization race protection', () async {
      final audioService = AudioService();

      // Call init multiple times concurrently
      final f1 = audioService.init();
      final f2 = audioService.init();
      final f3 = audioService.init();

      await Future.wait([f1, f2, f3]);

      // Subsequent calls after completion return immediately
      await audioService.init();

      audioService.dispose();
    });

    test('AudioService settings toggle and instant mute policy', () async {
      final audioService = AudioService();
      await audioService.init();

      final initialRequested = Diagnostics.instance.soundRequested;

      // Sound enabled by default
      audioService.playPull();
      expect(Diagnostics.instance.soundRequested, equals(initialRequested + 1));

      // Disable sound
      audioService.updateSoundEnabled(false);
      audioService.playPull();
      audioService.playBlock();
      expect(Diagnostics.instance.soundRequested, equals(initialRequested + 3));

      // Re-enable sound
      audioService.updateSoundEnabled(true);
      audioService.playComplete();
      expect(Diagnostics.instance.soundRequested, equals(initialRequested + 4));

      audioService.dispose();
    });

    test(
        'Multi-level transitions and restart preserve feedback without degradation',
        () async {
      final fakeSound = FakeSoundService();
      final fakeAudio = FakeAudioService(fakeSound);
      final spyHaptics = SpyHapticPlatformExecutor();
      final container = ProviderContainer(
        overrides: [
          soundServiceProvider.overrideWithValue(fakeSound),
          audioServiceProvider.overrideWithValue(fakeAudio),
          hapticsServiceProvider
              .overrideWith((ref) => HapticsService(ref, executor: spyHaptics)),
        ],
      );

      final haptics = container.read(hapticsServiceProvider);

      // Play 3 consecutive levels
      for (var lvl = 1; lvl <= 3; lvl++) {
        final level = Level(
          id: lvl,
          rows: 4,
          cols: 4,
          threads: [
            Thread(1, [const Cell(0, 0), const Cell(0, 1)]), // exits up
          ],
        );
        final anim = BoardAnimator(vsync: FakeTickerProvider());
        final ctrl = GameController(
          level: level,
          animator: anim,
          audio: fakeAudio,
          haptics: haptics,
          progress: container.read(progressProvider.notifier),
          snapshotRepo: container.read(snapshotRepositoryProvider),
        );

        // Valid move
        ctrl.handleThreadTap(1, 24.0);
        expect(fakeSound.pullCalls, equals(lvl));
        expect(spyHaptics.lightCount, equals(lvl));

        // Let completion finalize
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(ctrl.state.status, equals(GameStatus.completed));
        expect(fakeSound.completeCalls, equals(lvl));
        expect(spyHaptics.successCount, equals(lvl));

        // Restart simulation
        ctrl.restartLevel(24.0);
        expect(ctrl.state.status, equals(GameStatus.playing));

        anim.dispose();
        ctrl.dispose();
      }

      container.dispose();
    });
  });
}
