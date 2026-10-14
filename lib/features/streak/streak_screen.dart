import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Dedicated screen displaying daily streak progress, recent activity, reset rules,
/// and local reminder settings.
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh streak status when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(streakRepositoryProvider.notifier).refreshStreakStatus();
      }
    });
  }

  Future<void> _onToggleReminders(bool value) async {
    final haptics = ref.read(hapticsServiceProvider);
    await haptics.selection();

    final notificationService = ref.read(notificationServiceProvider);
    final streakRepo = ref.read(streakRepositoryProvider.notifier);

    if (value) {
      final hasPerm = await notificationService.hasPermission();
      if (!hasPerm) {
        if (!mounted) return;
        final shouldRequest = await _showPermissionExplanationDialog();
        if (shouldRequest != true) return;

        final granted = await notificationService.requestPermission();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission was denied. You can enable notifications in device settings.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }
      await streakRepo.setRemindersEnabled(true, notificationService);
    } else {
      await streakRepo.setRemindersEnabled(false, notificationService);
    }
  }

  Future<bool?> _showPermissionExplanationDialog() {
    final tokens = context.tokens;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        title: Text(
          'Daily Streak Reminders',
          style: tokens.typography.heading.copyWith(color: tokens.ink),
        ),
        content: Text(
          'ArrowZ can send a quiet daily reminder at 8:00 PM if you haven\'t completed a level yet, so you never lose your streak.\n\nAll reminders are offline and generated locally on your device.',
          style: tokens.typography.body.copyWith(color: tokens.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Not now',
              style: tokens.typography.label.copyWith(color: tokens.inkMuted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accent,
              foregroundColor: tokens.onAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Allow Reminders',
              style: tokens.typography.label.copyWith(color: tokens.onAccent),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'None';
    final now = DateTime.now();
    final today = normalizeDate(now);
    final norm = normalizeDate(date);

    if (norm == today) return 'Today';
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (norm == yesterday) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _weekdayAbbreviation(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'T';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'S';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final streak = ref.watch(streakRepositoryProvider);
    final streakRepo = ref.read(streakRepositoryProvider.notifier);
    final haptics = ref.read(hapticsServiceProvider);

    final currentStreak = streak.currentStreak;
    final bestStreak = streak.bestStreak;
    final isCompletedToday = streakRepo.isTodayCompleted();
    final recentActivity = streakRepo.getRecentActivity(7);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: Text('Daily Streak', style: tokens.typography.title),
        leading: IconButton(
          key: const Key('streak_back_button'),
          icon: Icon(Icons.arrow_back_rounded, color: tokens.ink),
          tooltip: 'Back',
          onPressed: () {
            haptics.selection();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Primitives.space20,
            vertical: Primitives.space16,
          ),
          children: [
            // Streak Hero Card
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.threadFaint, width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Primitives.space20,
                  vertical: Primitives.space24,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 48.0,
                        color:
                            currentStreak > 0 ? tokens.accent : tokens.inkMuted,
                      ),
                      const SizedBox(height: Primitives.space8),
                      Text(
                        '$currentStreak',
                        key: const Key('streak_current_count'),
                        style: TextStyle(
                          fontFamily: Primitives.fontDisplay,
                          fontSize: 48.0,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(height: Primitives.space4),
                      Text(
                        currentStreak == 1 ? 'DAY STREAK' : 'DAYS STREAK',
                        style: tokens.typography.caption.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                          color: tokens.inkMuted,
                        ),
                      ),
                      const SizedBox(height: Primitives.space16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Primitives.space12,
                          vertical: Primitives.space8,
                        ),
                        decoration: BoxDecoration(
                          color: isCompletedToday
                              ? tokens.success.withValues(alpha: 0.12)
                              : tokens.threadFaint.withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(Primitives.radiusButton),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompletedToday
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16.0,
                              color: isCompletedToday
                                  ? tokens.success
                                  : tokens.inkMuted,
                            ),
                            const SizedBox(width: Primitives.space8),
                            Flexible(
                              child: Text(
                                isCompletedToday
                                    ? 'Completed for today'
                                    : 'Not yet completed today',
                                key: const Key('streak_today_status'),
                                style: tokens.typography.caption.copyWith(
                                  color: isCompletedToday
                                      ? tokens.success
                                      : tokens.inkMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: Primitives.space16),

            // Statistics Overview Grid
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: tokens.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(Primitives.radiusCard),
                      side: BorderSide(color: tokens.threadFaint, width: 1.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Primitives.space16,
                        vertical: Primitives.space16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Best Streak',
                            style: tokens.typography.caption.copyWith(
                              color: tokens.inkMuted,
                            ),
                          ),
                          const SizedBox(height: Primitives.space4),
                          Text(
                            '$bestStreak ${bestStreak == 1 ? 'day' : 'days'}',
                            key: const Key('streak_best_count'),
                            style: tokens.typography.heading.copyWith(
                              color: tokens.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Primitives.space12),
                Expanded(
                  child: Card(
                    color: tokens.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(Primitives.radiusCard),
                      side: BorderSide(color: tokens.threadFaint, width: 1.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Primitives.space16,
                        vertical: Primitives.space16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Played',
                            style: tokens.typography.caption.copyWith(
                              color: tokens.inkMuted,
                            ),
                          ),
                          const SizedBox(height: Primitives.space4),
                          Text(
                            _formatDate(streak.lastQualifyingPlayDate),
                            key: const Key('streak_last_date'),
                            style: tokens.typography.heading.copyWith(
                              color: tokens.ink,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Primitives.space16),

            // 7-Day Recent Activity Strip
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.threadFaint, width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Primitives.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activity',
                      style: tokens.typography.label.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Primitives.space16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: recentActivity.map((activity) {
                        final isCompleted = activity.isCompleted;
                        final isToday = activity.isToday;

                        return Column(
                          children: [
                            Text(
                              _weekdayAbbreviation(activity.date.weekday),
                              style: tokens.typography.caption.copyWith(
                                color:
                                    isToday ? tokens.accent : tokens.inkMuted,
                                fontWeight:
                                    isToday ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: Primitives.space8),
                            Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? tokens.accent
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isToday
                                      ? tokens.accent
                                      : (isCompleted
                                          ? tokens.accent
                                          : tokens.threadFaint),
                                  width: isToday ? 2.0 : 1.0,
                                ),
                              ),
                              child: isCompleted
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 20.0,
                                      color: tokens.onAccent,
                                    )
                                  : (isToday
                                      ? Center(
                                          child: Container(
                                            width: 6.0,
                                            height: 6.0,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: tokens.accent,
                                            ),
                                          ),
                                        )
                                      : null),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: Primitives.space16),

            // Daily Evening Reminder Section
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.threadFaint, width: 1.0),
              ),
              child: SwitchListTile(
                key: const Key('streak_reminder_switch'),
                activeTrackColor: tokens.accent,
                title: Text(
                  'Daily evening reminder',
                  style: tokens.typography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Quiet reminder at 8:00 PM if you haven\'t played yet',
                  style: tokens.typography.caption.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
                value: streak.remindersEnabled,
                onChanged: _onToggleReminders,
              ),
            ),

            const SizedBox(height: Primitives.space16),

            // Reset Rule & Local-first Explanation
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Primitives.space8,
                vertical: Primitives.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How Streaks Work',
                    style: tokens.typography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: tokens.inkMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Primitives.space4),
                  Text(
                    'Complete at least one puzzle level every calendar day to maintain your streak. Missing a full day resets your active streak to 0.',
                    style: tokens.typography.caption.copyWith(
                      color: tokens.inkMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: Primitives.space8),
                  Text(
                    'All streak data is stored locally on this device. ArrowZ works 100% offline and never uploads your activity.',
                    style: tokens.typography.caption.copyWith(
                      color: tokens.inkFaint,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
