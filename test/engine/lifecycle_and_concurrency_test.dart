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

Future<void> advanceTime(
  WidgetTester tester,
  BoardAnimator animator,
  Duration duration,
) async {
  animator.stepTimeMs(duration.inMilliseconds.toDouble());
  await tester.pump(duration);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lifecycle, Concurrency & Completion Synchronization Suite', () {
    late ProviderContainer container;
    late BoardAnimator animator;

    setUp(() {
      container = ProviderContainer();
      animator = BoardAnimator(vsync: FakeTickerProvider());
      animator.setTestClockMs(1000.0);
    });

    tearDown(() {
      animator.dispose();
      container.dispose();
    });

    testWidgets(
        'Long exit animation: level does not complete prematurely at 350ms, waits for full exit',
        (tester) async {
      // Level with an arrow that has a long exit run (takes >500ms)
      final level = Level(
        id: 991,
        rows: 12,
        cols: 12,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
        ],
      );

      animator.setLevel(level, 30.0);

      final controller = GameController(
        level: level,
        animator: animator,
        audio: FakeAudio(),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      // Tap thread 1 to start exit
      controller.handleThreadTap(1, 30.0);

      expect(animator.hasActiveExits, isTrue);
      final exitDuration = animator.exits[1]!.durationMs;
      expect(exitDuration, greaterThan(350.0));

      // Advance 350ms: exit must still be in flight, and game must NOT be completed yet
      await advanceTime(tester, animator, const Duration(milliseconds: 350));
      expect(animator.hasActiveExits, isTrue,
          reason: 'Arrow should still be exiting across long exit path');
      expect(controller.currentState.status, equals(GameStatus.playing),
          reason:
              'Level completion must not trigger before arrow finishes exit');

      // Advance until the exit duration finishes + 200ms stillness delay
      final remainingMs = (exitDuration - 350.0).ceil() + 10;
      await advanceTime(tester, animator, Duration(milliseconds: remainingMs));
      await advanceTime(tester, animator, const Duration(milliseconds: 250));

      expect(animator.hasActiveExits, isFalse);
      expect(controller.currentState.status, equals(GameStatus.completed));

      controller.dispose();
    });

    testWidgets(
        'Screen resize during active exit preserves normalized progress and does not drop arrow',
        (tester) async {
      final level = Level(
        id: 992,
        rows: 8,
        cols: 8,
        threads: [
          Thread(1, [const Cell(1, 1), const Cell(1, 2), const Cell(1, 3)]),
        ],
      );

      animator.setLevel(level, 25.0);

      final controller = GameController(
        level: level,
        animator: animator,
        audio: FakeAudio(),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      controller.handleThreadTap(1, 25.0);
      expect(animator.exits.containsKey(1), isTrue);

      // Advance halfway
      await advanceTime(tester, animator, const Duration(milliseconds: 150));
      final progressBeforeResize = animator.exits[1]!.progress(animator.nowMs);
      expect(progressBeforeResize, greaterThan(0.0));
      expect(progressBeforeResize, lessThan(1.0));

      // Screen resize occurs: cell size scales from 25.0 to 40.0
      animator.updateCellSize(40.0);

      expect(animator.exits.containsKey(1), isTrue,
          reason: 'Active exit must be preserved across resize');
      expect(animator.geometries[1]!.cellSize, equals(40.0));

      final progressAfterResize = animator.exits[1]!.progress(animator.nowMs);
      expect(progressAfterResize, closeTo(progressBeforeResize, 0.05),
          reason: 'Animation progress should remain continuous across resize');

      // Finish animation
      await advanceTime(tester, animator, const Duration(milliseconds: 800));
      await advanceTime(tester, animator, const Duration(milliseconds: 250));

      expect(animator.hasActiveExits, isFalse);
      expect(controller.currentState.status, equals(GameStatus.completed));

      controller.dispose();
    });

    testWidgets(
        'Concurrent exits track individual identities and trigger completion exactly once',
        (tester) async {
      final level = Level(
        id: 993,
        rows: 6,
        cols: 6,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(2, 0), const Cell(2, 1)]),
          Thread(3, [const Cell(4, 0), const Cell(4, 1)]),
        ],
      );

      animator.setLevel(level, 20.0);

      final controller = GameController(
        level: level,
        animator: animator,
        audio: FakeAudio(),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      var completionsCount = 0;
      final completedIds = <int>[];
      animator.onExitCompleted = (id) => completedIds.add(id);

      controller.addListener((st) {
        if (st.status == GameStatus.completed) {
          completionsCount++;
        }
      });

      // Tap all 3 threads rapidly
      controller.handleThreadTap(1, 20.0);
      controller.handleThreadTap(2, 20.0);
      controller.handleThreadTap(3, 20.0);

      expect(animator.exits.length, equals(3));
      expect(controller.currentState.activeIds.isEmpty, isTrue);

      // Run until all exits settle
      await advanceTime(tester, animator, const Duration(milliseconds: 300));
      await advanceTime(tester, animator, const Duration(milliseconds: 600));
      await advanceTime(tester, animator, const Duration(milliseconds: 300));

      expect(completedIds.toSet(), equals({1, 2, 3}),
          reason: 'Every thread must report its individual exit completion');
      expect(completionsCount, equals(1),
          reason: 'Level completion should fire exactly once for the batch');

      controller.dispose();
    });

    testWidgets(
        'Restart during active exit animation cancels pending completion callbacks',
        (tester) async {
      final level = Level(
        id: 994,
        rows: 5,
        cols: 5,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
        ],
      );

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

      // Mid-exit restart
      await advanceTime(tester, animator, const Duration(milliseconds: 100));
      controller.restartLevel(20.0);

      expect(animator.exits.isEmpty, isTrue);
      expect(animator.hasActiveExits, isFalse);
      expect(controller.currentState.activeIds.contains(1), isTrue);
      expect(controller.currentState.status, equals(GameStatus.playing));

      // Advance past entrance animation and past cancelled exit time
      await advanceTime(tester, animator, const Duration(milliseconds: 1000));
      expect(animator.hasActiveAnimations, isFalse,
          reason: 'All animations including entrance settle to rest');
      expect(controller.currentState.status, equals(GameStatus.playing),
          reason:
              'Cancelled completion timer must never mark restarted level completed');

      controller.dispose();
    });
  });
}
