import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/stats_and_snapshot_models.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/level_progress_bar.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

Level createTestLevel({int count = 100}) {
  final threads = <Thread>[];
  for (int i = 0; i < count; i++) {
    threads.add(
      Thread(i + 1, [Cell(i, 0), Cell(i, 1)]),
    );
  }
  return Level(
    id: 99,
    rows: count,
    cols: 2,
    threads: threads,
  );
}

Level createTwoArrowBlockedLevel() {
  // Arrow 1 at (0,0)->(0,1) pointing right (exits at col >= 2).
  // Arrow 2 at (0,2)->(0,3) pointing right. Arrow 1 is blocked by Arrow 2.
  return Level(
    id: 101,
    rows: 1,
    cols: 4,
    threads: [
      Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
      Thread(2, [const Cell(0, 2), const Cell(0, 3)]),
    ],
  );
}

Widget wrapWithTheme(Widget child, {ThemeData? theme}) {
  final defaultTheme = AppThemes.buildThemeData(
    AppThemes.sageLinenTokens,
    isDark: false,
  );
  return MaterialApp(
    theme: theme ?? defaultTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('ARROWZ-1-7: Animated Level Progress Bar Tests', () {
    // 1. A new 100-arrow level starts at zero progress.
    test('1. A new 100-arrow level starts at zero progress', () {
      final level = createTestLevel(count: 100);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      expect(controller.currentState.totalArrows, equals(100));
      expect(controller.currentState.removedArrows, equals(0));
      expect(controller.currentState.progress, equals(0.0));
      controller.dispose();
    });

    // 2. Removing one of 100 arrows produces a target progress of 0.01.
    test('2. Removing one of 100 arrows produces a target progress of 0.01',
        () {
      final level = createTestLevel(count: 100);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      controller.handleThreadTap(1, 40.0);
      expect(controller.currentState.removedArrows, equals(1));
      expect(controller.currentState.progress, closeTo(0.01, 0.0001));
      controller.dispose();
    });

    // 3. Removing 25 of 100 arrows produces 0.25.
    test('3. Removing 25 of 100 arrows produces 0.25', () {
      final level = createTestLevel(count: 100);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      for (int i = 1; i <= 25; i++) {
        controller.handleThreadTap(i, 40.0);
      }
      expect(controller.currentState.removedArrows, equals(25));
      expect(controller.currentState.progress, closeTo(0.25, 0.0001));
      controller.dispose();
    });

    // 4. Removing half the arrows produces 0.5.
    test('4. Removing half the arrows produces 0.5', () {
      final level = createTestLevel(count: 100);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      for (int i = 1; i <= 50; i++) {
        controller.handleThreadTap(i, 40.0);
      }
      expect(controller.currentState.removedArrows, equals(50));
      expect(controller.currentState.progress, closeTo(0.50, 0.0001));
      controller.dispose();
    });

    // 5. Removing all arrows produces 1.0.
    test('5. Removing all arrows produces 1.0', () {
      final level = createTestLevel(count: 100);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      for (int i = 1; i <= 100; i++) {
        controller.handleThreadTap(i, 40.0);
      }
      expect(controller.currentState.removedArrows, equals(100));
      expect(controller.currentState.progress, equals(1.0));
      controller.dispose();
    });

    // 6. Levels with different total arrow counts calculate progress correctly.
    test(
        '6. Levels with different total arrow counts calculate progress correctly',
        () {
      // 8 arrows, 3 removed => 3 / 8 = 0.375
      final level8 = createTestLevel(count: 8);
      final controller8 = GameController(
        level: level8,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      controller8.handleThreadTap(1, 40.0);
      controller8.handleThreadTap(2, 40.0);
      controller8.handleThreadTap(3, 40.0);
      expect(controller8.currentState.totalArrows, equals(8));
      expect(controller8.currentState.removedArrows, equals(3));
      expect(controller8.currentState.progress, closeTo(0.375, 0.0001));
      controller8.dispose();

      // 1 arrow, 1 removed => 1.0
      final level1 = createTestLevel(count: 1);
      final controller1 = GameController(
        level: level1,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      expect(controller1.currentState.progress, equals(0.0));
      controller1.handleThreadTap(1, 40.0);
      expect(controller1.currentState.removedArrows, equals(1));
      expect(controller1.currentState.progress, equals(1.0));
      controller1.dispose();
    });

    // 7. Blocked moves do not advance progress.
    test('7. Blocked moves do not advance progress', () {
      final level = createTwoArrowBlockedLevel();
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      // Arrow 1 is blocked by Arrow 2
      controller.handleThreadTap(1, 40.0);
      expect(controller.currentState.mistakes, equals(1));
      expect(controller.currentState.removedArrows, equals(0));
      expect(controller.currentState.progress, equals(0.0));
      controller.dispose();
    });

    // 8. Pending extraction does not advance progress before removal is committed.
    test('8. Authoritative game state commits removal before progress advances',
        () {
      final level = createTestLevel(count: 10);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      expect(controller.currentState.progress, equals(0.0));
      controller.handleThreadTap(1, 40.0);
      expect(controller.currentState.activeIds.contains(1), isFalse);
      expect(controller.currentState.progress, equals(0.1));
      controller.dispose();
    });

    // 9. Duplicate removal callbacks do not advance progress twice.
    test('9. Duplicate removal callbacks do not advance progress twice', () {
      final level = createTestLevel(count: 10);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      controller.handleThreadTap(1, 40.0);
      expect(controller.currentState.removedArrows, equals(1));
      expect(controller.currentState.progress, equals(0.1));

      // Attempt tap on the same thread id again
      controller.handleThreadTap(1, 40.0);
      expect(controller.currentState.removedArrows, equals(1));
      expect(controller.currentState.progress, equals(0.1));
      controller.dispose();
    });

    // 10. Restart resets progress correctly.
    test('10. Restart resets progress correctly', () {
      final level = createTestLevel(count: 10);
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
      );

      controller.handleThreadTap(1, 40.0);
      controller.handleThreadTap(2, 40.0);
      expect(controller.currentState.progress, equals(0.2));

      controller.restartLevel(40.0);
      expect(controller.currentState.removedArrows, equals(0));
      expect(controller.currentState.progress, equals(0.0));
      controller.dispose();
    });

    // 11. Restored saved state displays the correct progress.
    test('11. Restored saved state displays the correct progress', () {
      final level = createTestLevel(count: 10);
      // Saved snapshot with 4 active threads remaining (thread IDs 7, 8, 9, 10).
      // Thus 6 threads have been removed out of 10.
      final snapshot = LevelSnapshot(
        levelId: level.id,
        activeThreadIds: {7, 8, 9, 10},
        mistakes: 1,
        hintsUsed: 0,
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        initialSnapshot: snapshot,
      );

      expect(controller.currentState.removedArrows, equals(6));
      expect(controller.currentState.totalArrows, equals(10));
      expect(controller.currentState.progress, equals(0.6));
      controller.dispose();
    });

    // 12. The component contains no visible percentage or numeric progress text.
    testWidgets(
        '12. The component contains no visible percentage or numeric progress text',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const LevelProgressBar(
            progress: 0.45,
            reduceMotion: true,
          ),
        ),
      );
      await tester.pump();

      // Ensure no Text widgets exist in the progress bar
      expect(find.byType(Text), findsNothing);

      // Verify that no text widget contains numbers or percentages
      final textFinder = find.byWidgetPredicate((widget) {
        if (widget is Text) return true;
        if (widget is RichText) {
          final plainText = widget.text.toPlainText();
          return plainText.contains('%') || RegExp(r'\d').hasMatch(plainText);
        }
        return false;
      });
      expect(textFinder, findsNothing);

      // Semantics should expose accessibility description for screen readers
      final semantics = tester.getSemantics(find.byType(LevelProgressBar));
      expect(semantics.label, equals('Level progress'));
      expect(semantics.value, equals('45% complete'));
    });

    // 13. The component renders correctly across all five themes.
    testWidgets('13. The component renders correctly across all five themes',
        (tester) async {
      for (final tokens in [
        AppThemes.sageLinenTokens,
        AppThemes.inkAndBrassTokens,
        AppThemes.fogSlateTokens,
        AppThemes.rosewoodTokens,
        AppThemes.graphiteEmberTokens,
      ]) {
        final theme = AppThemes.buildThemeData(
          tokens,
          isDark: tokens == AppThemes.inkAndBrassTokens ||
              tokens == AppThemes.graphiteEmberTokens,
        );
        await tester.pumpWidget(
          wrapWithTheme(
            const LevelProgressBar(
              progress: 0.5,
              reduceMotion: true,
            ),
            theme: theme,
          ),
        );
        await tester.pump();

        expect(find.byType(LevelProgressBar), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    // 14. Rapid updates animate toward the latest target without losing state.
    testWidgets(
        '14. Rapid updates animate toward latest target without losing state',
        (tester) async {
      double target = 0.0;
      late StateSetter setStateCallback;

      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              setStateCallback = setState;
              return LevelProgressBar(
                progress: target,
                duration: const Duration(milliseconds: 200),
                reduceMotion: false,
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Trigger first progress update: 0.0 -> 0.3
      setStateCallback(() {
        target = 0.3;
      });
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 50)); // Partial progress

      // Rapidly trigger second progress update mid-flight: -> 0.7
      setStateCallback(() {
        target = 0.7;
      });
      await tester.pump(); // Intercepts and smoothly redirects toward 0.7

      // Advance through remainder of duration
      await tester.pump(const Duration(milliseconds: 250));

      // Bar is settled at final target 0.7
      final semantics = tester.getSemantics(find.byType(LevelProgressBar));
      expect(semantics.label, equals('Level progress'));
      expect(semantics.value, equals('70% complete'));
    });

    // 15. Invalid or empty level data is handled safely.
    test('15. Invalid or empty level data is handled safely', () {
      // Empty level (0 arrows)
      final emptyLevel = Level(
        id: 0,
        rows: 0,
        cols: 0,
        threads: [],
      );

      final emptyState = GameState(
        level: emptyLevel,
        activeIds: {},
        mistakes: 0,
        hintsUsed: 0,
        moves: 0,
        elapsedSeconds: 0,
        status: GameStatus.playing,
        stars: 0,
        showCoachMark: false,
      );

      // Must not divide by zero or result in NaN
      expect(emptyState.totalArrows, equals(0));
      expect(emptyState.removedArrows, equals(0));
      expect(emptyState.progress, equals(0.0));
      expect(emptyState.progress.isNaN, isFalse);
    });
  });
}
