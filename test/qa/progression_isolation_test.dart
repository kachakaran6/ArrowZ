import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/features/qa/qa_session.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoOpTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

Level _createLevel(int id) {
  return Level(
    id: id,
    rows: 4,
    cols: 4,
    threads: [
      Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late SharedPreferences prefs;
  late ProgressRepository progressRepo;
  late SnapshotRepository snapshotRepo;
  late StreakRepository streakRepo;
  late QaSessionController qaSessionController;
  late BoardAnimator animator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    progressRepo = container.read(progressProvider.notifier);
    snapshotRepo = container.read(snapshotRepositoryProvider);
    streakRepo = container.read(streakRepositoryProvider.notifier);
    qaSessionController = container.read(qaSessionProvider.notifier);
    animator = BoardAnimator(vsync: _NoOpTickerProvider());
  });

  tearDown(() {
    animator.dispose();
    container.dispose();
  });

  group('Progression Isolation & Testing Session Integrity', () {
    test(
        '1. Jumping to a locked level in QA session does not complete preceding levels or advance real progression',
        () async {
      // Baseline player progress: highestUnlocked is 1
      expect(progressRepo.state.highestUnlocked, equals(1));
      expect(progressRepo.state.stars, isEmpty);

      // Start QA session on locked level 50
      const targetLevelId = 50;
      qaSessionController.startSession(
        levelId: targetLevelId,
        currentProgress: progressRepo.state,
      );

      final level50 = _createLevel(targetLevelId);
      final controller = GameController(
        level: level50,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: progressRepo,
        snapshotRepo: snapshotRepo,
        streakRepo: streakRepo,
        isQaSession: true,
        qaSessionController: qaSessionController,
      );

      // Solve level 50 by tapping the only thread
      controller.handleThreadTap(1, 40.0);

      // Wait for completion stillness
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Game state should reach completed
      expect(controller.currentState.status, equals(GameStatus.completed));
      expect(controller.currentState.stars, equals(3));

      // 1. QA Session captured the completion in memory
      expect(
          qaSessionController.state.completedQaLevels, contains(targetLevelId));
      expect(qaSessionController.state.qaLevelStars[targetLevelId], equals(3));

      // 2. Real persistent progress MUST REMAIN COMPLETELY UNTOUCHED!
      expect(progressRepo.state.highestUnlocked, equals(1));
      expect(progressRepo.state.stars, isEmpty);
      expect(progressRepo.state.stats.levelsCleared, equals(0));
      expect(progressRepo.state.stats.totalStars, equals(0));

      // 3. Preceding levels (1..49) are NOT marked completed
      for (var i = 1; i < targetLevelId; i++) {
        expect(progressRepo.state.stars.containsKey(i), isFalse);
      }

      // 4. Streak was not modified
      expect(streakRepo.state.currentStreak, equals(0));

      // 5. Test level snapshot was not stored to corrupt normal resume
      expect(snapshotRepo.getSnapshot(), isNull);

      controller.dispose();
    });

    test('2. Restart reloads the selected level from clean initial state',
        () async {
      const targetLevelId = 25;
      final level = _createLevel(targetLevelId);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: progressRepo,
        snapshotRepo: snapshotRepo,
        isQaSession: true,
        qaSessionController: qaSessionController,
      );

      // Tap thread
      controller.handleThreadTap(1, 40.0);
      expect(controller.currentState.activeIds, isEmpty);

      // Restart puzzle
      controller.restartLevel(40.0);

      // All initial threads restored and game reset
      expect(controller.currentState.activeIds, contains(1));
      expect(controller.currentState.mistakes, equals(0));
      expect(controller.currentState.status, equals(GameStatus.playing));

      controller.dispose();
    });

    test('3. Exiting QA restores the exact normal gameplay context', () {
      // Setup initial player progress
      expect(progressRepo.state.highestUnlocked, equals(1));

      // Start QA session
      qaSessionController.startSession(
        levelId: 100,
        currentProgress: progressRepo.state,
      );
      expect(qaSessionController.state.isActive, isTrue);

      // Clear overrides / Exit QA
      qaSessionController.clearOverrides();

      // State is completely reset and normal player progression is preserved
      expect(qaSessionController.state.isActive, isFalse);
      expect(qaSessionController.state.activeLevelId, isNull);
      expect(progressRepo.state.highestUnlocked, equals(1));
    });

    test(
        '4. Regular non-QA gameplay correctly records progression and updates save state',
        () async {
      // Normal gameplay (isQaSession: false) on Level 1
      final level1 = _createLevel(1);
      final controller = GameController(
        level: level1,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: progressRepo,
        snapshotRepo: snapshotRepo,
        streakRepo: streakRepo,
        isQaSession: false,
      );

      controller.handleThreadTap(1, 40.0);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Normal progress should advance to level 2 and record 3 stars
      expect(progressRepo.state.highestUnlocked, equals(2));
      expect(progressRepo.state.stars[1], equals(3));
      expect(progressRepo.state.stats.levelsCleared, equals(1));

      controller.dispose();
    });
  });
}
