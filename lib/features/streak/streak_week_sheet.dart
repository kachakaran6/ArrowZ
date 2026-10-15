import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/design/widgets/streak_flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet displaying the 7-day streak calendar and streak status.
void showStreakWeekSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _StreakWeekSheetContent(),
  );
}

class _StreakWeekSheetContent extends ConsumerWidget {
  const _StreakWeekSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final streak = ref.watch(streakRepositoryProvider);
    final count = streak.currentStreak;
    final now = DateTime.now();

    // 7 days of the current week (Mon-Sun or past 7 days)
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Primitives.radiusSheet),
        ),
        border: Border(
          top: BorderSide(color: tokens.line),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 24.0,
        bottom: MediaQuery.paddingOf(context).bottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  StreakFlame(size: 24.0, color: tokens.accent),
                  const SizedBox(width: 10.0),
                  Text(
                    '$count Day Streak',
                    style: tokens.typography.title.copyWith(color: tokens.ink),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: tokens.inkMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            count > 0
                ? 'Solve the Daily Thread every day to keep your streak alive.'
                : 'Complete today\'s Daily Thread to ignite your streak.',
            style: tokens.typography.body.copyWith(color: tokens.inkMuted),
          ),
          const SizedBox(height: 24.0),
          // 7-day dots container
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(AppTokens.radius16),
              border: Border.all(color: tokens.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final dayIndex = i + 1; // 1 = Monday
                final isPast = dayIndex < weekday;
                final isToday = dayIndex == weekday;
                final isCompleted = (isToday && streak.completedToday) ||
                    (isPast && count >= (weekday - dayIndex));

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayNames[i],
                      style: tokens.typography.caption.copyWith(
                        color: isToday ? tokens.accent : tokens.inkMuted,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Container(
                      width: 28.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? tokens.accent
                            : isToday
                                ? tokens.accent.withValues(alpha: 0.15)
                                : tokens.surface,
                        border: Border.all(
                          color: isToday
                              ? tokens.accent
                              : isCompleted
                                  ? tokens.accent
                                  : tokens.line,
                          width: isToday ? 2.0 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? Icon(
                              Icons.check_rounded,
                              size: 16.0,
                              color: tokens.onAccent,
                            )
                          : isToday
                              ? Container(
                                  width: 8.0,
                                  height: 8.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tokens.accent,
                                  ),
                                )
                              : null,
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 24.0),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.surfaceRaised,
              foregroundColor: tokens.ink,
              minimumSize: const Size.fromHeight(48.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius16),
                side: BorderSide(color: tokens.line),
              ),
            ),
            child: Text('Close', style: tokens.typography.label),
          ),
        ],
      ),
    );
  }
}
