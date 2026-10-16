import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/stats_and_snapshot_models.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Persistence & Repositories', () {
    test('ProgressState round trip JSON serialization', () {
      const state = ProgressState(
        highestUnlocked: 17,
        stars: {1: 3, 2: 2, 3: 3},
        hintBank: 7,
        stats: GameStats(
          levelsCleared: 3,
          totalStars: 8,
          threadsCleared: 24,
          perfectLevels: 2,
          longestPerfectStreak: 2,
        ),
        coachMarkShown: true,
      );

      final json = state.toJson();
      final restored = ProgressState.fromJson(json);

      expect(restored.highestUnlocked, equals(17));
      expect(restored.stars, equals({1: 3, 2: 2, 3: 3}));
      expect(restored.hintBank, equals(7));
      expect(restored.stats.levelsCleared, equals(3));
      expect(restored.stats.totalStars, equals(8));
      expect(restored.coachMarkShown, isTrue);
    });

    test(
        'ProgressRepository hint bank grows every 3 completed levels capped at 9',
        () async {
      final repo = ProgressRepository(null);

      expect(repo.state.hintBank, equals(5));

      // Level 1
      await repo.recordLevelCompleted(
          levelId: 1, starsEarned: 3, threadsCleared: 4, mistakes: 0);
      expect(repo.state.hintBank, equals(5));

      // Level 2
      await repo.recordLevelCompleted(
          levelId: 2, starsEarned: 3, threadsCleared: 4, mistakes: 0);
      expect(repo.state.hintBank, equals(5));

      // Level 3 (multiples of 3 completed -> hint bank + 1)
      await repo.recordLevelCompleted(
          levelId: 3, starsEarned: 3, threadsCleared: 4, mistakes: 0);
      expect(repo.state.hintBank, equals(6));
    });

    test('SettingsState round trip JSON serialization', () {
      const settings = SettingsState(
        themeChoice: AppThemeMode.graphiteEmber,
        sound: false,
        haptics: true,
        reduceMotion: true,
      );

      final json = settings.toJson();
      final restored = SettingsState.fromJson(json);

      expect(restored.themeChoice, equals(AppThemeMode.graphiteEmber));
      expect(restored.sound, isFalse);
      expect(restored.haptics, isTrue);
      expect(restored.reduceMotion, isTrue);
    });

    test('LevelSnapshot round trip JSON serialization', () {
      const snapshot = LevelSnapshot(
        levelId: 42,
        activeThreadIds: {1, 3, 5},
        mistakes: 1,
        hintsUsed: 2,
        savedAtMs: 123456789,
      );

      final json = snapshot.toJson();
      final restored = LevelSnapshot.fromJson(json);

      expect(restored.levelId, equals(42));
      expect(restored.activeThreadIds, equals({1, 3, 5}));
      expect(restored.mistakes, equals(1));
      expect(restored.hintsUsed, equals(2));
    });

    test('Old user progress is reset to Level 1 on first launch after update',
        () async {
      SharedPreferences.setMockInitialValues({
        'unwind.progress':
            '{"highestUnlocked":68,"stars":{"1":3,"2":3},"hintBank":5,"stats":{"levelsCleared":67,"totalStars":180},"coachMarkShown":true}',
        'unwind.snapshot':
            '{"levelId":68,"activeThreadIds":[1,2],"mistakes":0,"hintsUsed":0,"savedAtMs":1234567}',
      });

      final prefs = await SharedPreferences.getInstance();

      // Creating repository performs migration
      final repo = ProgressRepository(prefs);

      // State is reset to Level 1
      expect(repo.state.highestUnlocked, equals(1));
      expect(repo.state.stars, isEmpty);

      // Snapshot and old progress are removed
      expect(prefs.containsKey('unwind.snapshot'), isFalse);
      expect(prefs.getBool(ProgressRepository.migrationResetKey), isTrue);

      // Now player completes level 1 -> unlocks level 2
      await repo.recordLevelCompleted(
        levelId: 1,
        starsEarned: 3,
        threadsCleared: 4,
        mistakes: 0,
      );
      expect(repo.state.highestUnlocked, equals(2));

      // Next app launch retains new progress
      final repo2 = ProgressRepository(prefs);
      expect(repo2.state.highestUnlocked, equals(2));
    });
  });
}
