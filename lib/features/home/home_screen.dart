import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Minimal, elegant lobby screen for ArrowZ.
///
/// Contains exclusively four elements:
/// 1. Game Name: ArrowZ
/// 2. Level number: Current next/resumable level
/// 3. Play: Primary action
/// 4. Settings: Unobtrusive secondary action
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Check Play in-app updates at session start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(playUpdateServiceProvider).checkForUpdates(context);
      }
    });
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
    final snapshot = ref.watch(snapshotRepositoryProvider).getSnapshot();

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
                      // Top Row: Unobtrusive Settings button
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          key: const Key('lobby_settings_button'),
                          icon: Icon(
                            Icons.settings_outlined,
                            color: tokens.ink,
                            size: 24.0,
                          ),
                          tooltip: 'Settings',
                          onPressed: _onSettings,
                        ),
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
