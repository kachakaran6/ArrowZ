import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/theme_provider.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/features/game/sheets/complete_sheet.dart';
import 'package:arrowtapout/features/home/home_screen.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Bug Fixes & Polish Verification', () {
    testWidgets(
        '1. CompleteSheet shows title "Complete", 3 stars, Arrows terminology, and only Replay & Next Level buttons',
        (tester) async {
      bool replayed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppThemes.buildThemeData(
              AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
              isDark: false,
            ),
            home: Scaffold(
              body: CompleteSheet(
                levelId: 5,
                stars: 3,
                threadsCleared: 8,
                mistakes: 0,
                onReplay: () => replayed = true,
                onNextLevel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title must be "Complete"
      expect(find.text('Complete'), findsOneWidget);

      // Exactly 3 star icons
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));

      // Uses Arrow instead of Thread, keeps Mistake
      expect(find.textContaining('8 Arrows · 0 Mistakes'), findsOneWidget);

      // Only two buttons: Replay and Next Level
      expect(find.text('Replay'), findsOneWidget);
      expect(find.text('Next Level'), findsOneWidget);
      expect(find.text('Levels'), findsNothing);
      expect(find.text('Share'), findsNothing);

      // Tap Replay
      await tester.tap(find.text('Replay'));
      expect(replayed, isTrue);
    });

    testWidgets(
        '1b. CompleteSheet Next Level button triggers onNextLevel callback',
        (tester) async {
      bool nextLeveled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppThemes.buildThemeData(
              AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
              isDark: false,
            ),
            home: Scaffold(
              body: CompleteSheet(
                levelId: 5,
                stars: 3,
                threadsCleared: 8,
                mistakes: 0,
                onReplay: () {},
                onNextLevel: () => nextLeveled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next Level'));
      expect(nextLeveled, isTrue);
    });

    test(
        '2. Weekday recent activity always orders starting from Sunday (S M T W T F S)',
        () {
      final repo = StreakRepository(null);
      // Fixed test date: Thursday Oct 15, 2026
      final testThursday = DateTime(2026, 10, 15);
      final activity = repo.getRecentActivity(7, testThursday);

      expect(activity.length, equals(7));

      // Day 0: Sunday (DateTime.sunday == 7)
      expect(activity[0].date.weekday, equals(DateTime.sunday));
      // Day 1: Monday (DateTime.monday == 1)
      expect(activity[1].date.weekday, equals(DateTime.monday));
      // Day 2: Tuesday
      expect(activity[2].date.weekday, equals(DateTime.tuesday));
      // Day 3: Wednesday
      expect(activity[3].date.weekday, equals(DateTime.wednesday));
      // Day 4: Thursday (today)
      expect(activity[4].date.weekday, equals(DateTime.thursday));
      expect(activity[4].isToday, isTrue);
      // Day 5: Friday
      expect(activity[5].date.weekday, equals(DateTime.friday));
      // Day 6: Saturday
      expect(activity[6].date.weekday, equals(DateTime.saturday));
    });

    testWidgets(
        '3. Theme choice in settings dynamically updates themeModeProvider and currentTokensProvider',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeModeProvider);
              final tokens = ref.watch(currentTokensProvider);
              return MaterialApp(
                home: Scaffold(
                  backgroundColor: tokens.bg,
                  body: Text('ActiveTheme: ${mode.name}'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ActiveTheme: followSystem'), findsOneWidget);

      final element = tester.element(find.byType(Consumer));
      final container = ProviderScope.containerOf(element);

      // Change theme in settings to Rosewood
      await container
          .read(settingsProvider.notifier)
          .setThemeChoice(AppThemeMode.rosewood);
      await tester.pumpAndSettle();

      // Should automatically re-render with Rosewood!
      expect(find.text('ActiveTheme: rosewood'), findsOneWidget);
    });

    testWidgets('4. Subtitle displays Escape Puzzle instead of Thread Puzzle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationServiceProvider
                .overrideWithValue(FakeNotificationService()),
          ],
          child: MaterialApp(
            theme: AppThemes.buildThemeData(
              AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
              isDark: false,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ArrowZ'), findsOneWidget);
      expect(find.text('Escape Puzzle'), findsOneWidget);
      expect(find.text('Thread Puzzle'), findsNothing);
    });
  });
}
