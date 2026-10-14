import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/stats_and_snapshot_models.dart';
import 'package:arrowtapout/design/theme_provider.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/features/home/home_screen.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestLobby({
    ProgressState? progressState,
    LevelSnapshot? snapshot,
    AppThemeMode themeMode = AppThemeMode.sageLinen,
    GoRouter? router,
  }) {
    SharedPreferences.setMockInitialValues({});

    final progress = progressState ?? const ProgressState();
    final dummyRepo = ProgressRepository(null);
    dummyRepo.state = progress;

    return ProviderScope(
      overrides: [
        progressProvider.overrideWith((ref) => dummyRepo),
        snapshotRepositoryProvider.overrideWithValue(
          _MockSnapshotRepository(snapshot),
        ),
        playUpdateServiceProvider.overrideWithValue(NoOpUpdateService()),
        themeModeProvider.overrideWith((ref) => themeMode),
      ],
      child: router != null
          ? MaterialApp.router(
              routerConfig: router,
              theme: AppThemes.buildThemeData(
                AppThemes.tokensFor(themeMode, Brightness.light),
                isDark: themeMode.isDark,
              ),
            )
          : MaterialApp(
              theme: AppThemes.buildThemeData(
                AppThemes.tokensFor(themeMode, Brightness.light),
                isDark: themeMode.isDark,
              ),
              home: const HomeScreen(),
            ),
    );
  }

  group('ArrowZ Lobby Screen Acceptance Criteria', () {
    testWidgets(
        '1. Fresh installation displays ArrowZ, Level 1, Play, and Settings',
        (tester) async {
      await tester.pumpWidget(buildTestLobby());
      await tester.pumpAndSettle();

      // Only the 4 essential elements
      expect(find.byKey(const Key('lobby_game_title')), findsOneWidget);
      expect(find.text('ArrowZ'), findsOneWidget);

      expect(find.byKey(const Key('lobby_level_number')), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);

      expect(find.byKey(const Key('lobby_play_button')), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);

      expect(find.byKey(const Key('lobby_settings_button')), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('2. Saved progress displays the correct next level',
        (tester) async {
      const savedProgress = ProgressState(
        highestUnlocked: 42,
        stars: {1: 3, 2: 3},
      );

      await tester.pumpWidget(buildTestLobby(progressState: savedProgress));
      await tester.pumpAndSettle();

      expect(find.text('Level 42'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets(
        '3. Resumable in-progress level is displayed when snapshot exists',
        (tester) async {
      const savedProgress = ProgressState(
        highestUnlocked: 20,
        stars: {},
      );
      const activeSnapshot = LevelSnapshot(
        levelId: 7,
        activeThreadIds: {1, 2},
        mistakes: 1,
        hintsUsed: 0,
        savedAtMs: 1234567,
      );

      await tester.pumpWidget(buildTestLobby(
        progressState: savedProgress,
        snapshot: activeSnapshot,
      ));
      await tester.pumpAndSettle();

      // Should show in-progress Level 7 instead of 20
      expect(find.text('Level 7'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('4. Tapping Play launches the correct playable level route',
        (tester) async {
      String? navigatedLocation;

      final testRouter = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/play/:id',
            builder: (context, state) {
              navigatedLocation = state.uri.toString();
              return Scaffold(
                  body: Text('Playing Level ${state.pathParameters['id']}'));
            },
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const Scaffold(body: Text('Settings')),
          ),
        ],
      );

      const savedProgress = ProgressState(highestUnlocked: 15);
      await tester.pumpWidget(buildTestLobby(
        progressState: savedProgress,
        router: testRouter,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lobby_play_button')));
      await tester.pumpAndSettle();

      expect(navigatedLocation, equals('/play/15'));
      expect(find.text('Playing Level 15'), findsOneWidget);
    });

    testWidgets('5. Rapid repeated Play taps do not create duplicate routes',
        (tester) async {
      int playRoutePushes = 0;

      final testRouter = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/play/:id',
            builder: (context, state) {
              playRoutePushes++;
              return const Scaffold(body: Text('Play Screen'));
            },
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const Scaffold(body: Text('Settings')),
          ),
        ],
      );

      await tester.pumpWidget(buildTestLobby(router: testRouter));
      await tester.pump();

      // Rapid successive taps before animation/settling
      await tester.tap(find.byKey(const Key('lobby_play_button')));
      await tester.tap(find.byKey(const Key('lobby_play_button')));
      await tester.tap(find.byKey(const Key('lobby_play_button')));
      await tester.pumpAndSettle();

      // Guard should ensure only 1 route was pushed
      expect(playRoutePushes, equals(1));
    });

    testWidgets('6. Tapping Settings button opens the Settings screen',
        (tester) async {
      String? navigatedLocation;

      final testRouter = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) {
              navigatedLocation = state.uri.toString();
              return const Scaffold(body: Text('Settings Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(buildTestLobby(router: testRouter));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lobby_settings_button')));
      await tester.pumpAndSettle();

      expect(navigatedLocation, equals('/settings'));
      expect(find.text('Settings Screen'), findsOneWidget);
    });

    testWidgets(
        '7. Screen contains NO obsolete lobby actions, buttons, or content',
        (tester) async {
      await tester.pumpWidget(buildTestLobby());
      await tester.pumpAndSettle();

      // Obsolete buttons removed
      expect(find.text('Stats'), findsNothing);
      expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
      expect(find.text('Levels'), findsNothing);
      expect(find.text('How to play'), findsNothing);
      expect(find.text('Continue'), findsNothing);

      // Obsolete chapter names removed
      expect(find.text('First Threads'), findsNothing);
      expect(find.text('Loose Ends'), findsNothing);

      // No promotional cards, level grids, or daily reward widgets
      expect(find.byType(Card), findsNothing);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets(
        '8. Lobby renders consistently across all 5 themes without error',
        (tester) async {
      final themes = [
        AppThemeMode.sageLinen,
        AppThemeMode.inkAndBrass,
        AppThemeMode.fogSlate,
        AppThemeMode.rosewood,
        AppThemeMode.graphiteEmber,
      ];

      for (final mode in themes) {
        await tester.pumpWidget(buildTestLobby(themeMode: mode));
        await tester.pumpAndSettle();

        expect(find.text('ArrowZ'), findsOneWidget);
        expect(find.text('Play'), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('9. Small screen and large text scaler do not cause overflow',
        (tester) async {
      // 320x480 small screen
      tester.view.physicalSize = const Size(320.0, 480.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320.0, 480.0),
            textScaler: TextScaler.linear(1.3),
          ),
          child: buildTestLobby(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ArrowZ'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. Player progress is preserved through UI lifecycle',
        (tester) async {
      const savedProgress = ProgressState(
        highestUnlocked: 88,
        stars: {1: 3, 2: 3, 3: 2},
        hintBank: 6,
        stats: GameStats(levelsCleared: 3, totalStars: 8),
      );

      await tester.pumpWidget(buildTestLobby(progressState: savedProgress));
      await tester.pumpAndSettle();

      expect(find.text('Level 88'), findsOneWidget);
      expect(savedProgress.highestUnlocked, equals(88));
      expect(savedProgress.stars.length, equals(3));
      expect(savedProgress.hintBank, equals(6));
      expect(savedProgress.stats.levelsCleared, equals(3));
    });
  });
}

class _MockSnapshotRepository implements SnapshotRepository {
  _MockSnapshotRepository(this._snapshot);
  final LevelSnapshot? _snapshot;

  @override
  LevelSnapshot? getSnapshot() => _snapshot;

  @override
  Future<void> saveSnapshot({
    required int levelId,
    required Set<int> activeThreadIds,
    required int mistakes,
    required int hintsUsed,
  }) async {}

  @override
  Future<void> clearSnapshot() async {}
}
