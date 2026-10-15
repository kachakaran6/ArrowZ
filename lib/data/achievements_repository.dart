import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AchievementItem {
  const AchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.current,
    required this.iconCode,
  });

  final String id;
  final String title;
  final String description;
  final int target;
  final int current;
  final int iconCode; // 0 to 4 icon types

  bool get isUnlocked => current >= target;
  double get progress => (current / target).clamp(0.0, 1.0);
}

final achievementsProvider = Provider<List<AchievementItem>>((ref) {
  final progress = ref.watch(progressProvider);
  final streak = ref.watch(streakRepositoryProvider);
  final stats = progress.stats;
  final totalStars = progress.totalStars;
  final highestUnlocked = progress.highestUnlocked;

  return [
    AchievementItem(
      id: 'first_pull',
      title: 'First Pull',
      description: 'Free your first thread',
      target: 1,
      current: stats.threadsCleared > 0 ? 1 : 0,
      iconCode: 0,
    ),
    AchievementItem(
      id: 'level_10',
      title: 'Double Digit',
      description: 'Clear 10 levels',
      target: 10,
      current: (highestUnlocked - 1).clamp(0, 10),
      iconCode: 1,
    ),
    AchievementItem(
      id: 'level_50',
      title: 'Quarter Way',
      description: 'Clear 50 levels',
      target: 50,
      current: (highestUnlocked - 1).clamp(0, 50),
      iconCode: 1,
    ),
    AchievementItem(
      id: 'level_100',
      title: 'Centurion',
      description: 'Clear 100 levels',
      target: 100,
      current: (highestUnlocked - 1).clamp(0, 100),
      iconCode: 1,
    ),
    AchievementItem(
      id: 'level_200',
      title: 'Master Weaver',
      description: 'Clear all 200 levels',
      target: 200,
      current: (highestUnlocked - 1).clamp(0, 200),
      iconCode: 1,
    ),
    AchievementItem(
      id: 'chain_5',
      title: 'Flow State',
      description: 'Build a chain of 5',
      target: 5,
      current: (stats.threadsCleared >= 5 ? 5 : 0),
      iconCode: 2,
    ),
    AchievementItem(
      id: 'chain_10',
      title: 'In the Groove',
      description: 'Build a chain of 10',
      target: 10,
      current: (stats.threadsCleared >= 10 ? 10 : 0),
      iconCode: 2,
    ),
    AchievementItem(
      id: 'chain_20',
      title: 'Unstoppable',
      description: 'Build a chain of 20',
      target: 20,
      current: (stats.threadsCleared >= 20 ? 20 : 0),
      iconCode: 2,
    ),
    AchievementItem(
      id: 'clean_sweep',
      title: 'Clean Sweep',
      description: 'Clear a level with zero mistakes',
      target: 1,
      current: stats.perfectLevels > 0 ? 1 : 0,
      iconCode: 3,
    ),
    AchievementItem(
      id: 'perfect_10',
      title: 'Perfect Ten',
      description: '10 levels with zero mistakes',
      target: 10,
      current: stats.perfectLevels.clamp(0, 10),
      iconCode: 3,
    ),
    AchievementItem(
      id: 'flawless_chapter',
      title: 'Flawless Chapter',
      description: 'Clear an entire chapter with 3 stars on each level',
      target: 20,
      current: totalStars >= 60 ? 20 : totalStars.clamp(0, 20),
      iconCode: 3,
    ),
    AchievementItem(
      id: 'streak_3',
      title: 'Spark',
      description: 'Reach a 3-day streak',
      target: 3,
      current: streak.currentStreak.clamp(0, 3),
      iconCode: 4,
    ),
    AchievementItem(
      id: 'streak_7',
      title: 'Flame',
      description: 'Reach a 7-day streak',
      target: 7,
      current: streak.currentStreak.clamp(0, 7),
      iconCode: 4,
    ),
    AchievementItem(
      id: 'streak_30',
      title: 'Inferno',
      description: 'Reach a 30-day streak',
      target: 30,
      current: streak.currentStreak.clamp(0, 30),
      iconCode: 4,
    ),
    AchievementItem(
      id: 'daily_10',
      title: 'Daily Dedication',
      description: 'Solve 10 Daily Threads',
      target: 10,
      current: streak.totalCompleted.clamp(0, 10),
      iconCode: 4,
    ),
    AchievementItem(
      id: 'no_hints_25',
      title: 'Pure Intuition',
      description: 'Clear 25 levels without using hints',
      target: 25,
      current: stats.perfectLevels.clamp(0, 25),
      iconCode: 0,
    ),
    AchievementItem(
      id: 'bank_9',
      title: 'Conservationist',
      description: 'Max out your hint bank to 9',
      target: 9,
      current: progress.hintBank.clamp(0, 9),
      iconCode: 0,
    ),
    AchievementItem(
      id: 'speedy',
      title: 'Rapid Pulls',
      description: 'Clear a level in under 30 seconds',
      target: 1,
      current: stats.levelsCleared > 0 ? 1 : 0,
      iconCode: 2,
    ),
    AchievementItem(
      id: 'all_stars_100',
      title: 'Constellation',
      description: 'Earn 100 stars across all levels',
      target: 100,
      current: totalStars.clamp(0, 100),
      iconCode: 3,
    ),
    AchievementItem(
      id: 'grand_weaver',
      title: 'Grand Weaver',
      description: 'Earn 600 total stars across all chapters',
      target: 600,
      current: totalStars.clamp(0, 600),
      iconCode: 1,
    ),
  ];
});
