import 'dart:async';
import 'package:arrowtapout/features/levels/levels_screen.dart';
import 'package:arrowtapout/router/nav_utils.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Section 6 Navigation Graph & Quality Gates', () {
    test('Level select computeChapterOffset calculates correct chapter offset', () {
      // Gate: Level select opens at current chapter (highestUnlocked of 1, 36, 100, 200)
      expect(LevelsScreen.computeChapterOffset(1), equals(0.0));
      expect(LevelsScreen.computeChapterOffset(36), equals(560.0)); // Chapter 2
      expect(LevelsScreen.computeChapterOffset(100), equals(2240.0)); // Chapter 5
      expect(LevelsScreen.computeChapterOffset(200), equals(5040.0)); // Chapter 10
    });

    testWidgets('SafeBack pops when canPop is true', (tester) async {
      late BuildContext capturedContext;

      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Page A');
            }),
          ),
          GoRoute(
            path: '/b',
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Page B');
            }),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.text('Page A'), findsOneWidget);

      unawaited(capturedContext.push('/b'));
      await tester.pumpAndSettle();
      expect(find.text('Page B'), findsOneWidget);

      // SafeBack should pop back to /a
      capturedContext.safeBack(fallbackRoute: '/a');
      await tester.pumpAndSettle();
      expect(find.text('Page A'), findsOneWidget);
    });

    testWidgets('SafeBack navigates to fallbackRoute on cold restore (canPop == false)', (tester) async {
      late BuildContext capturedContext;

      final router = GoRouter(
        initialLocation: '/cold_game',
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (ctx, state) => const Text('Home Screen'),
          ),
          GoRoute(
            path: '/cold_game',
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Cold Game Screen');
            }),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.text('Cold Game Screen'), findsOneWidget);

      // In cold restore, canPop is false. SafeBack must go to fallbackRoute (/home)
      expect(capturedContext.canPop(), isFalse);
      capturedContext.safeBack(fallbackRoute: Routes.home);
      await tester.pumpAndSettle();

      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('Levels route back returns to Home', (tester) async {
      late BuildContext capturedContext;

      final router = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Home Screen');
            }),
          ),
          GoRoute(
            path: Routes.levels,
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Levels Screen');
            }),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      expect(find.text('Home Screen'), findsOneWidget);

      unawaited(capturedContext.push(Routes.levels));
      await tester.pumpAndSettle();
      expect(find.text('Levels Screen'), findsOneWidget);

      capturedContext.safeBack(fallbackRoute: Routes.home);
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('Settings and Theme picker back unwinds properly', (tester) async {
      late BuildContext capturedContext;

      final router = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Home Screen');
            }),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Settings Screen');
            }),
            routes: [
              GoRoute(
                path: 'theme',
                builder: (ctx, state) => Builder(builder: (c) {
                  capturedContext = c;
                  return const Text('Theme Picker');
                }),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      unawaited(capturedContext.push(Routes.settings));
      await tester.pumpAndSettle();
      expect(find.text('Settings Screen'), findsOneWidget);

      unawaited(capturedContext.push(Routes.theme));
      await tester.pumpAndSettle();
      expect(find.text('Theme Picker'), findsOneWidget);

      // Back from theme picker goes to Settings
      capturedContext.safeBack(fallbackRoute: Routes.settings);
      await tester.pumpAndSettle();
      expect(find.text('Settings Screen'), findsOneWidget);

      // Back from Settings goes to Home
      capturedContext.safeBack(fallbackRoute: Routes.home);
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('Next level uses pushReplacement keeping stack depth', (tester) async {
      late BuildContext capturedContext;

      final router = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return const Text('Home Screen');
            }),
          ),
          GoRoute(
            path: '/play/:id',
            builder: (ctx, state) => Builder(builder: (c) {
              capturedContext = c;
              return Text('Game Level ${state.pathParameters['id']}');
            }),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      unawaited(capturedContext.push(Routes.play(1)));
      await tester.pumpAndSettle();
      expect(find.text('Game Level 1'), findsOneWidget);

      // After complete, "Next level" uses pushReplacement
      capturedContext.pushReplacement(Routes.play(2));
      await tester.pumpAndSettle();
      expect(find.text('Game Level 2'), findsOneWidget);

      // Back returns to Home directly (stack was not expanded to 3)
      capturedContext.safeBack(fallbackRoute: Routes.home);
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);
    });
  });
}
