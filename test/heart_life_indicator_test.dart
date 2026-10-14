import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/heart_life_indicator.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child, {ThemeData? theme}) {
    final defaultTheme = AppThemes.buildThemeData(
      AppThemes.sageLinenTokens,
      isDark: false,
    );
    return MaterialApp(
      theme: theme ?? defaultTheme,
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }

  group('HeartLifeIndicator Acceptance Tests (ARROWZ-1-3)', () {
    testWidgets('1. A new level displays three red hearts', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 3, reduceMotion: true),
        ),
      );
      await tester.pump();

      // Find all active heart keys
      expect(find.byKey(const ValueKey('active_heart_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('active_heart_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('active_heart_2')), findsOneWidget);

      // Verify no lost hearts are present
      expect(find.byKey(const ValueKey('lost_heart_0')), findsNothing);
      expect(find.byKey(const ValueKey('lost_heart_1')), findsNothing);
      expect(find.byKey(const ValueKey('lost_heart_2')), findsNothing);

      // Verify colors: all 3 active hearts are red
      final icons =
          tester.widgetList<Icon>(find.byIcon(Icons.favorite_rounded));
      expect(icons.length, equals(3));
      for (final icon in icons) {
        expect(icon.color, equals(const Color(0xFFE53935)));
      }
    });

    testWidgets('2. One wrong attempt changes exactly one heart to white',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 2, reduceMotion: true),
        ),
      );
      await tester.pump();

      // First two hearts are active red
      expect(find.byKey(const ValueKey('active_heart_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('active_heart_1')), findsOneWidget);

      // Third heart has turned into a lost white heart
      expect(find.byKey(const ValueKey('lost_heart_2')), findsOneWidget);

      // Verify lost heart fill is white and border outline is present
      final whiteHeart = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('lost_heart_2')),
          matching: find.byIcon(Icons.favorite_rounded),
        ),
      );
      expect(whiteHeart.color, equals(Colors.white));

      final borderHeart = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('lost_heart_2')),
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
      );
      expect(borderHeart, isNotNull);
    });

    testWidgets('3. Two wrong attempts leave one red heart', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 1, reduceMotion: true),
        ),
      );
      await tester.pump();

      // Exactly 1 red heart remaining
      expect(find.byKey(const ValueKey('active_heart_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('active_heart_1')), findsNothing);
      expect(find.byKey(const ValueKey('active_heart_2')), findsNothing);

      // 2 white hearts
      expect(find.byKey(const ValueKey('lost_heart_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('lost_heart_2')), findsOneWidget);
    });

    testWidgets(
        '4. Three wrong attempts show three white hearts and trigger game-over behavior',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 0, reduceMotion: true),
        ),
      );
      await tester.pump();

      // 0 active red hearts
      expect(find.byKey(const ValueKey('active_heart_0')), findsNothing);
      expect(find.byKey(const ValueKey('active_heart_1')), findsNothing);
      expect(find.byKey(const ValueKey('active_heart_2')), findsNothing);

      // 3 lost white hearts
      expect(find.byKey(const ValueKey('lost_heart_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('lost_heart_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('lost_heart_2')), findsOneWidget);

      // Test game logic: GameController triggers failed status on 3 mistakes
      final container = ProviderContainer();
      final animator = BoardAnimator(vsync: FakeTickerProvider());
      final level = Level(
        id: 10,
        rows: 4,
        cols: 4,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(1, 2), const Cell(0, 2)]),
        ],
      );
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: true,
      );

      // Attempt 1 (mistake 1)
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.remainingLives, equals(2));

      // Attempt 2 (mistake 2)
      controller.state = controller.state.copyWith(lastBlockedTapTimeMs: 0.0);
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.remainingLives, equals(1));

      // Attempt 3 (mistake 3 -> game over)
      controller.state = controller.state.copyWith(lastBlockedTapTimeMs: 0.0);
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.remainingLives, equals(0));
      expect(controller.state.status, equals(GameStatus.failed));

      animator.dispose();
      container.dispose();
    });

    test('5. A successful move does not consume a life', () {
      final container = ProviderContainer();
      final animator = BoardAnimator(vsync: FakeTickerProvider());
      final level = Level(
        id: 10,
        rows: 4,
        cols: 4,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(1, 2), const Cell(0, 2)]), // Thread 2 is free
        ],
      );
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );

      expect(controller.state.remainingLives, equals(3));

      // Tap free arrow 2
      controller.handleThreadTap(2, 24.0);

      expect(controller.state.moves, equals(1));
      expect(controller.state.mistakes, equals(0));
      expect(controller.state.remainingLives, equals(3));

      animator.dispose();
      container.dispose();
    });

    test('6. Duplicate callbacks cannot consume the same life twice', () {
      final container = ProviderContainer();
      final animator = BoardAnimator(vsync: FakeTickerProvider());
      final level = Level(
        id: 10,
        rows: 4,
        cols: 4,
        threads: [
          Thread(
              1, [const Cell(0, 0), const Cell(0, 1)]), // Blocked by Thread 2
          Thread(2, [const Cell(1, 2), const Cell(0, 2)]),
        ],
      );
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );

      expect(controller.state.remainingLives, equals(3));

      // First blocked tap
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.remainingLives, equals(2));

      // Immediate duplicate tap on same blocked arrow within 250ms
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.remainingLives, equals(2)); // Still 2!

      animator.dispose();
      container.dispose();
    });

    test('7. Restart restores the correct initial state', () {
      final container = ProviderContainer();
      final animator = BoardAnimator(vsync: FakeTickerProvider());
      final level = Level(
        id: 10,
        rows: 4,
        cols: 4,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
          Thread(2, [const Cell(1, 2), const Cell(0, 2)]),
        ],
      );
      final controller = GameController(
        level: level,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: container.read(progressProvider.notifier),
        snapshotRepo: container.read(snapshotRepositoryProvider),
        reduceMotion: false,
      );

      // Make a mistake
      controller.handleThreadTap(1, 24.0);
      expect(controller.state.remainingLives, equals(2));

      // Restart level
      controller.restartLevel(24.0);

      // Restores 3 lives
      expect(controller.state.mistakes, equals(0));
      expect(controller.state.remainingLives, equals(3));
      expect(controller.state.status, equals(GameStatus.playing));

      animator.dispose();
      container.dispose();
    });

    testWidgets(
        '8. The indicator renders correctly with all five existing themes',
        (tester) async {
      final allModes = [
        AppThemeMode.sageLinen,
        AppThemeMode.inkAndBrass,
        AppThemeMode.fogSlate,
        AppThemeMode.rosewood,
        AppThemeMode.graphiteEmber,
      ];

      for (final mode in allModes) {
        final theme = AppThemes.buildThemeData(
          AppThemes.tokensFor(mode, Brightness.light),
          isDark: mode.isDark,
        );
        await tester.pumpWidget(
          wrapWithTheme(
            const HeartLifeIndicator(remainingLives: 2, reduceMotion: true),
            theme: theme,
          ),
        );
        await tester.pump();

        expect(find.byType(HeartLifeIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Active hearts
        expect(find.byKey(const ValueKey('active_heart_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('active_heart_1')), findsOneWidget);

        // Lost white heart
        expect(find.byKey(const ValueKey('lost_heart_2')), findsOneWidget);
      }
    });

    testWidgets('9. The indicator does not overflow on narrow screens',
        (tester) async {
      // 320x568 screen (compact mobile phone viewport)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            width: 320,
            child: HeartLifeIndicator(remainingLives: 2, reduceMotion: true),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(HeartLifeIndicator), findsOneWidget);
    });

    testWidgets(
        '10. Accessibility labels report the correct remaining-life count',
        (tester) async {
      final handle = tester.ensureSemantics();

      // 3 of 3
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 3, reduceMotion: true),
        ),
      );
      await tester.pump();
      var node = tester.getSemantics(find.byType(HeartLifeIndicator));
      expect(node.label, contains('Lives remaining: 3 of 3'));
      expect(node.value, equals('3'));

      // 2 of 3
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 2, reduceMotion: true),
        ),
      );
      await tester.pump();
      node = tester.getSemantics(find.byType(HeartLifeIndicator));
      expect(node.label, contains('Lives remaining: 2 of 3'));
      expect(node.value, equals('2'));

      // 1 of 3
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 1, reduceMotion: true),
        ),
      );
      await tester.pump();
      node = tester.getSemantics(find.byType(HeartLifeIndicator));
      expect(node.label, contains('Lives remaining: 1 of 3'));
      expect(node.value, equals('1'));

      // 0 of 3
      await tester.pumpWidget(
        wrapWithTheme(
          const HeartLifeIndicator(remainingLives: 0, reduceMotion: true),
        ),
      );
      await tester.pump();
      node = tester.getSemantics(find.byType(HeartLifeIndicator));
      expect(node.label, contains('Lives remaining: 0 of 3'));
      expect(node.value, equals('0'));

      handle.dispose();
    });
  });
}
