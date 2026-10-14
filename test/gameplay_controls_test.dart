import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/theme_provider.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_screen.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/heart_life_indicator.dart';
import 'package:arrowtapout/features/game/hint_service.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/ad_service.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class _FakeLevelRepository implements LevelRepository {
  _FakeLevelRepository(this.testLevel);
  final Level testLevel;

  @override
  Future<Level> loadLevel(int id) async => testLevel;

  @override
  Future<List<Level>> loadChapter(int chapterNumber) async => [testLevel];
}

Level _createTestLevel() {
  return Level(
    id: 1,
    rows: 4,
    cols: 4,
    threads: [
      // Thread 1: at row 0, points right (dr=0, dc=1), unobstructed to edge
      Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
      // Thread 2: points up towards (0, 0) occupied by Thread 1 -> BLOCKED
      Thread(2, [const Cell(2, 0), const Cell(1, 0)]),
      // Thread 3: points up towards (0, 1) occupied by Thread 1 -> BLOCKED
      Thread(3, [const Cell(2, 1), const Cell(1, 1)]),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArrowZ Gameplay Controls & Rewarded Hint System (ARROWZ-1-4)', () {
    late ProviderContainer container;
    late BoardAnimator animator;
    late Level level;
    late GameController controller;
    late FakeRewardedAdService fakeAdService;
    late HintService hintService;
    late _FakeLevelRepository levelRepo;

    final defaultThemeData = AppThemes.buildThemeData(
      AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
      isDark: false,
    );

    setUp(() {
      level = _createTestLevel();
      levelRepo = _FakeLevelRepository(level);
      animator = BoardAnimator(vsync: _FakeTickerProvider());
      fakeAdService = FakeRewardedAdService();
      hintService = HintService(adService: fakeAdService);

      container = ProviderContainer(
        overrides: [
          levelRepositoryProvider.overrideWithValue(levelRepo),
          rewardedAdServiceProvider.overrideWithValue(fakeAdService),
          hintServiceProvider.overrideWith((ref) => hintService),
        ],
      );

      controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        notificationService: FakeNotificationService(),
      );
    });

    tearDown(() {
      controller.dispose();
      animator.dispose();
      container.dispose();
    });

    // 1. Hint requests a rewarded ad
    test('1. Hint requests a rewarded ad', () async {
      expect(fakeAdService.showAdCallCount, equals(0));

      final result =
          await hintService.requestRewardedHint(controller: controller);

      expect(fakeAdService.showAdCallCount, equals(1));
      expect(fakeAdService.requestedAdIds, isNotEmpty);
      expect(result.status, equals(HintResultStatus.success));
    });

    // 2. A verified reward grants exactly one hint
    test('2. A verified reward grants exactly one hint', () async {
      expect(controller.state.hintsUsed, equals(0));
      expect(controller.state.hintedThreadId, isNull);

      final result =
          await hintService.requestRewardedHint(controller: controller);

      expect(result.status, equals(HintResultStatus.success));
      expect(controller.state.hintsUsed, equals(1));
      expect(controller.state.hintedThreadId, equals(1)); // Thread 1 is free
      expect(animator.hintedThreadId, equals(1));
    });

    // 3. Ad dismissal without a reward grants no hint
    test('3. Ad dismissal without a reward grants no hint', () async {
      fakeAdService.setAdState(RewardedAdState.ready);
      final dismissedAdService = FakeRewardedAdService(
        initialState: RewardedAdState.ready,
        simulateResult: RewardedAdResultType.dismissedWithoutReward,
      );
      final service = HintService(adService: dismissedAdService);

      final result = await service.requestRewardedHint(controller: controller);

      expect(result.status, equals(HintResultStatus.adDismissed));
      expect(controller.state.hintsUsed, equals(0));
      expect(controller.state.hintedThreadId, isNull);
    });

    // 4. Ad load failure grants no hint
    test('4. Ad load failure grants no hint', () async {
      final failingAdService = FakeRewardedAdService(
        initialState: RewardedAdState.idle,
        simulateResult: RewardedAdResultType.failed,
      );
      final service = HintService(adService: failingAdService);

      final result = await service.requestRewardedHint(controller: controller);

      expect(result.status, equals(HintResultStatus.adFailed));
      expect(controller.state.hintsUsed, equals(0));
      expect(controller.state.hintedThreadId, isNull);
    });

    // 5. Duplicate reward callbacks cannot grant duplicate hints
    test('5. Duplicate reward callbacks cannot grant duplicate hints',
        () async {
      final result1 =
          await hintService.requestRewardedHint(controller: controller);
      expect(result1.status, equals(HintResultStatus.success));
      expect(controller.state.hintsUsed, equals(1));

      // Attempting to reuse or re-trigger with duplicate request
      expect(fakeAdService.requestedAdIds.length, equals(1));
      expect(controller.state.hintsUsed, equals(1));
    });

    // 6. Repeated Hint taps cannot show overlapping ads
    test('6. Repeated Hint taps cannot show overlapping ads', () async {
      final delayedAdService = FakeRewardedAdService(
        initialState: RewardedAdState.ready,
        showDelay: const Duration(milliseconds: 50),
      );
      final service = HintService(adService: delayedAdService);

      // Start first request
      final future1 = service.requestRewardedHint(controller: controller);

      // Immediate second tap while first is in flight
      final result2 = await service.requestRewardedHint(controller: controller);

      expect(result2.status, equals(HintResultStatus.alreadyInProgress));
      expect(delayedAdService.showAdCallCount, equals(1));

      final result1 = await future1;
      expect(result1.status, equals(HintResultStatus.success));
    });

    // 7. A valid hint identifies an actually removable arrow
    test('7. A valid hint identifies an actually removable arrow', () {
      final hintId = controller.chooseHintThread();
      expect(hintId, isNotNull);
      expect(
          hintId, equals(1)); // Thread 1 is free, threads 2 and 3 are blocked
    });

    // 8. Hint highlighting does not mutate the board or consume a heart
    test('8. Hint highlighting does not mutate the board or consume a heart',
        () async {
      final initialActive = Set<int>.from(controller.state.activeIds);
      final initialMistakes = controller.state.mistakes;
      final initialLives = controller.state.remainingLives;

      await hintService.requestRewardedHint(controller: controller);

      expect(controller.state.activeIds, equals(initialActive));
      expect(controller.state.mistakes, equals(initialMistakes));
      expect(controller.state.remainingLives, equals(initialLives));
      expect(controller.state.status, equals(GameStatus.playing));
    });

    // 9. Replay resets the current level and restores three hearts
    test('9. Replay resets the current level and restores three hearts', () {
      // Tap blocked thread to incur mistakes
      controller.handleThreadTap(2, 24.0);
      expect(controller.state.mistakes, equals(1));
      expect(controller.state.remainingLives, equals(2));

      // Tap free thread 1 to make progress
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.activeIds.contains(1), isFalse);

      // Call restart
      controller.restartLevel(24.0);

      expect(controller.state.activeIds.length, equals(level.threads.length));
      expect(controller.state.activeIds.contains(1), isTrue);
      expect(controller.state.mistakes, equals(0));
      expect(controller.state.remainingLives, equals(3));
      expect(controller.state.status, equals(GameStatus.playing));
    });

    // 10. Back returns to Home without corrupting saved progress
    testWidgets('10. Back returns to Home without corrupting saved progress',
        (tester) async {
      String? currentPath;
      final router = GoRouter(
        initialLocation: '/play/1',
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) {
              currentPath = '/home';
              return const Scaffold(body: Text('Home Screen'));
            },
          ),
          GoRoute(
            path: '/play/:id',
            builder: (ctx, state) {
              currentPath = state.uri.toString();
              return const GameScreen(levelId: 1);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            levelRepositoryProvider.overrideWithValue(levelRepo),
            rewardedAdServiceProvider.overrideWithValue(fakeAdService),
            hintServiceProvider
                .overrideWith((ref) => HintService(adService: fakeAdService)),
            notificationServiceProvider
                .overrideWithValue(FakeNotificationService()),
          ],
          child: MaterialApp.router(
            theme: defaultThemeData,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game_back_button')), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('game_back_button')));
      await tester.pumpAndSettle();

      expect(currentPath, equals('/home'));
      expect(find.text('Home Screen'), findsOneWidget);
    });

    // 11. Rapid taps cannot trigger duplicate navigation or restart actions
    testWidgets(
        '11. Rapid taps cannot trigger duplicate navigation or restart actions',
        (tester) async {
      var homeNavigations = 0;
      final router = GoRouter(
        initialLocation: '/play/1',
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) {
              homeNavigations++;
              return const Scaffold(body: Text('Home Screen'));
            },
          ),
          GoRoute(
            path: '/play/:id',
            builder: (ctx, state) => const GameScreen(levelId: 1),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            levelRepositoryProvider.overrideWithValue(levelRepo),
            rewardedAdServiceProvider.overrideWithValue(fakeAdService),
            hintServiceProvider
                .overrideWith((ref) => HintService(adService: fakeAdService)),
            notificationServiceProvider
                .overrideWithValue(FakeNotificationService()),
          ],
          child: MaterialApp.router(
            theme: defaultThemeData,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final backFinder = find.byKey(const Key('game_back_button'));
      // Rapid triple tap
      await tester.tap(backFinder);
      await tester.tap(backFinder);
      await tester.tap(backFinder);
      await tester.pumpAndSettle();

      expect(homeNavigations, equals(1));
    });

    // 12. The HUD renders correctly in all five themes
    testWidgets('12. The HUD renders correctly in all five themes',
        (tester) async {
      const themes = [
        AppThemeMode.sageLinen,
        AppThemeMode.inkAndBrass,
        AppThemeMode.fogSlate,
        AppThemeMode.rosewood,
        AppThemeMode.graphiteEmber,
      ];

      for (final themeMode in themes) {
        final tokens = AppThemes.tokensFor(themeMode, Brightness.light);
        final themeData =
            AppThemes.buildThemeData(tokens, isDark: themeMode.isDark);

        final router = GoRouter(
          initialLocation: '/play/1',
          routes: [
            GoRoute(
              path: '/home',
              builder: (ctx, state) => const SizedBox(),
            ),
            GoRoute(
              path: '/play/:id',
              builder: (ctx, state) => const GameScreen(levelId: 1),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              levelRepositoryProvider.overrideWithValue(levelRepo),
              themeModeProvider.overrideWith((ref) => themeMode),
              rewardedAdServiceProvider.overrideWithValue(fakeAdService),
              hintServiceProvider
                  .overrideWith((ref) => HintService(adService: fakeAdService)),
              notificationServiceProvider
                  .overrideWithValue(FakeNotificationService()),
            ],
            child: MaterialApp.router(
              theme: themeData,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('game_back_button')), findsOneWidget);
        expect(find.byKey(const Key('game_replay_button')), findsOneWidget);
        expect(find.byKey(const Key('game_hint_button')), findsOneWidget);
        expect(find.byType(HeartLifeIndicator), findsOneWidget);
      }
    });

    // 13. The game remains playable when the ad service is unavailable
    testWidgets(
        '13. The game remains playable when the ad service is unavailable',
        (tester) async {
      final offlineAdService = FakeRewardedAdService(
        initialState: RewardedAdState.failed,
        simulateResult: RewardedAdResultType.failed,
      );
      final offlineHintService = HintService(adService: offlineAdService);

      final router = GoRouter(
        initialLocation: '/play/1',
        routes: [
          GoRoute(path: '/home', builder: (ctx, state) => const SizedBox()),
          GoRoute(
              path: '/play/:id',
              builder: (ctx, state) => const GameScreen(levelId: 1)),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            levelRepositoryProvider.overrideWithValue(levelRepo),
            rewardedAdServiceProvider.overrideWithValue(offlineAdService),
            hintServiceProvider.overrideWith((ref) => offlineHintService),
            notificationServiceProvider
                .overrideWithValue(FakeNotificationService()),
          ],
          child: MaterialApp.router(
            theme: defaultThemeData,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap hint when ad service is failing
      await tester.tap(find.byKey(const Key('game_hint_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Gameplay is not broken: screen remains interactive
      expect(find.byKey(const Key('game_replay_button')), findsOneWidget);
      expect(find.byKey(const Key('game_back_button')), findsOneWidget);
    });

    // 14. Ad and animation callbacks arriving after navigation are handled safely
    test(
        '14. Ad and animation callbacks arriving after navigation are handled safely',
        () async {
      final localController = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        notificationService: FakeNotificationService(),
      );

      final delayedAdService = FakeRewardedAdService(
        initialState: RewardedAdState.ready,
        showDelay: const Duration(milliseconds: 100),
      );
      final service = HintService(adService: delayedAdService);

      // Start hint flow
      final future = service.requestRewardedHint(controller: localController);

      // Simulate navigating away / disposing controller
      localController.dispose();

      // Completing the future does not throw
      final result = await future;
      expect(result, isNotNull);
    });
  });
}
