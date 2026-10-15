import 'dart:async';

import 'package:arrowtapout/data/daily_thread_service.dart';
import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/design/widgets/arrowz_wordmark.dart';
import 'package:arrowtapout/design/widgets/primary_play_button.dart';
import 'package:arrowtapout/design/widgets/streak_flame.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/home/home_attract_board.dart';
import 'package:arrowtapout/features/levels/level_miniature_painter.dart';
import 'package:arrowtapout/features/streak/streak_week_sheet.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Distinctive, tactile lobby screen for ArrowZ: "dark console, living threads".
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isNavigating = false;
  DateTime? _lastNavTime;
  Level? _continueLevel;
  late final AnimationController _staggerController;

  static const List<String> _chapterNames = [
    'First Threads',
    'Loose Ends',
    'Straight Talk',
    'Corners',
    'Spirals',
    'Crosscurrents',
    'Dense Weave',
    'Labyrinth',
    'Long Form',
    'Masterworks',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(playUpdateServiceProvider).checkForUpdates(context);
        ref.read(streakRepositoryProvider.notifier).refreshStreakStatus();
        ref.read(streakRepositoryProvider.notifier).syncReminders(
              ref.read(notificationServiceProvider),
            );
        _loadContinueLevel();
      }
    });
  }

  Future<void> _loadContinueLevel() async {
    final progress = ref.read(progressProvider);
    final snapshot = ref.read(snapshotRepositoryProvider).getSnapshot();
    final targetLevelId =
        (snapshot != null && snapshot.levelId <= progress.highestUnlocked)
            ? snapshot.levelId.clamp(1, 200)
            : progress.highestUnlocked.clamp(1, 200);

    try {
      final level =
          await ref.read(levelRepositoryProvider).loadLevel(targetLevelId);
      if (mounted) {
        setState(() {
          _continueLevel = level;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _staggerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _resetNav();
      ref.read(streakRepositoryProvider.notifier).refreshStreakStatus();
      ref.read(streakRepositoryProvider.notifier).syncReminders(
            ref.read(notificationServiceProvider),
          );
      _loadContinueLevel();
    }
  }

  bool _canNavigate() {
    final now = DateTime.now();
    if (_isNavigating) return false;
    if (_lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(milliseconds: 500)) {
      return false;
    }
    _lastNavTime = now;
    _isNavigating = true;
    return true;
  }

  void _resetNav() {
    if (mounted) {
      setState(() {
        _isNavigating = false;
      });
    }
  }

  void _onPlay(int levelId) {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.play(levelId)).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  void _onDailyThread() {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    final dailyLevelId = DailyThreadService.getDailyLevelId();
    context.push(Routes.play(dailyLevelId)).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  void _onBrowseLevels() {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.levels).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  void _onAchievements() {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.achievements).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  void _onSettings() {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.settings).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  Widget _staggeredItem({
    required int index,
    required Widget child,
    required bool reduceMotion,
  }) {
    if (reduceMotion) return child;

    // Stagger 60 ms apart, 320 ms each
    final startTime = (index * 60) / 680.0;
    final endTime = ((index * 60) + 320) / 680.0;
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(
        startTime.clamp(0.0, 1.0),
        endTime.clamp(0.0, 1.0),
        curve: Primitives.curveEnter,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final dy = (1.0 - animation.value) * 16.0;
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = ref.watch(progressProvider);
    final streak = ref.watch(streakRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final reduceMotion = settings.reduceMotion;
    final snapshot = ref.watch(snapshotRepositoryProvider).getSnapshot();

    final currentStreak = streak.currentStreak;
    final currentLevel =
        (snapshot != null && snapshot.levelId <= progress.highestUnlocked)
            ? snapshot.levelId.clamp(1, 200)
            : progress.highestUnlocked.clamp(1, 200);

    final chapterIdx = ((currentLevel - 1) ~/ 20).clamp(0, _chapterNames.length - 1);
    final chapterName = _chapterNames[chapterIdx];
    final chapterLevelNum = ((currentLevel - 1) % 20) + 1;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 24.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Top Bar (56 dp)
                    _staggeredItem(
                      index: 0,
                      reduceMotion: reduceMotion,
                      child: SizedBox(
                        height: 56.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Streak Chip with custom flame
                            Semantics(
                              button: true,
                              label: 'Daily streak: $currentStreak days',
                              child: InkWell(
                                onTap: () {
                                  ref.read(hapticsServiceProvider).selection();
                                  showStreakWeekSheet(context);
                                },
                                borderRadius: BorderRadius.circular(AppTokens.radius16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0,
                                    vertical: 8.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tokens.surface,
                                    borderRadius:
                                        BorderRadius.circular(AppTokens.radius16),
                                    border: Border.all(
                                      color: currentStreak > 0
                                          ? tokens.accent.withValues(alpha: 0.4)
                                          : tokens.line,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      StreakFlame(
                                        size: 18.0,
                                        color: currentStreak > 0
                                            ? tokens.accent
                                            : tokens.inkMuted,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text(
                                        '$currentStreak',
                                        style: tokens.typography.label.copyWith(
                                          color: currentStreak > 0
                                              ? tokens.ink
                                              : tokens.inkMuted,
                                          fontWeight: FontWeight.w700,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Right: Achievements & Settings Buttons (48 dp circular)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _CircularIconButton(
                                  icon: Icons.emoji_events_outlined,
                                  tooltip: 'Achievements',
                                  tokens: tokens,
                                  onPressed: _onAchievements,
                                ),
                                const SizedBox(width: 10.0),
                                _CircularIconButton(
                                  icon: Icons.settings_outlined,
                                  tooltip: 'Settings',
                                  tokens: tokens,
                                  onPressed: _onSettings,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Hero: Living Board Plate (~42% height, centered)
                    _staggeredItem(
                      index: 1,
                      reduceMotion: reduceMotion,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft radial stage light
                            if (tokens.isDark)
                              Container(
                                width: 330.0,
                                height: 330.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      tokens.accent.withValues(alpha: 0.08),
                                      tokens.accent.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            HomeAttractBoard(reduceMotion: reduceMotion),
                          ],
                        ),
                      ),
                    ),

                    // 3. Wordmark & Tagline
                    _staggeredItem(
                      index: 2,
                      reduceMotion: reduceMotion,
                      child: Column(
                        children: [
                          const ArrowZWordmark(
                            fontSize: 34.0,
                            animateOnLaunch: true,
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            'Pull every thread free.',
                            style: tokens.typography.body.copyWith(
                              color: tokens.inkMuted,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8.0),

                    // 4. Continue Card (surfaceRaised, radius 24)
                    _staggeredItem(
                      index: 3,
                      reduceMotion: reduceMotion,
                      child: InkWell(
                        onTap: () => _onPlay(currentLevel),
                        borderRadius: BorderRadius.circular(AppTokens.radius24),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: tokens.surfaceRaised,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radius24),
                            border: Border.all(color: tokens.line),
                          ),
                          child: Row(
                            children: [
                              // 64 dp miniature of actual next level
                              Container(
                                width: 64.0,
                                height: 64.0,
                                decoration: BoxDecoration(
                                  color: tokens.surface,
                                  borderRadius:
                                      BorderRadius.circular(AppTokens.radius16),
                                  border: Border.all(color: tokens.line),
                                ),
                                child: _continueLevel != null
                                    ? LevelMiniatureTile(
                                        level: _continueLevel,
                                        size: 64.0,
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: tokens.accent,
                                          size: 28.0,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16.0),
                              // Level progress details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chapterName,
                                      style: tokens.typography.caption.copyWith(
                                        color: tokens.inkMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      'Level $currentLevel',
                                      style: tokens.typography.display.copyWith(
                                        fontSize: 22.0,
                                        color: tokens.ink,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    // Segmented chapter progress (x of 20)
                                    Row(
                                      children: List.generate(20, (i) {
                                        final isFilled = i < chapterLevelNum;
                                        return Expanded(
                                          child: Container(
                                            height: 3.0,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1.0),
                                            decoration: BoxDecoration(
                                              color: isFilled
                                                  ? tokens.accent
                                                  : tokens.surface,
                                              borderRadius:
                                                  BorderRadius.circular(1.5),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12.0),

                    // 5. Primary button "Play" (64 dp)
                    _staggeredItem(
                      index: 4,
                      reduceMotion: reduceMotion,
                      child: PrimaryPlayButton(
                        label: 'Play',
                        reduceMotion: reduceMotion,
                        onPressed: () => _onPlay(currentLevel),
                      ),
                    ),

                    const SizedBox(height: 12.0),

                    // 6. Secondary Row of Two Cards (equal width, 88 dp)
                    _staggeredItem(
                      index: 5,
                      reduceMotion: reduceMotion,
                      child: Row(
                        children: [
                          // Daily Thread Card
                          Expanded(
                            child: _SecondaryActionCard(
                              title: 'Daily Thread',
                              subtitle: streak.completedToday
                                  ? 'Cleared'
                                  : 'Ready to play',
                              accentIcon: StreakFlame(
                                size: 20.0,
                                color: streak.completedToday
                                    ? tokens.accent
                                    : tokens.accent.withValues(alpha: 0.8),
                              ),
                              tokens: tokens,
                              onPressed: _onDailyThread,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          // Levels Card
                          Expanded(
                            child: _SecondaryActionCard(
                              title: 'Levels',
                              subtitle: '$currentLevel of 200',
                              accentIcon: Icon(
                                Icons.grid_view_rounded,
                                size: 20.0,
                                color: tokens.accent,
                              ),
                              tokens: tokens,
                              onPressed: _onBrowseLevels,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CircularIconButton extends StatelessWidget {
  const _CircularIconButton({
    required this.icon,
    required this.tooltip,
    required this.tokens,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final AppTokens tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.0,
      height: 48.0,
      decoration: BoxDecoration(
        color: tokens.surface,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.line),
      ),
      child: IconButton(
        icon: Icon(icon, color: tokens.ink, size: 20.0),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _SecondaryActionCard extends StatelessWidget {
  const _SecondaryActionCard({
    required this.title,
    required this.subtitle,
    required this.accentIcon,
    required this.tokens,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final Widget accentIcon;
  final AppTokens tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(color: tokens.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                accentIcon,
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13.0,
                  color: tokens.inkMuted,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tokens.typography.label.copyWith(
                    color: tokens.ink,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: tokens.typography.caption.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
