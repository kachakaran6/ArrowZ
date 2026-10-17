import 'dart:async';
import 'dart:math' as math;

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/stats_and_snapshot_models.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/features/game/wrong_move_feedback_controller.dart';
import 'package:arrowtapout/features/qa/qa_session.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameController extends StateNotifier<GameState> {
  GameController({
    required Level level,
    required this.animator,
    required this.audio,
    required this.haptics,
    required this.progress,
    required this.snapshotRepo,
    this.streakRepo,
    this.notificationService,
    this.reduceMotion = false,
    this.isQaSession = false,
    this.qaSessionController,
    WrongMoveFeedbackController? feedbackController,
    LevelSnapshot? initialSnapshot,
    bool coachMarkShown = false,
  })  : feedbackController = feedbackController ??
            WrongMoveFeedbackController(
              haptics: haptics,
              audio: audio,
              animator: animator,
            ),
        _boardState = BoardState(level),
        super(_initState(level, initialSnapshot, coachMarkShown)) {
    if (initialSnapshot != null) {
      // Resume from snapshot: remove already cleared threads
      for (final t in level.threads) {
        if (!initialSnapshot.activeThreadIds.contains(t.id)) {
          _boardState.remove(t.id);
        }
      }
    }
  }

  final BoardState _boardState;
  final BoardAnimator animator;
  final AudioService audio;
  final HapticsService haptics;
  final WrongMoveFeedbackController feedbackController;
  final ProgressRepository progress;
  final SnapshotRepository snapshotRepo;
  final StreakRepository? streakRepo;
  final NotificationService? notificationService;
  final bool reduceMotion;
  final bool isQaSession;
  final QaSessionController? qaSessionController;

  Timer? _completeTimer;
  Timer? _snapshotDebounceTimer;

  late final ValueNotifier<GameState> gameStateNotifier =
      ValueNotifier<GameState>(state);

  @override
  set state(GameState value) {
    super.state = value;
    if (mounted) {
      gameStateNotifier.value = value;
    }
  }

  GameState get currentState => state;

  static GameState _initState(
    Level level,
    LevelSnapshot? snapshot,
    bool coachMarkShown,
  ) {
    final active = snapshot != null
        ? Set<int>.of(snapshot.activeThreadIds)
        : {for (final t in level.threads) t.id};

    final showCoach = level.id == 1 && !coachMarkShown;

    return GameState(
      level: level,
      activeIds: active,
      mistakes: snapshot?.mistakes ?? 0,
      hintsUsed: snapshot?.hintsUsed ?? 0,
      moves: 0,
      elapsedSeconds: 0,
      status: GameStatus.playing,
      stars: 0,
      showCoachMark: showCoach,
    );
  }

  bool get _reduceMotion => reduceMotion;

  /// Handles tap on a thread with [threadId].
  void handleThreadTap(int threadId, double cellSize) {
    if (state.status != GameStatus.playing) return;
    if (animator.exits.containsKey(threadId)) return; // Already exiting
    if (!state.activeIds.contains(threadId)) return;

    if (state.showCoachMark) {
      dismissCoachMark();
    }

    final canExit = _boardState.canExit(threadId);

    if (canExit) {
      // 1. Immediate tactile feedback at the interaction boundary.
      // Must not wait for exit animations, audio, or snapshot writes.
      haptics.light();

      // 2. Sound effect.
      audio.playPull();

      // 3. Update board state & begin path-aware extraction.
      _boardState.remove(threadId);
      animator.triggerExit(threadId, reduceMotion: _reduceMotion);

      final newActive = Set<int>.of(state.activeIds)..remove(threadId);
      state = state.copyWith(
        activeIds: newActive,
        moves: state.moves + 1,
      );

      _saveSnapshotDebounced();

      if (newActive.isEmpty) {
        _handleLevelCompleted();
      }
    } else {
      // Blocked thread tap: must NEVER be debounced or ignored!
      final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
      final thread = state.level.threads.firstWhere((t) => t.id == threadId);

      // Coordinate wrong move feedback (immediate sound, haptics, shake, red highlight, semantics)
      feedbackController.handleWrongMove(
        threadId: threadId,
        dir: thread.dir,
        reduceMotion: _reduceMotion,
      );

      final blocker = _boardState.firstBlocker(threadId);
      if (blocker != null) {
        animator.triggerBlocked(
          threadId: threadId,
          blocker: blocker,
          cellSize: cellSize,
          reduceMotion: _reduceMotion,
        );
      }

      // Spec 03: Consecutive taps on the same blocked thread within 600 ms count as one mistake
      final isMistakeDebounced = state.lastBlockedThreadId == threadId &&
          (nowMs - state.lastBlockedTapTimeMs) < 600.0;

      final newMistakes =
          isMistakeDebounced ? state.mistakes : state.mistakes + 1;
      final isFailed = newMistakes >= 3;

      state = state.copyWith(
        mistakes: newMistakes,
        status: isFailed ? GameStatus.failed : GameStatus.playing,
        lastBlockedTapTimeMs: nowMs,
        lastBlockedThreadId: threadId,
      );

      if (isFailed) {
        _snapshotDebounceTimer?.cancel();
        snapshotRepo.clearSnapshot();
      } else {
        _saveSnapshotDebounced();
      }
    }
  }

  void _handleLevelCompleted() {
    _snapshotDebounceTimer?.cancel();
    _completeTimer?.cancel();

    void completeNow() {
      if (!mounted || state.status != GameStatus.playing) return;
      animator.onAllExitsCompleted = null;
      final stars = GameState.calculateStars(state.mistakes);
      state = state.copyWith(
        status: GameStatus.completed,
        stars: stars,
      );

      audio.playComplete();
      haptics.success();
      snapshotRepo.clearSnapshot();

      if (isQaSession) {
        qaSessionController?.recordQaLevelCompleted(
          levelId: state.level.id,
          stars: stars,
        );
      } else {
        progress.recordLevelCompleted(
          levelId: state.level.id,
          starsEarned: stars,
          threadsCleared: state.level.threads.length,
          mistakes: state.mistakes,
        );

        streakRepo?.recordQualifyingPlay(null, notificationService);
      }
    }

    void scheduleStillnessCompletion() {
      if (!mounted || state.status != GameStatus.playing) return;
      _completeTimer?.cancel();
      // 200 ms natural stillness after the last arrow exits the board
      _completeTimer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted || state.status != GameStatus.playing) return;
        completeNow();
      });
    }

    if (!animator.hasActiveExits) {
      scheduleStillnessCompletion();
    } else {
      animator.onAllExitsCompleted = () {
        scheduleStillnessCompletion();
      };
      // Defensive fallback timer proportional to the maximum active exit path length
      // ensuring headless tests and stalled tickers recover safely
      final maxExitMs = animator.exits.values.fold<double>(
        0.0,
        (maxVal, e) => math.max(maxVal, e.durationMs),
      );
      final fallbackDelayMs = math.max(maxExitMs + 50.0, 390.0).ceil();
      _completeTimer = Timer(Duration(milliseconds: fallbackDelayMs), () {
        if (!mounted || state.status != GameStatus.playing) return;
        Diagnostics.instance.reportStuckAnimation(
          threadId: 0,
          state: 'completion_fallback',
          ageMs: fallbackDelayMs.toDouble(),
          maxAllowedMs: fallbackDelayMs.toDouble(),
        );
        animator.finalizeAllRunningAnimations();
        completeNow();
      });
    }
  }

  /// Returns the ID of an optimal unobstructed thread that can currently exit, or null.
  int? chooseHintThread() {
    if (state.status != GameStatus.playing) return null;
    return _boardState.chooseHintThread();
  }

  /// Grants a rewarded hint by triggering a 2-second highlight on [hintId] without
  /// removing the thread, consuming a heart life, or recording a mistake.
  bool grantRewardedHint(int hintId) {
    if (!mounted || state.status != GameStatus.playing) return false;
    if (!state.activeIds.contains(hintId)) return false;
    if (!_boardState.canExit(hintId)) return false;

    animator.triggerHint(hintId);
    state = state.copyWith(
      hintsUsed: state.hintsUsed + 1,
      hintedThreadId: hintId,
    );
    return true;
  }

  /// Legacy helper for consuming from bank, preserved for compatibility.
  Future<void> useHint() async {
    if (!mounted || state.status != GameStatus.playing) return;
    if (state.hintsUsed >= 3) return;

    final hintId = _boardState.chooseHintThread();
    if (hintId == null) return;

    final consumed = await progress.consumeHint();
    if (!consumed) return;

    grantRewardedHint(hintId);
  }

  void dismissCoachMark() {
    progress.setCoachMarkShown();
    state = state.copyWith(showCoachMark: false);
  }

  /// Restarts current level from clean state.
  void restartLevel(double cellSize) {
    _snapshotDebounceTimer?.cancel();
    _completeTimer?.cancel();
    animator.onAllExitsCompleted = null;
    animator.onExitCompleted = null;
    feedbackController.cancel();
    animator.finalizeAllRunningAnimations();
    final allIds = {for (final t in state.level.threads) t.id};

    _boardState.active.clear();
    _boardState.active.addAll(allIds);
    _boardState.occupancy.clear();
    for (final t in state.level.threads) {
      for (final c in t.cells) {
        _boardState.occupancy[c] = t.id;
      }
    }

    animator.setLevel(state.level, cellSize);
    animator.startEntrance(state.level.threads.length,
        reduceMotion: _reduceMotion);

    snapshotRepo.clearSnapshot();

    state = state.copyWith(
      activeIds: allIds,
      mistakes: 0,
      hintsUsed: 0,
      moves: 0,
      status: GameStatus.playing,
      stars: 0,
      hintedThreadId: null,
      lastBlockedTapTimeMs: 0.0,
      lastBlockedThreadId: null,
    );
  }

  void _saveSnapshotDebounced() {
    if (isQaSession) return;
    _snapshotDebounceTimer?.cancel();
    _snapshotDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || state.status != GameStatus.playing) return;
      snapshotRepo.saveSnapshot(
        levelId: state.level.id,
        activeThreadIds: state.activeIds,
        mistakes: state.mistakes,
        hintsUsed: state.hintsUsed,
      );
    });
  }

  @override
  void dispose() {
    _snapshotDebounceTimer?.cancel();
    _completeTimer?.cancel();
    animator.onAllExitsCompleted = null;
    animator.onExitCompleted = null;
    feedbackController.dispose();
    animator.finalizeAllRunningAnimations();
    gameStateNotifier.dispose();
    if (mounted) {
      super.dispose();
    }
  }
}
