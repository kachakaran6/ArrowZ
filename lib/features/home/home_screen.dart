import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Minimal, elegant lobby screen for ArrowZ.
///
/// Contains the core four elements: Game Name, Level Number, Play, Settings,
/// plus a restrained consecutive-day Streak indicator.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Check Play in-app updates and sync streak status at session start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(playUpdateServiceProvider).checkForUpdates(context);
        ref.read(streakRepositoryProvider.notifier).refreshStreakStatus();
        ref.read(streakRepositoryProvider.notifier).syncReminders(
              ref.read(notificationServiceProvider),
            );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(streakRepositoryProvider.notifier).refreshStreakStatus();
      ref.read(streakRepositoryProvider.notifier).syncReminders(
            ref.read(notificationServiceProvider),
          );
    }
  }

  void _onPlay(int levelId) {
    if (_isNavigating) return;
    _isNavigating = true;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.play(levelId)).then((_) {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  void _onStreak() {
    if (_isNavigating) return;
    _isNavigating = true;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.streak).then((_) {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  void _onSettings() {
    if (_isNavigating) return;
    _isNavigating = true;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.settings).then((_) {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = ref.watch(progressProvider);
    final streak = ref.watch(streakRepositoryProvider);
    final snapshot = ref.watch(snapshotRepositoryProvider).getSnapshot();
    final currentStreak = streak.currentStreak;

    // Derive active level: if an active in-progress snapshot exists for an unlocked level,
    // resume that level; otherwise launch the player's next unlocked level.
    final currentLevel =
        (snapshot != null && snapshot.levelId <= progress.highestUnlocked)
            ? snapshot.levelId.clamp(1, 200)
            : progress.highestUnlocked.clamp(1, 200);

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Primitives.space24,
                    vertical: Primitives.space16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Row: Restrained Streak indicator on the left, Settings on the right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Streak: $currentStreak days',
                            child: InkWell(
                              key: const Key('lobby_streak_button'),
                              onTap: _onStreak,
                              borderRadius: BorderRadius.circular(
                                  Primitives.radiusButton),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Primitives.space12,
                                  vertical: Primitives.space8,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 22.0,
                                      color: currentStreak > 0
                                          ? tokens.accent
                                          : tokens.inkMuted,
                                    ),
                                    const SizedBox(width: Primitives.space4),
                                    Text(
                                      '$currentStreak',
                                      key: const Key('lobby_streak_text'),
                                      style: tokens.typography.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: currentStreak > 0
                                            ? tokens.ink
                                            : tokens.inkMuted,
                                        fontSize: 15.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('lobby_settings_button'),
                            icon: Icon(
                              Icons.settings_outlined,
                              color: tokens.ink,
                              size: 24.0,
                            ),
                            tooltip: 'Settings',
                            onPressed: _onSettings,
                          ),
                        ],
                      ),

                      const Spacer(flex: 2),

                      // Center: Game Name & Level Number
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ArrowZ',
                              key: const Key('lobby_game_title'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: Primitives.fontDisplay,
                                fontSize: 44.0,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                color: tokens.ink,
                              ),
                            ),
                            const SizedBox(height: Primitives.space12),
                            Text(
                              'Level $currentLevel',
                              key: const Key('lobby_level_number'),
                              textAlign: TextAlign.center,
                              style: tokens.typography.heading.copyWith(
                                color: tokens.inkMuted,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Bottom: Primary Play Action
                      FilledButton(
                        key: const Key('lobby_play_button'),
                        onPressed: () => _onPlay(currentLevel),
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.accent,
                          foregroundColor: tokens.onAccent,
                          minimumSize: const Size.fromHeight(56.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Primitives.radiusButton,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Play',
                          style: tokens.typography.label.copyWith(
                            color: tokens.onAccent,
                            fontSize: 17.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: Primitives.space16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
