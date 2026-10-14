import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/features/dev/animation_lab_screen.dart';
import 'package:arrowtapout/features/game/game_screen.dart';
import 'package:arrowtapout/features/home/home_screen.dart';
import 'package:arrowtapout/features/howto/howto_screen.dart';
import 'package:arrowtapout/features/levels/levels_screen.dart';
import 'package:arrowtapout/features/settings/settings_screen.dart';
import 'package:arrowtapout/features/settings/theme_picker_screen.dart';
import 'package:arrowtapout/features/splash/splash_screen.dart';
import 'package:arrowtapout/features/stats/stats_screen.dart';
import 'package:arrowtapout/features/streak/streak_screen.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:arrowtapout/router/transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: [
      // Splash
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      // Home
      GoRoute(
        path: Routes.home,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const HomeScreen(),
        ),
      ),
      // Levels
      GoRoute(
        path: Routes.levels,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const LevelsScreen(),
        ),
      ),
      // Play
      GoRoute(
        path: '/play/:id',
        redirect: (context, state) {
          final idParam = state.pathParameters['id'];
          final id = int.tryParse(idParam ?? '');
          if (id == null || id < 1 || id > 200) {
            return Routes.levels;
          }
          final highest = ref.read(progressProvider).highestUnlocked;
          if (id > highest) {
            return Routes.levels;
          }
          return null;
        },
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return buildGamePage(
            context: context,
            state: state,
            child: GameScreen(levelId: id),
          );
        },
      ),
      // Settings
      GoRoute(
        path: Routes.settings,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
        routes: [
          // Theme picker (/settings/theme)
          GoRoute(
            path: 'theme',
            pageBuilder: (context, state) => buildFadeThroughPage(
              context: context,
              state: state,
              child: const ThemePickerScreen(),
            ),
          ),
        ],
      ),
      // How to play
      GoRoute(
        path: Routes.howToPlay,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const HowToPlayScreen(),
        ),
      ),
      // Stats
      GoRoute(
        path: Routes.stats,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const StatsScreen(),
        ),
      ),
      // Daily Streak
      GoRoute(
        path: Routes.streak,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const StreakScreen(),
        ),
      ),
      // Animation Dev Lab
      GoRoute(
        path: Routes.devLab,
        pageBuilder: (context, state) => buildFadeThroughPage(
          context: context,
          state: state,
          child: const AnimationLabScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => const HomeScreen(),
  );
});
