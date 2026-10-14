import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Spy platform executor tracking invocation counts and event sequence.
class SpyHapticPlatformExecutor implements HapticPlatformExecutor {
  final List<String> eventLog = [];
  bool throwOnCall = false;

  int get lightCount => eventLog.where((e) => e == 'light').length;
  int get mediumCount => eventLog.where((e) => e == 'medium').length;
  int get selectionCount => eventLog.where((e) => e == 'selection').length;

  @override
  Future<void> lightImpact() async {
    if (throwOnCall) {
      throw PlatformException(
        code: 'VIBRATE_UNAVAILABLE',
        message: 'Device haptic hardware unavailable or busy',
      );
    }
    eventLog.add('light');
  }

  @override
  Future<void> mediumImpact() async {
    if (throwOnCall) {
      throw PlatformException(
        code: 'VIBRATE_UNAVAILABLE',
        message: 'Device haptic hardware unavailable or busy',
      );
    }
    eventLog.add('medium');
  }

  @override
  Future<void> selectionClick() async {
    if (throwOnCall) {
      throw PlatformException(
        code: 'VIBRATE_UNAVAILABLE',
        message: 'Device haptic hardware unavailable or busy',
      );
    }
    eventLog.add('selection');
  }

  void clear() {
    eventLog.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArrowZ Haptic Feedback Timing & Lifecycle Acceptance Tests', () {
    late ProviderContainer container;
    late BoardAnimator animator;
    late SpyHapticPlatformExecutor spyExecutor;
    late HapticsService hapticsService;

    // Test level: Thread 2 is free (points up); Thread 1 is blocked by Thread 2 at (0, 2).
    final testLevel = Level(
      id: 10,
      rows: 4,
      cols: 4,
      threads: [
        Thread(1, [
          const Cell(0, 0),
          const Cell(0, 1),
        ]), // points right into (0,2), BLOCKED by Thread 2
        Thread(2, [
          const Cell(1, 2),
          const Cell(0, 2),
        ]), // occupies (0,2), points up, FREE to exit
      ],
    );

    setUp(() {
      spyExecutor = SpyHapticPlatformExecutor();
      container = ProviderContainer(
        overrides: [
          hapticsServiceProvider.overrideWith((ref) {
            return HapticsService(ref, executor: spyExecutor);
          }),
        ],
      );
      animator = BoardAnimator(vsync: FakeTickerProvider());
      animator.setLevel(testLevel, 24.0);
      hapticsService = container.read(hapticsServiceProvider);
    });

    tearDown(() {
      animator.dispose();
      container.dispose();
    });

    GameController createController({Level? level}) {
      final lvl = level ?? testLevel;
      animator.setLevel(lvl, 24.0);
      return GameController(
        level: lvl,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: hapticsService,
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );
    }

    test(
        '1. A valid arrow tap requests light haptics at the interaction boundary',
        () {
      final controller = createController();
      expect(spyExecutor.lightCount, equals(0));

      // Tap free arrow 2
      controller.handleThreadTap(2, 24.0);

      // Feedback should have been requested immediately
      expect(spyExecutor.lightCount, equals(1));
      expect(spyExecutor.eventLog.first, equals('light'));
      expect(controller.state.activeIds.contains(2), isFalse);
      expect(controller.state.moves, equals(1));
    });

    test(
        '2. A blocked arrow tap requests medium feedback without waiting for an animation',
        () {
      final controller = createController();
      expect(spyExecutor.mediumCount, equals(0));

      // Tap blocked arrow 1 (blocked by arrow 2)
      controller.handleThreadTap(1, 24.0);

      // Feedback should occur immediately upon blocked tap detection
      expect(spyExecutor.mediumCount, equals(1));
      expect(spyExecutor.eventLog.first, equals('medium'));
      expect(controller.state.mistakes, equals(1));
    });

    test('3. Completing a level does not replay earlier tap feedback',
        () async {
      // 1-thread level to test completion cleanly
      final singleLevel = Level(
        id: 5,
        rows: 4,
        cols: 4,
        threads: [
          Thread(2, [const Cell(1, 1), const Cell(1, 2)]),
        ],
      );
      final controller = createController(level: singleLevel);

      // Tap thread 2 to exit and trigger level completion
      controller.handleThreadTap(2, 24.0);
      expect(spyExecutor.lightCount, equals(1));
      expect(spyExecutor.mediumCount, equals(0));

      final logBeforeCompletion = List<String>.from(spyExecutor.eventLog);

      // Wait for completion timer (350ms stillness)
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(controller.state.status, equals(GameStatus.completed));
      // Verify NO earlier tap haptics were replayed
      expect(spyExecutor.eventLog, equals(logBeforeCompletion));
      expect(spyExecutor.lightCount, equals(1));
    });

    test(
        '4. Rapid taps do not create duplicate haptic events for the same accepted move',
        () {
      final controller = createController();

      // Tap blocked arrow 1 first (arrow 2 is still on board blocking it)
      controller.handleThreadTap(1, 24.0);
      expect(spyExecutor.mediumCount, equals(1));

      // Immediate successive tap on the same blocked arrow within 250ms debounce window
      controller.handleThreadTap(1, 24.0);
      controller.handleThreadTap(1, 24.0);
      expect(spyExecutor.mediumCount, equals(1));

      // Tap free arrow 2
      controller.handleThreadTap(2, 24.0);
      expect(spyExecutor.lightCount, equals(1));

      // Immediate successive taps on the same arrow while it is exiting
      controller.handleThreadTap(2, 24.0);
      controller.handleThreadTap(2, 24.0);
      controller.handleThreadTap(2, 24.0);

      // No duplicate haptics dispatched for the same arrow
      expect(spyExecutor.lightCount, equals(1));
    });

    test('5. Disabling haptics prevents game-triggered feedback', () {
      // Disable haptics in settings repository
      container.read(settingsProvider.notifier).state = const SettingsState(
        themeChoice: AppThemeMode.sageLinen,
        sound: true,
        haptics: false,
        reduceMotion: false,
      );

      final controller = createController();

      // Blocked tap
      controller.handleThreadTap(1, 24.0);
      expect(spyExecutor.mediumCount, equals(0));

      // Valid tap
      controller.handleThreadTap(2, 24.0);
      expect(spyExecutor.lightCount, equals(0));

      expect(spyExecutor.eventLog, isEmpty);
    });

    test('6. Animation completion does not invoke tap haptics', () {
      final controller = createController();

      // Tap arrow 2
      controller.handleThreadTap(2, 24.0);
      expect(spyExecutor.lightCount, equals(1));
      expect(animator.exits.containsKey(2), isTrue);

      // Check exit progress
      final exit = animator.exits[2]!;
      expect(exit.isDone(animator.nowMs + 600.0), isTrue);

      // No additional tap haptics were dispatched during or after animation
      expect(spyExecutor.lightCount, equals(1));
      expect(spyExecutor.eventLog.length, equals(1));
    });

    test('7. A haptic-service failure does not break gameplay', () {
      spyExecutor.throwOnCall = true;
      final controller = createController();

      // Blocked tap should register mistake despite platform haptic exception
      expect(() => controller.handleThreadTap(1, 24.0), returnsNormally);
      expect(controller.state.mistakes, equals(1));
      expect(controller.state.status, equals(GameStatus.playing));

      // Valid tap should succeed despite platform haptic exception
      expect(() => controller.handleThreadTap(2, 24.0), returnsNormally);
      expect(controller.state.activeIds.contains(2), isFalse);
      expect(controller.state.moves, equals(1));
    });

    test(
        '8. Restarting or leaving a screen does not leave queued haptic requests behind',
        () {
      final controller = createController();

      controller.handleThreadTap(2, 24.0);
      expect(spyExecutor.lightCount, equals(1));

      // Restart level
      controller.restartLevel(24.0);
      expect(controller.state.activeIds.length, equals(2));
      expect(controller.state.moves, equals(0));

      // Verify no queued haptic events were triggered by restart
      expect(spyExecutor.lightCount, equals(1));

      // Dispose controller
      controller.dispose();

      // No lingering haptic requests
      expect(spyExecutor.lightCount, equals(1));
    });
  });
}
