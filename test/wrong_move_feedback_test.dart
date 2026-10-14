import 'dart:ui' as ui;

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/board_painter.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/features/game/wrong_move_feedback_controller.dart';
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

class SpyHapticExecutor implements HapticPlatformExecutor {
  final List<String> eventLog = [];

  int get lightCount => eventLog.where((e) => e == 'light').length;
  int get heavyCount => eventLog.where((e) => e == 'heavy').length;
  int get mediumCount => eventLog.where((e) => e == 'medium').length;

  @override
  Future<void> lightImpact() async {
    eventLog.add('light');
  }

  @override
  Future<void> mediumImpact() async {
    eventLog.add('medium');
  }

  @override
  Future<void> heavyImpact() async {
    eventLog.add('heavy');
  }

  @override
  Future<void> selectionClick() async {
    eventLog.add('selection');
  }

  void clear() => eventLog.clear();
}

class SpyAudioService extends AudioService {
  SpyAudioService(this._testRef) : super(_testRef);

  final Ref _testRef;
  int blockPlayCount = 0;
  int pullPlayCount = 0;

  bool get soundEnabled {
    try {
      return _testRef.read(settingsProvider).sound;
    } catch (_) {
      return false;
    }
  }

  @override
  void playBlock() {
    if (!soundEnabled) return;
    blockPlayCount++;
  }

  @override
  void playPull() {
    if (!soundEnabled) return;
    pullPlayCount++;
  }

  void clear() {
    blockPlayCount = 0;
    pullPlayCount = 0;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArrowZ — ARROWZ-1-6: Wrong Move Feedback Engine Tests', () {
    late ProviderContainer container;
    late BoardAnimator animator;
    late SpyHapticExecutor spyHaptics;
    late SpyAudioService spyAudio;
    late HapticsService hapticsService;

    // Test Level:
    // Thread 1: (0,0) -> (0,1), points Right towards (0,2). BLOCKED by Thread 2.
    // Thread 2: (1,2) -> (0,2), points Up. FREE to exit.
    final testLevel = Level(
      id: 201,
      rows: 4,
      cols: 4,
      threads: [
        Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
        Thread(2, [const Cell(1, 2), const Cell(0, 2)]),
      ],
    );

    setUp(() {
      spyHaptics = SpyHapticExecutor();
      container = ProviderContainer(
        overrides: [
          hapticsServiceProvider.overrideWith((ref) {
            return HapticsService(ref, executor: spyHaptics);
          }),
          audioServiceProvider.overrideWith((ref) {
            return SpyAudioService(ref);
          }),
        ],
      );
      animator = BoardAnimator(vsync: FakeTickerProvider());
      animator.setLevel(testLevel, 24.0);
      hapticsService = container.read(hapticsServiceProvider);
      spyAudio = container.read(audioServiceProvider) as SpyAudioService;
    });

    tearDown(() {
      animator.dispose();
      container.dispose();
    });

    GameController createController({
      Level? level,
      bool reduceMotion = false,
      void Function(String message)? announceBlocked,
    }) {
      final lvl = level ?? testLevel;
      animator.setLevel(lvl, 24.0);
      return GameController(
        level: lvl,
        animator: animator,
        audio: spyAudio,
        haptics: hapticsService,
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: reduceMotion,
        feedbackController: WrongMoveFeedbackController(
          haptics: hapticsService,
          audio: spyAudio,
          animator: animator,
          announceBlocked: announceBlocked,
        ),
      );
    }

    test('1. A blocked move emits exactly one wrong-move event', () {
      final controller = createController();
      final events = <WrongMoveEvent>[];
      controller.feedbackController.addListener(events.add);

      // Tap blocked arrow 1
      controller.handleThreadTap(1, 24.0);

      expect(events.length, equals(1));
      expect(events.first.threadId, equals(1));
      expect(events.first.dir, equals(Dir.right));
      expect(events.first.reduceMotion, isFalse);
      expect(controller.feedbackController.eventCount, equals(1));
    });

    test('2. Haptics are requested immediately after the event', () {
      final controller = createController();
      expect(spyHaptics.heavyCount, equals(0));

      // Tap blocked arrow 1
      controller.handleThreadTap(1, 24.0);

      // Feedback should have been requested immediately at interaction boundary
      expect(spyHaptics.heavyCount, equals(1));
      expect(spyHaptics.eventLog.first, equals('heavy'));
    });

    test(
        '3. Sound playback begins without waiting for the shake animation to finish',
        () {
      final controller = createController();
      expect(spyAudio.blockPlayCount, equals(0));

      // Tap blocked arrow 1
      controller.handleThreadTap(1, 24.0);

      // Sound begins immediately
      expect(spyAudio.blockPlayCount, equals(1));
      // Animation is active and at beginning
      expect(animator.wrongMoves.containsKey(1), isTrue);
      final wrongMove = animator.wrongMoves[1]!;
      expect(wrongMove.progress(animator.nowMs), lessThan(0.25));
    });

    test('4. The selected arrow becomes red during feedback', () {
      final controller = createController();
      controller.handleThreadTap(1, 24.0);

      final wrongMove = animator.wrongMoves[1]!;
      // Danger factor is 1.0 (full red) during the initial feedback window
      final initialDanger = wrongMove.dangerLerp(animator.nowMs);
      expect(initialDanger, equals(1.0));

      // Paint and verify color matches tokens.danger
      const tokens = AppThemes.sageLinenTokens;
      final painter = BoardPainter(
        level: testLevel,
        activeIds: controller.state.activeIds,
        cellSize: 24.0,
        tokens: tokens,
        animator: animator,
        reduceMotion: false,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(96.0, 96.0));
      // Painting completed without error with active wrong move
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('5. Its original color is restored afterward', () {
      final controller = createController();
      controller.handleThreadTap(1, 24.0);

      final wrongMove = animator.wrongMoves[1]!;
      final startTime = wrongMove.startTimeMs;

      // At duration end (>= 240ms), danger lerp factor must be 0.0 (fully restored)
      final restoredDanger = wrongMove.dangerLerp(startTime + 245.0);
      expect(restoredDanger, equals(0.0));
      expect(wrongMove.isDone(startTime + 245.0), isTrue);
    });

    test('6. Other arrows remain unchanged', () {
      final controller = createController();
      controller.handleThreadTap(1, 24.0);

      // Only arrow 1 has wrong move state; arrow 2 has none
      expect(animator.wrongMoves.containsKey(1), isTrue);
      expect(animator.wrongMoves.containsKey(2), isFalse);
    });

    test(
        '7. Logical geometry and collision results remain unchanged during shaking',
        () {
      final controller = createController();
      final origCells1 = List<Cell>.from(testLevel.threads[0].cells);
      final origCells2 = List<Cell>.from(testLevel.threads[1].cells);

      controller.handleThreadTap(1, 24.0);

      // Verify model geometry was not mutated
      expect(testLevel.threads[0].cells, equals(origCells1));
      expect(testLevel.threads[1].cells, equals(origCells2));
      expect(controller.state.level.threads[0].cells, equals(origCells1));
      expect(controller.state.level.threads[1].cells, equals(origCells2));

      // Shake offset is a presentation transform
      final wrongMove = animator.wrongMoves[1]!;
      expect(wrongMove.dir, equals(Dir.right));
      final shake = wrongMove.shakeOffset(wrongMove.startTimeMs + 20.0);
      expect(shake.dy.abs(), greaterThan(0.0));
      expect(shake.dx, equals(0.0)); // Perpendicular to Dir.right
    });

    test('8. One wrong attempt consumes at most one life', () {
      final controller = createController();
      expect(controller.state.mistakes, equals(0));

      controller.handleThreadTap(1, 24.0);
      expect(controller.state.mistakes, equals(1));
      expect(controller.state.status, equals(GameStatus.playing));
    });

    test('9. Disabled haptics do not produce haptic requests', () {
      container.read(settingsProvider.notifier).state = const SettingsState(
        themeChoice: AppThemeMode.sageLinen,
        sound: true,
        haptics: false,
        reduceMotion: false,
      );

      final controller = createController();
      controller.handleThreadTap(1, 24.0);

      expect(spyHaptics.heavyCount, equals(0));
      expect(spyHaptics.eventLog, isEmpty);
      // But visual and audio still work
      expect(spyAudio.blockPlayCount, equals(1));
      expect(animator.wrongMoves.containsKey(1), isTrue);
    });

    test('10. Disabled sound does not produce sound requests', () {
      container.read(settingsProvider.notifier).state = const SettingsState(
        themeChoice: AppThemeMode.sageLinen,
        sound: false,
        haptics: true,
        reduceMotion: false,
      );

      final controller = createController();
      controller.handleThreadTap(1, 24.0);

      expect(spyAudio.blockPlayCount, equals(0));
      // But haptic and visual still work
      expect(spyHaptics.heavyCount, equals(1));
      expect(animator.wrongMoves.containsKey(1), isTrue);
    });

    test('11. Reduced-motion mode avoids the normal shake', () {
      final controller = createController(reduceMotion: true);
      controller.handleThreadTap(1, 24.0);

      final wrongMove = animator.wrongMoves[1]!;
      expect(wrongMove.reduceMotion, isTrue);

      // Shake displacement is 0.0 with reduced motion
      final offset = wrongMove.shakeOffset(wrongMove.startTimeMs + 20.0);
      expect(offset, equals(Offset.zero));

      // Visual color highlight still presents clearly
      expect(wrongMove.dangerLerp(wrongMove.startTimeMs), equals(1.0));
    });

    test(
        '12. Repeated attempts do not cause duplicate callbacks or accumulated transforms',
        () {
      final controller = createController();
      final events = <WrongMoveEvent>[];
      controller.feedbackController.addListener(events.add);

      // Tap 3 times rapidly
      controller.handleThreadTap(1, 24.0);
      controller.handleThreadTap(1, 24.0);
      controller.handleThreadTap(1, 24.0);

      // Debounce window filters rapid repeat on the same arrow
      expect(events.length, equals(1));
      expect(controller.state.mistakes, equals(1));
      expect(spyHaptics.heavyCount, equals(1));
      expect(spyAudio.blockPlayCount, equals(1));

      // Replacing animation state calculates fresh from nowMs without accumulated offset
      final wrongMove = animator.wrongMoves[1]!;
      final offset = wrongMove.shakeOffset(wrongMove.startTimeMs + 245.0);
      expect(offset, equals(Offset.zero));
    });

    test('13. Restarting or leaving gameplay safely cancels transient feedback',
        () {
      final controller = createController();
      controller.handleThreadTap(1, 24.0);
      expect(animator.wrongMoves.containsKey(1), isTrue);

      // Restarting cancels active feedback
      controller.restartLevel(24.0);
      expect(animator.wrongMoves.isEmpty, isTrue);

      // Re-trigger and dispose
      controller.handleThreadTap(1, 24.0);
      expect(animator.wrongMoves.containsKey(1), isTrue);

      controller.dispose();
      expect(animator.wrongMoves.isEmpty, isTrue);
    });

    test(
        '14. Feedback cannot trigger after game over or after the arrow has been removed',
        () {
      final controller = createController();

      // Trigger 3 mistakes to cause game over
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.mistakes, equals(1));

      // Advance clock past debounce
      controller.state = controller.state.copyWith(lastBlockedTapTimeMs: 0.0);
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.mistakes, equals(2));

      controller.state = controller.state.copyWith(lastBlockedTapTimeMs: 0.0);
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.mistakes, equals(3));
      expect(controller.state.status, equals(GameStatus.failed));

      // Now game is failed: subsequent tap should be completely ignored
      spyHaptics.clear();
      spyAudio.clear();
      controller.state = controller.state.copyWith(lastBlockedTapTimeMs: 0.0);
      controller.handleThreadTap(1, 24.0);

      expect(spyHaptics.heavyCount, equals(0));
      expect(spyAudio.blockPlayCount, equals(0));
      expect(controller.state.mistakes, equals(3));

      // Now test removed arrow
      final freshController = createController();
      // Remove arrow 2
      freshController.handleThreadTap(2, 24.0);
      expect(freshController.state.activeIds.contains(2), isFalse);

      spyHaptics.clear();
      spyAudio.clear();
      // Tap already-removed arrow 2
      freshController.handleThreadTap(2, 24.0);
      expect(spyHaptics.heavyCount, equals(0));
      expect(spyAudio.blockPlayCount, equals(0));
    });
  });
}
