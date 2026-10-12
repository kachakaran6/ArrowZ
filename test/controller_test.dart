import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
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

class FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameController Logic', () {
    late ProviderContainer container;
    late BoardAnimator animator;

    setUp(() {
      container = ProviderContainer();
      animator = BoardAnimator(vsync: FakeTickerProvider());
    });

    tearDown(() {
      animator.dispose();
      container.dispose();
    });

    test('free thread tap removes thread and updates state', () {
      final level = Level(
        id: 1,
        rows: 4,
        cols: 4,
        threads: [
          Thread(1, [const Cell(1, 1), const Cell(1, 2)]),
          Thread(2, [const Cell(2, 1), const Cell(2, 2)]),
        ],
      );

      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );

      expect(controller.state.activeIds.length, equals(2));

      // Tap free thread 1
      controller.handleThreadTap(1, 24.0);

      expect(controller.state.activeIds.contains(1), isFalse);
      expect(controller.state.moves, equals(1));
      expect(controller.state.mistakes, equals(0));
    });

    test('blocked tap records mistake and debounces rapid taps', () {
      final level = Level(
        id: 10, // Non-tutorial level
        rows: 4,
        cols: 4,
        threads: [
          Thread(1,
              [const Cell(0, 0), const Cell(0, 1)]), // points right into (0,2)
          Thread(2, [
            const Cell(1, 2),
            const Cell(0, 2)
          ]), // occupies (0,2), points up
        ],
      );

      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );

      // Tap blocked thread 1
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.mistakes, equals(1));

      // Immediate second tap within 250ms on same blocked thread should not add second mistake
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.mistakes, equals(1));
    });

    test('three mistakes trigger failed status on non-tutorial level', () {
      final level = Level(
        id: 20,
        rows: 4,
        cols: 4,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(1, 2), const Cell(0, 2)]),
        ],
      );

      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );

      controller.handleThreadTap(1, 24.0); // mistake 1
      // Simulate subsequent non-debounced mistakes
      controller.state = controller.state.copyWith(lastBlockedTapTimeMs: 0.0);
      controller.handleThreadTap(1, 24.0); // mistake 2

      controller.state = controller.state.copyWith(lastBlockedTapTimeMs: 0.0);
      controller.handleThreadTap(1, 24.0); // mistake 3

      expect(controller.state.mistakes, equals(3));
      expect(controller.state.status, equals(GameStatus.failed));
    });

    test('mistakes are tracked on all levels', () {
      final level = Level(
        id: 2,
        rows: 4,
        cols: 4,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(1, 2), const Cell(0, 2)]),
        ],
      );

      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );

      controller.handleThreadTap(1, 24.0);
      expect(controller.state.mistakes, equals(1));
      expect(controller.state.remainingMistakes, equals(2));
    });

    test('star calculation awards correct stars based on mistakes', () {
      expect(GameState.calculateStars(0), equals(3));
      expect(GameState.calculateStars(1), equals(2));
      expect(GameState.calculateStars(2), equals(2));
      expect(GameState.calculateStars(3), equals(1));
    });
  });
}
