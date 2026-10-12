import 'dart:async';

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/stats_and_snapshot_models.dart';
import 'package:arrowtapout/engine/board_state.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameController extends StateNotifier<GameState> {
  GameController({
    required Level level,
    required this.animator,
    required this.audio,
    required this.haptics,
    required this.progress,
    required this.snapshotRepo,
    this.reduceMotion = false,
    LevelSnapshot? initialSnapshot,
    bool coachMarkShown = false,
  })  : _boardState = BoardState(level),
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
  final ProgressRepository progress;
  final SnapshotRepository snapshotRepo;
  final bool reduceMotion;

  Timer? _completeTimer;

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
      // Free thread: exit immediately
      _boardState.remove(threadId);
      animator.triggerExit(threadId, reduceMotion: _reduceMotion);
      audio.playPull();
      haptics.light();

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
      // Blocked thread tap
      final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
      final isDebounced = state.lastBlockedThreadId == threadId &&
          (nowMs - state.lastBlockedTapTimeMs) < 250.0;

      final blocker = _boardState.firstBlocker(threadId);
      if (blocker != null) {
        animator.triggerBlocked(
          threadId: threadId,
          blocker: blocker,
          cellSize: cellSize,
          reduceMotion: _reduceMotion,
        );
      }

      audio.playBlock();
      haptics.medium();

      var newMistakes = state.mistakes;
      if (!isDebounced) {
        newMistakes++;
      }

      final isFailed = newMistakes >= 3;

      state = state.copyWith(
        mistakes: newMistakes,
        status: isFailed ? GameStatus.failed : GameStatus.playing,
        lastBlockedTapTimeMs: nowMs,
        lastBlockedThreadId: threadId,
      );

      if (isFailed) {
        snapshotRepo.clearSnapshot();
      } else {
        _saveSnapshotDebounced();
      }
    }
  }

  void _handleLevelCompleted() {
    _completeTimer?.cancel();

    // 350 ms stillness after last exit before showing complete sheet
    _completeTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      final stars = GameState.calculateStars(state.mistakes);
      state = state.copyWith(
        status: GameStatus.completed,
        stars: stars,
      );

      audio.playComplete();
      snapshotRepo.clearSnapshot();

      progress.recordLevelCompleted(
        levelId: state.level.id,
        starsEarned: stars,
        threadsCleared: state.level.threads.length,
        mistakes: state.mistakes,
      );
    });
  }

  /// Uses a hint from the global bank to highlight an optimal free thread for 2 seconds.
  Future<void> useHint() async {
    if (state.status != GameStatus.playing) return;
    if (state.hintsUsed >= 3) return;

    final hintId = _boardState.chooseHintThread();
    if (hintId == null) return;

    final consumed = await progress.consumeHint();
    if (!consumed) return;

    animator.triggerHint(hintId);
    state = state.copyWith(
      hintsUsed: state.hintsUsed + 1,
      hintedThreadId: hintId,
    );
  }

  void dismissCoachMark() {
    progress.setCoachMarkShown();
    state = state.copyWith(showCoachMark: false);
  }

  /// Restarts current level from clean state.
  void restartLevel(double cellSize) {
    _completeTimer?.cancel();
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
    );
  }

  void _saveSnapshotDebounced() {
    snapshotRepo.saveSnapshot(
      levelId: state.level.id,
      activeThreadIds: state.activeIds,
      mistakes: state.mistakes,
      hintsUsed: state.hintsUsed,
    );
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    super.dispose();
  }
}
