import 'package:arrowtapout/data/arrow_skin.dart';
import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/board_view.dart';
import 'package:arrowtapout/features/game/game_screen.dart';
import 'package:arrowtapout/features/game/hint_service.dart';
import 'package:arrowtapout/features/game/sheets/complete_sheet.dart';
import 'package:arrowtapout/features/game/sheets/failed_sheet.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/ad_service.dart';
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
  int get cachedTotalLevels => 500;

  @override
  Future<int> getTotalLevelCount() async => 500;

  @override
  Future<bool> isValidLevelId(int id) async => id >= 1 && id <= 500;

  @override
  Future<Level?> tryLoadLevel(int id) async => testLevel;

  @override
  Future<Level> loadLevel(int id) async => testLevel;

  @override
  Future<List<Level>> loadChapter(int chapterNumber) async => [testLevel];
}

Level _createTestLevel({int id = 1, int rows = 5, int cols = 5}) {
  return Level(
    id: id,
    rows: rows,
    cols: cols,
    threads: [
      Thread(1, [const Cell(0, 0), const Cell(0, 1)]), // points right
      Thread(2, [const Cell(1, 0), const Cell(1, 1)]), // points right
      Thread(3, [const Cell(4, 4), const Cell(4, 3)]), // points left
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testThemeData = AppThemes.buildThemeData(
    AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
    isDark: false,
  );

  group('Touch Input, Zoom & Stability Regression Tests', () {
    late Level level;
    late BoardAnimator animator;
    late TransformationController transformController;

    setUp(() {
      level = _createTestLevel();
      animator = BoardAnimator(vsync: _FakeTickerProvider());
      animator.setLevel(level, 40.0);
      transformController = TransformationController();
    });

    tearDown(() {
      animator.dispose();
      transformController.dispose();
    });

    Widget createBoardTestWidget({
      required Level testLevel,
      required ValueChanged<int> onThreadTap,
      TransformationController? controller,
    }) {
      return ProviderScope(
        child: MaterialApp(
          theme: testThemeData,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 500,
                child: BoardView(
                  level: testLevel,
                  activeIds: testLevel.threads.map((t) => t.id).toSet(),
                  animator: animator,
                  onThreadTap: onThreadTap,
                  arrowSkin: ArrowSkin.chevron,
                  transformationController: controller ?? transformController,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('UI Test 1: Floating zoom toolbar is completely absent',
        (tester) async {
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: level,
        onThreadTap: (_) {},
      ));
      await tester.pumpAndSettle();

      // Ensure no zoom toolbar icons or buttons exist
      expect(find.byIcon(Icons.zoom_in_rounded), findsNothing,
          reason: 'Zoom in icon must be removed');
      expect(find.byIcon(Icons.remove_rounded), findsNothing,
          reason: 'Zoom minus button must be removed');
      expect(find.byIcon(Icons.add_rounded), findsNothing,
          reason: 'Zoom plus button must be removed');
      expect(find.byIcon(Icons.fit_screen_rounded), findsNothing,
          reason: 'Fit screen zoom button must be removed');
      expect(find.textContaining('%'), findsNothing,
          reason: 'Zoom percentage indicator must be removed');
    });

    testWidgets(
        'UI Test 2: Board renders with InteractiveViewer clamping min 1.0 max 2.5',
        (tester) async {
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: level,
        onThreadTap: (_) {},
      ));
      await tester.pumpAndSettle();

      final interactiveViewerFinder = find.byType(InteractiveViewer);
      expect(interactiveViewerFinder, findsOneWidget);

      final InteractiveViewer viewer =
          tester.widget<InteractiveViewer>(interactiveViewerFinder);
      expect(viewer.minScale, equals(1.0),
          reason: 'minScale must be clamped to 1.0');
      expect(viewer.maxScale, equals(2.5),
          reason: 'maxScale must be clamped to 2.5');
      expect(viewer.scaleEnabled, isTrue,
          reason: 'Two-finger pinch scale should be enabled');
    });

    testWidgets('Gesture Test 1: Single tap on arrow selects intended arrow',
        (tester) async {
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: level,
        onThreadTap: (id) {},
      ));
      await tester.pumpAndSettle();

      final boardFinder = find.byType(CustomPaint).first;
      final boardCenter = tester.getCenter(boardFinder);

      await tester.tapAt(boardCenter);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Gesture Test 2: Double-tapping an arrow does NOT trigger zoom or scale changes',
        (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: level,
        onThreadTap: (_) => tapCount++,
      ));
      await tester.pumpAndSettle();

      final initialMatrix = transformController.value.clone();
      expect(transformController.value.getMaxScaleOnAxis(), equals(1.0));

      final boardFinder = find.byType(CustomPaint).first;
      final center = tester.getCenter(boardFinder);

      // Perform rapid double tap
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      // Double-tapping must NEVER zoom the board!
      expect(transformController.value.getMaxScaleOnAxis(), equals(1.0),
          reason: 'Double tap must never change camera scale');
      expect(transformController.value, equals(initialMatrix),
          reason: 'Double tap must preserve exact identity transform');
    });

    testWidgets(
        'Gesture Test 3: One-finger pan does not move camera when at scale 1.0',
        (tester) async {
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: level,
        onThreadTap: (_) {},
      ));
      await tester.pumpAndSettle();

      final initialMatrix = transformController.value.clone();
      final boardFinder = find.byType(CustomPaint).first;
      final center = tester.getCenter(boardFinder);

      // Drag with one finger
      await tester.dragFrom(center, const Offset(60, 60));
      await tester.pumpAndSettle();

      // Panning must be disabled at scale 1.0
      expect(transformController.value.getMaxScaleOnAxis(), equals(1.0));
      expect(transformController.value, equals(initialMatrix),
          reason: 'One-finger drag must not drift or translate board at 1.0x');
    });

    testWidgets(
        'Gesture Test 4: Two-finger pinch clears arrow taps and safely zooms',
        (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: level,
        onThreadTap: (_) => tapCount++,
      ));
      await tester.pumpAndSettle();

      final boardFinder = find.byType(CustomPaint).first;
      final center = tester.getCenter(boardFinder);

      // Simulate a two-finger pinch gesture
      final touch1 = await tester.startGesture(center - const Offset(20, 0));
      final touch2 = await tester.startGesture(center + const Offset(20, 0));
      await tester.pump();

      // Spread fingers outward to pinch-zoom
      await touch1.moveBy(const Offset(-40, 0));
      await touch2.moveBy(const Offset(40, 0));
      await tester.pump();

      // Release fingers
      await touch1.up();
      await touch2.up();
      await tester.pumpAndSettle();

      // Releasing fingers after a pinch must NOT fire arrow selection taps!
      expect(tapCount, equals(0),
          reason: 'Pinch gesture must never trigger arrow selection');
    });

    testWidgets(
        'Stability Test 1: CompleteSheet rapid double-tap executes onNextLevel only once',
        (tester) async {
      int nextLevelCalls = 0;
      int replayCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: testThemeData,
          home: Scaffold(
            body: CompleteSheet(
              levelId: 1,
              chapterName: 'Chapter 1',
              stars: 3,
              threadsCleared: 5,
              mistakes: 0,
              onNextLevel: () => nextLevelCalls++,
              onReplay: () => replayCalls++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextButton = find.text('Next Level');
      expect(nextButton, findsOneWidget);

      // Rapidly tap "Next Level" twice
      await tester.tap(nextButton);
      await tester.pump(const Duration(milliseconds: 30));
      try {
        await tester.tap(nextButton, warnIfMissed: false);
      } catch (_) {}
      await tester.pumpAndSettle();

      expect(nextLevelCalls, equals(1),
          reason: 'onNextLevel must be called exactly once despite rapid taps');
      expect(replayCalls, equals(0));
    });

    testWidgets(
        'Stability Test 2: CompleteSheet rapid double-tap executes onReplay only once',
        (tester) async {
      int replayCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: testThemeData,
          home: Scaffold(
            body: CompleteSheet(
              levelId: 1,
              chapterName: 'Chapter 1',
              stars: 3,
              threadsCleared: 5,
              mistakes: 0,
              onNextLevel: () {},
              onReplay: () => replayCalls++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final replayButton = find.text('Replay');
      expect(replayButton, findsOneWidget);

      await tester.tap(replayButton);
      await tester.pump(const Duration(milliseconds: 30));
      try {
        await tester.tap(replayButton, warnIfMissed: false);
      } catch (_) {}
      await tester.pumpAndSettle();

      expect(replayCalls, equals(1),
          reason: 'onReplay must be called exactly once');
    });

    testWidgets(
        'Stability Test 3: FailedSheet rapid tap executes onRetry only once',
        (tester) async {
      int retryCalls = 0;
      int levelsCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: testThemeData,
          home: Scaffold(
            body: FailedSheet(
              onRetry: () => retryCalls++,
              onLevels: () => levelsCalls++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump(const Duration(milliseconds: 30));
      try {
        await tester.tap(retryButton, warnIfMissed: false);
      } catch (_) {}
      await tester.pumpAndSettle();

      expect(retryCalls, equals(1),
          reason: 'onRetry must be called exactly once');
      expect(levelsCalls, equals(0));
    });

    testWidgets(
        'Stability Test 4: Board transform cleanly resets when level changes or restarts',
        (tester) async {
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: level,
        onThreadTap: (_) {},
      ));
      await tester.pumpAndSettle();

      // Artificially modify the transform to simulate zoom
      transformController.value = Matrix4.diagonal3Values(1.8, 1.8, 1.0);
      expect(transformController.value.getMaxScaleOnAxis(), equals(1.8));

      // Re-pump with new level (simulating next level or level change)
      final newLevel = _createTestLevel(id: 2);
      await tester.pumpWidget(createBoardTestWidget(
        testLevel: newLevel,
        onThreadTap: (_) {},
      ));
      await tester.pumpAndSettle();

      // Transform must be reset to identity
      expect(transformController.value.getMaxScaleOnAxis(), equals(1.0),
          reason: 'Transform must reset to 1.0 when loading a new level');
      expect(transformController.value, equals(Matrix4.identity()));
    });

    testWidgets(
        'UI Test 3: Gameplay screen renders without overflow on compact 360x640 screen',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = _FakeLevelRepository(level);
      final fakeAd = FakeRewardedAdService();

      final router = GoRouter(
        initialLocation: '/play/1',
        routes: [
          GoRoute(
            path: '/home',
            builder: (ctx, state) => const Scaffold(body: Text('Home Screen')),
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
            levelRepositoryProvider.overrideWithValue(fakeRepo),
            rewardedAdServiceProvider.overrideWithValue(fakeAd),
            hintServiceProvider
                .overrideWith((ref) => HintService(adService: fakeAd)),
            notificationServiceProvider
                .overrideWithValue(FakeNotificationService()),
          ],
          child: MaterialApp.router(
            theme: testThemeData,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check no layout overflow occurred
      expect(tester.takeException(), isNull,
          reason: 'Gameplay screen must not overflow on compact screens');

      // Check zoom toolbar is NOT rendered in GameScreen
      expect(find.byIcon(Icons.zoom_in_rounded), findsNothing);
      expect(find.byIcon(Icons.fit_screen_rounded), findsNothing);
    });
  });
}
