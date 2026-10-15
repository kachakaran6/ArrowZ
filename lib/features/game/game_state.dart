import 'package:arrowtapout/engine/level.dart';

enum GameStatus { playing, completed, failed }

/// Immutable state snapshot of an active game level.
class GameState {
  const GameState({
    required this.level,
    required this.activeIds,
    required this.mistakes,
    required this.hintsUsed,
    required this.moves,
    required this.elapsedSeconds,
    required this.status,
    required this.stars,
    required this.showCoachMark,
    this.hintedThreadId,
    this.lastBlockedTapTimeMs = 0.0,
    this.lastBlockedThreadId,
    this.chainCount = 0,
    this.bestChain = 0,
    this.lastPullTimeMs = 0.0,
  });

  final Level level;
  final Set<int> activeIds;
  final int mistakes;
  final int hintsUsed;
  final int moves;
  final int elapsedSeconds;
  final GameStatus status;
  final int stars;
  final bool showCoachMark;
  final int? hintedThreadId;
  final double lastBlockedTapTimeMs;
  final int? lastBlockedThreadId;
  final int chainCount;
  final int bestChain;
  final double lastPullTimeMs;

  /// Tutorial mode flag (all levels now track mistakes and lives).
  bool get isTutorial => false;

  /// Remaining mistakes out of 3 allowed.
  int get remainingMistakes => (3 - mistakes).clamp(0, 3);

  /// Remaining lives out of 3 maximum lives.
  int get remainingLives => remainingMistakes;

  /// Number of cleared threads.
  int get clearedCount => level.threads.length - activeIds.length;

  /// Total number of arrows at the beginning of the level.
  int get totalArrows => level.threads.length;

  /// Number of arrows successfully removed.
  int get removedArrows => clearedCount;

  /// Normalized level progress value clamped to [0.0, 1.0].
  double get progress =>
      totalArrows == 0 ? 0.0 : (removedArrows / totalArrows).clamp(0.0, 1.0);

  /// Calculates stars on completion: 3 for 0 mistakes, 2 for 1-2 mistakes, 1 otherwise.
  static int calculateStars(int mistakes) {
    if (mistakes == 0) return 3;
    if (mistakes <= 2) return 2;
    return 1;
  }

  GameState copyWith({
    Level? level,
    Set<int>? activeIds,
    int? mistakes,
    int? hintsUsed,
    int? moves,
    int? elapsedSeconds,
    GameStatus? status,
    int? stars,
    bool? showCoachMark,
    int? hintedThreadId,
    double? lastBlockedTapTimeMs,
    int? lastBlockedThreadId,
    int? chainCount,
    int? bestChain,
    double? lastPullTimeMs,
  }) {
    return GameState(
      level: level ?? this.level,
      activeIds: activeIds ?? this.activeIds,
      mistakes: mistakes ?? this.mistakes,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      moves: moves ?? this.moves,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      status: status ?? this.status,
      stars: stars ?? this.stars,
      showCoachMark: showCoachMark ?? this.showCoachMark,
      hintedThreadId: hintedThreadId ?? this.hintedThreadId,
      lastBlockedTapTimeMs: lastBlockedTapTimeMs ?? this.lastBlockedTapTimeMs,
      lastBlockedThreadId: lastBlockedThreadId ?? this.lastBlockedThreadId,
      chainCount: chainCount ?? this.chainCount,
      bestChain: bestChain ?? this.bestChain,
      lastPullTimeMs: lastPullTimeMs ?? this.lastPullTimeMs,
    );
  }
}
