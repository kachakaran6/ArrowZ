import 'package:arrowtapout/data/progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable model representing an active QA testing session.
///
/// Ensures progression, stars, and level completions during testing
/// remain strictly isolated in memory and never overwrite persistent player save state.
class QaSessionState {
  const QaSessionState({
    this.isActive = false,
    this.activeLevelId,
    this.originalProgressSnapshot,
    this.completedQaLevels = const {},
    this.qaLevelStars = const {},
    this.suppressAnimations = false,
    this.sessionStartedAt,
  });

  /// Whether an authorized QA testing session is currently active.
  final bool isActive;

  /// The level currently targeted or launched for testing.
  final int? activeLevelId;

  /// Snapshot of real player progress when the testing session was initiated.
  final ProgressState? originalProgressSnapshot;

  /// Set of level IDs completed during this QA session.
  final Set<int> completedQaLevels;

  /// Stars earned in this QA session per level ID (isolated from persistent progress).
  final Map<int, int> qaLevelStars;

  /// Testing utility: suppresses nonessential slide animations for rapid inspection.
  final bool suppressAnimations;

  /// Timestamp when this testing session began.
  final DateTime? sessionStartedAt;

  /// Checks if [levelId] is currently being tested in this QA session.
  bool isLevelActiveInQa(int levelId) => isActive && activeLevelId == levelId;

  QaSessionState copyWith({
    bool? isActive,
    int? activeLevelId,
    ProgressState? originalProgressSnapshot,
    Set<int>? completedQaLevels,
    Map<int, int>? qaLevelStars,
    bool? suppressAnimations,
    DateTime? sessionStartedAt,
  }) {
    return QaSessionState(
      isActive: isActive ?? this.isActive,
      activeLevelId: activeLevelId ?? this.activeLevelId,
      originalProgressSnapshot:
          originalProgressSnapshot ?? this.originalProgressSnapshot,
      completedQaLevels: completedQaLevels ?? this.completedQaLevels,
      qaLevelStars: qaLevelStars ?? this.qaLevelStars,
      suppressAnimations: suppressAnimations ?? this.suppressAnimations,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
    );
  }
}

/// Controller managing testing session state and progression boundaries.
class QaSessionController extends StateNotifier<QaSessionState> {
  QaSessionController() : super(const QaSessionState());

  /// Initiates an isolated testing session for [levelId], capturing [currentProgress] snapshot.
  void startSession({
    required int levelId,
    required ProgressState currentProgress,
  }) {
    state = state.copyWith(
      isActive: true,
      activeLevelId: levelId,
      originalProgressSnapshot:
          state.originalProgressSnapshot ?? currentProgress,
      sessionStartedAt: state.sessionStartedAt ?? DateTime.now(),
    );
  }

  /// Updates active testing target when switching levels within QA.
  void setTargetLevel(int levelId) {
    state = state.copyWith(
      isActive: true,
      activeLevelId: levelId,
    );
  }

  /// Records level completion inside the isolated QA session.
  /// Never writes to persistent user progress or awards persistent achievements.
  void recordQaLevelCompleted({
    required int levelId,
    required int stars,
  }) {
    if (!state.isActive) return;

    final updatedCompleted = Set<int>.of(state.completedQaLevels)..add(levelId);
    final updatedStars = Map<int, int>.of(state.qaLevelStars);
    final prev = updatedStars[levelId] ?? 0;
    if (stars > prev) {
      updatedStars[levelId] = stars;
    }

    state = state.copyWith(
      completedQaLevels: updatedCompleted,
      qaLevelStars: updatedStars,
    );
  }

  /// Prepares the QA session for the next sequential level.
  void prepareNextLevel(int nextLevelId) {
    state = state.copyWith(
      isActive: true,
      activeLevelId: nextLevelId,
    );
  }

  /// Toggles suppression of nonessential animations during QA testing.
  void setSuppressAnimations(bool suppress) {
    state = state.copyWith(suppressAnimations: suppress);
  }

  /// Clears testing session overrides and restores regular gameplay context.
  void clearOverrides() {
    state = const QaSessionState();
  }
}

final qaSessionProvider =
    StateNotifierProvider<QaSessionController, QaSessionState>((ref) {
  return QaSessionController();
});
