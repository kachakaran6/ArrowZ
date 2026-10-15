import 'dart:convert';

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Immutable model representing the daily activity for a single calendar day.
@immutable
class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.isCompleted,
    required this.isToday,
  });

  final DateTime date;
  final bool isCompleted;
  final bool isToday;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyActivity &&
          runtimeType == other.runtimeType &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          isCompleted == other.isCompleted &&
          isToday == other.isToday;

  @override
  int get hashCode =>
      Object.hash(date.year, date.month, date.day, isCompleted, isToday);
}

/// Immutable data state for the daily streak system.
@immutable
class StreakData {
  const StreakData({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastQualifyingPlayDate,
    this.qualifyingDates = const {},
    this.remindersEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.schemaVersion = 1,
  });

  final int currentStreak;
  final int bestStreak;
  final DateTime? lastQualifyingPlayDate;
  final Set<String> qualifyingDates;
  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final int schemaVersion;

  bool get completedToday {
    if (lastQualifyingPlayDate == null) return false;
    final now = DateTime.now();
    return lastQualifyingPlayDate!.year == now.year &&
        lastQualifyingPlayDate!.month == now.month &&
        lastQualifyingPlayDate!.day == now.day;
  }

  int get totalCompleted => qualifyingDates.length;

  StreakData copyWith({
    int? currentStreak,
    int? bestStreak,
    DateTime? lastQualifyingPlayDate,
    Set<String>? qualifyingDates,
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? schemaVersion,
  }) {
    return StreakData(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastQualifyingPlayDate:
          lastQualifyingPlayDate ?? this.lastQualifyingPlayDate,
      qualifyingDates: qualifyingDates ?? this.qualifyingDates,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastQualifyingPlayDate': lastQualifyingPlayDate != null
            ? dateToKey(lastQualifyingPlayDate!)
            : null,
        'qualifyingDates': qualifyingDates.toList()..sort(),
        'remindersEnabled': remindersEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  factory StreakData.fromJson(Map<String, dynamic> json) {
    final rawDates = json['qualifyingDates'] as List<dynamic>? ?? [];
    final datesSet = rawDates.map((e) => e.toString()).toSet();

    final lastDateStr = json['lastQualifyingPlayDate'] as String?;
    final lastDate = lastDateStr != null ? parseDateKey(lastDateStr) : null;

    return StreakData(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      lastQualifyingPlayDate: lastDate,
      qualifyingDates: datesSet,
      remindersEnabled: json['remindersEnabled'] as bool? ?? false,
      reminderHour: json['reminderHour'] as int? ?? 20,
      reminderMinute: json['reminderMinute'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakData &&
          runtimeType == other.runtimeType &&
          currentStreak == other.currentStreak &&
          bestStreak == other.bestStreak &&
          lastQualifyingPlayDate == other.lastQualifyingPlayDate &&
          setEquals(qualifyingDates, other.qualifyingDates) &&
          remindersEnabled == other.remindersEnabled &&
          reminderHour == other.reminderHour &&
          reminderMinute == other.reminderMinute &&
          schemaVersion == other.schemaVersion;

  @override
  int get hashCode => Object.hash(
        currentStreak,
        bestStreak,
        lastQualifyingPlayDate,
        Object.hashAll(qualifyingDates),
        remindersEnabled,
        reminderHour,
        reminderMinute,
        schemaVersion,
      );
}

/// Normalizes any DateTime to local midnight (year, month, day).
DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Converts a date to a calendar key "YYYY-MM-DD".
String dateToKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a "YYYY-MM-DD" key into a normalized DateTime.
DateTime? parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Authoritative daily streak tracking engine and local repository.
///
/// Implements calendar-day date arithmetic without 24-hour interval assumptions,
/// supporting leap years, month boundaries, and daylight-saving transitions.
class StreakRepository extends StateNotifier<StreakData> {
  StreakRepository(
    this._prefs, {
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        super(const StreakData()) {
    _load();
  }

  final SharedPreferences? _prefs;
  final DateTime Function() _clock;
  static const String _key = 'arrowz.streak';

  DateTime get now => _clock();

  void _load() {
    if (_prefs == null) return;
    final jsonStr = _prefs.getString(_key);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final loaded = StreakData.fromJson(map);
        state = loaded;
        // Recalculate streak status against current clock
        refreshStreakStatus();
      } catch (e) {
        // Safe fallback without silently corrupting if unparseable
        debugPrint('Warning: Failed to parse streak data, using default: $e');
      }
    }
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  /// Calculates the effective streak as of [referenceDate].
  ///
  /// - If [referenceDate] was completed, counts consecutive preceding days.
  /// - If [referenceDate] is not yet completed, checks if [yesterday] was completed.
  ///   If yesterday was completed, the active streak is preserved pending today's play.
  /// - If neither today nor yesterday was completed, the streak has lapsed and is 0.
  int calculateStreakForDate(DateTime referenceDate, Set<String> dates) {
    final today = normalizeDate(referenceDate);
    final todayKey = dateToKey(today);

    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayKey = dateToKey(yesterday);

    if (dates.contains(todayKey)) {
      int count = 0;
      DateTime cur = today;
      while (dates.contains(dateToKey(cur))) {
        count++;
        cur = DateTime(cur.year, cur.month, cur.day - 1);
      }
      return count;
    } else if (dates.contains(yesterdayKey)) {
      int count = 0;
      DateTime cur = yesterday;
      while (dates.contains(dateToKey(cur))) {
        count++;
        cur = DateTime(cur.year, cur.month, cur.day - 1);
      }
      return count;
    }

    return 0;
  }

  /// Refreshes the active streak count based on the current local calendar date.
  ///
  /// Safe to call on app launch, resume, or when viewing the Streak screen.
  void refreshStreakStatus([DateTime? testNow]) {
    final curNow = testNow ?? now;
    final calculatedStreak =
        calculateStreakForDate(curNow, state.qualifyingDates);
    if (calculatedStreak != state.currentStreak) {
      state = state.copyWith(currentStreak: calculatedStreak);
      _save();
    }
  }

  /// Records a qualifying level completion.
  ///
  /// Only level completions count. Multiple completions on the same calendar day
  /// are idempotent and will not inflate the streak.
  Future<bool> recordQualifyingPlay([
    DateTime? testNow,
    NotificationService? notificationService,
  ]) async {
    final playTime = testNow ?? now;
    final today = normalizeDate(playTime);
    final todayKey = dateToKey(today);

    final newDates = Set<String>.of(state.qualifyingDates);
    final isFirstCompletionToday = newDates.add(todayKey);

    // Calculate updated streak
    final newStreak = calculateStreakForDate(today, newDates);
    final newBest = newStreak > state.bestStreak ? newStreak : state.bestStreak;

    state = state.copyWith(
      currentStreak: newStreak,
      bestStreak: newBest,
      lastQualifyingPlayDate: today,
      qualifyingDates: newDates,
    );

    await _save();

    if (notificationService != null) {
      await syncReminders(notificationService, playTime);
    }

    return isFirstCompletionToday;
  }

  /// Returns whether a qualifying play has already been recorded for today.
  bool isTodayCompleted([DateTime? testNow]) {
    final today = normalizeDate(testNow ?? now);
    return state.qualifyingDates.contains(dateToKey(today));
  }

  /// Current consecutive streak.
  int getCurrentStreak([DateTime? testNow]) {
    return calculateStreakForDate(testNow ?? now, state.qualifyingDates);
  }

  /// Best streak achieved historically.
  int getBestStreak() => state.bestStreak;

  /// The date of the last recorded qualifying level completion.
  DateTime? getLastQualifyingPlayDate() => state.lastQualifyingPlayDate;

  /// Returns recent activity for the last [days] calendar days ending on today.
  List<DailyActivity> getRecentActivity([int days = 7, DateTime? testNow]) {
    final today = normalizeDate(testNow ?? now);
    final list = <DailyActivity>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(today.year, today.month, today.day - i);
      final key = dateToKey(date);
      list.add(DailyActivity(
        date: date,
        isCompleted: state.qualifyingDates.contains(key),
        isToday: i == 0,
      ));
    }

    return list;
  }

  /// Synchronizes scheduled streak reminders based on user preferences, current streak,
  /// and today's completion status.
  ///
  /// Rules:
  /// - If reminders are disabled: cancel pending reminders.
  /// - If user has never started a streak (streak == 0): cancel pending reminders.
  /// - If user already completed a qualifying level today: suppress/cancel today's reminder,
  ///   and schedule for tomorrow evening at the configured reminder time.
  /// - If today is not yet completed and user has an active streak: schedule for today evening
  ///   if the reminder time has not already passed.
  Future<void> syncReminders(
    NotificationService notificationService, [
    DateTime? testNow,
  ]) async {
    final referenceTime = testNow ?? now;
    final today = normalizeDate(referenceTime);
    final streak = calculateStreakForDate(referenceTime, state.qualifyingDates);

    if (!state.remindersEnabled || streak == 0) {
      await notificationService.cancelStreakReminder();
      return;
    }

    final todayPlayed = isTodayCompleted(referenceTime);
    if (todayPlayed) {
      // Today is completed: suppress today's reminder and schedule for tomorrow evening
      await notificationService.cancelStreakReminder();
      final tomorrow = DateTime(
        today.year,
        today.month,
        today.day + 1,
        state.reminderHour,
        state.reminderMinute,
      );
      await notificationService.scheduleStreakReminder(
        hour: state.reminderHour,
        minute: state.reminderMinute,
        title: 'Keep your ArrowZ streak going',
        body: 'Complete a level today to continue your streak.',
        testNow: tomorrow,
      );
    } else {
      // Today is not yet completed: schedule for today if the time is still in the future
      final todayReminderTime = DateTime(
        today.year,
        today.month,
        today.day,
        state.reminderHour,
        state.reminderMinute,
      );
      if (referenceTime.isBefore(todayReminderTime)) {
        await notificationService.scheduleStreakReminder(
          hour: state.reminderHour,
          minute: state.reminderMinute,
          title: 'Keep your ArrowZ streak going',
          body: 'Complete a level today to continue your streak.',
          testNow: todayReminderTime,
        );
      } else {
        await notificationService.cancelStreakReminder();
      }
    }
  }

  /// Updates whether daily reminders are enabled.
  Future<void> setRemindersEnabled(
    bool enabled, [
    NotificationService? notificationService,
  ]) async {
    state = state.copyWith(remindersEnabled: enabled);
    await _save();
    if (notificationService != null) {
      await syncReminders(notificationService);
    }
  }

  /// Updates the scheduled reminder time.
  Future<void> setReminderTime(int hour, int minute) async {
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
    await _save();
  }

  /// Resets streak state for testing or debug purposes.
  Future<void> resetStreak() async {
    state = const StreakData();
    if (_prefs != null) {
      await _prefs.remove(_key);
    }
  }
}

/// Provider for the StreakRepository.
final streakRepositoryProvider =
    StateNotifierProvider<StreakRepository, StreakData>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StreakRepository(prefs);
});
