import 'dart:convert';

import 'package:arrowtapout/data/stats_and_snapshot_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressState {
  const ProgressState({
    this.highestUnlocked = 1,
    this.stars = const {},
    this.hintBank = 5,
    this.stats = const GameStats(),
    this.coachMarkShown = false,
  });

  final int highestUnlocked;
  final Map<int, int> stars;
  final int hintBank;
  final GameStats stats;
  final bool coachMarkShown;

  ProgressState copyWith({
    int? highestUnlocked,
    Map<int, int>? stars,
    int? hintBank,
    GameStats? stats,
    bool? coachMarkShown,
  }) {
    return ProgressState(
      highestUnlocked: highestUnlocked ?? this.highestUnlocked,
      stars: stars ?? this.stars,
      hintBank: hintBank ?? this.hintBank,
      stats: stats ?? this.stats,
      coachMarkShown: coachMarkShown ?? this.coachMarkShown,
    );
  }

  Map<String, dynamic> toJson() => {
        'highestUnlocked': highestUnlocked,
        'stars': stars.map((k, v) => MapEntry(k.toString(), v)),
        'hintBank': hintBank,
        'stats': stats.toJson(),
        'coachMarkShown': coachMarkShown,
      };

  factory ProgressState.fromJson(Map<String, dynamic> json) {
    final rawStars = json['stars'] as Map<String, dynamic>? ?? {};
    final starsMap = rawStars.map((k, v) => MapEntry(int.parse(k), v as int));

    return ProgressState(
      highestUnlocked: json['highestUnlocked'] as int? ?? 1,
      stars: starsMap,
      hintBank: json['hintBank'] as int? ?? 5,
      stats: json['stats'] != null
          ? GameStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const GameStats(),
      coachMarkShown: json['coachMarkShown'] as bool? ?? false,
    );
  }
}

class ProgressRepository extends StateNotifier<ProgressState> {
  ProgressRepository(this._prefs) : super(const ProgressState()) {
    _load();
  }

  final SharedPreferences? _prefs;
  static const String _key = 'unwind.progress';
  static const String migrationResetKey = 'arrowz.v2_redesign_level1_reset';

  void _load() {
    if (_prefs == null) return;

    // One-time update migration: all users start fresh from Level 1
    final hasResetForUpdate = _prefs.getBool(migrationResetKey) ?? false;
    if (!hasResetForUpdate) {
      _prefs.remove(_key);
      _prefs.remove('unwind.snapshot');
      _prefs.setBool(migrationResetKey, true);
      state = const ProgressState(highestUnlocked: 1);
      return;
    }

    final jsonStr = _prefs.getString(_key);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = ProgressState.fromJson(map);
      } catch (_) {
        // Fallback to default on corrupt data
      }
    }
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Marks a level completed, awards stars, updates stats and unlocks next level.
  Future<void> recordLevelCompleted({
    required int levelId,
    required int starsEarned,
    required int threadsCleared,
    required int mistakes,
  }) async {
    final newStars = Map<int, int>.of(state.stars);
    final previousStars = newStars[levelId] ?? 0;
    if (starsEarned > previousStars) {
      newStars[levelId] = starsEarned;
    }

    final newHighest = levelId >= state.highestUnlocked
        ? (levelId + 1).clamp(1, 200)
        : state.highestUnlocked;

    // Hint bank: +1 for every 3 levels completed, capped at 9
    var newHintBank = state.hintBank;
    if (previousStars == 0 && newStars.length % 3 == 0 && newHintBank < 9) {
      newHintBank = (newHintBank + 1).clamp(0, 9);
    }

    final isPerfect = mistakes == 0;
    final newStreak = isPerfect ? state.stats.currentPerfectStreak + 1 : 0;
    final longestStreak = newStreak > state.stats.longestPerfectStreak
        ? newStreak
        : state.stats.longestPerfectStreak;

    final updatedStats = state.stats.copyWith(
      levelsCleared: newStars.length,
      totalStars: newStars.values.fold<int>(0, (a, b) => a + b),
      threadsCleared: state.stats.threadsCleared + threadsCleared,
      perfectLevels: isPerfect && previousStars == 0
          ? state.stats.perfectLevels + 1
          : state.stats.perfectLevels,
      currentPerfectStreak: newStreak,
      longestPerfectStreak: longestStreak,
    );

    state = state.copyWith(
      highestUnlocked: newHighest,
      stars: newStars,
      hintBank: newHintBank,
      stats: updatedStats,
    );

    await _save();
  }

  /// Deducts one hint from the global bank.
  Future<bool> consumeHint() async {
    if (state.hintBank <= 0) return false;
    state = state.copyWith(hintBank: state.hintBank - 1);
    await _save();
    return true;
  }

  /// Marks the level 1 coach mark as dismissed.
  Future<void> setCoachMarkShown() async {
    state = state.copyWith(coachMarkShown: true);
    await _save();
  }

  /// Resets all progress back to initial default state.
  Future<void> resetProgress() async {
    state = const ProgressState(highestUnlocked: 1);
    if (_prefs != null) {
      await _prefs.remove(_key);
      await _prefs.remove('unwind.snapshot');
      await _prefs.setBool(migrationResetKey, true);
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final progressProvider =
    StateNotifierProvider<ProgressRepository, ProgressState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ProgressRepository(prefs);
});
