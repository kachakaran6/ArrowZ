import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/features/home/home_screen.dart';
import 'package:arrowtapout/features/streak/streak_screen.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTickerProvider extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArrowZ Daily Streak System (ARROWZ-1-5)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('1. First qualifying completion creates a streak of 1', () async {
      final simulatedTime = DateTime(2026, 10, 14, 10, 30);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      expect(streakRepo.getCurrentStreak(), equals(0));
      expect(streakRepo.getBestStreak(), equals(0));
      expect(streakRepo.getLastQualifyingPlayDate(), isNull);

      final isFirst = await streakRepo.recordQualifyingPlay();

      expect(isFirst, isTrue);
      expect(streakRepo.getCurrentStreak(), equals(1));
      expect(streakRepo.getBestStreak(), equals(1));
      expect(
        streakRepo.getLastQualifyingPlayDate(),
        equals(DateTime(2026, 10, 14)),
      );
      expect(streakRepo.isTodayCompleted(), isTrue);
    });

    test('2. Multiple completions on one day count once', () async {
      DateTime simulatedTime = DateTime(2026, 10, 14, 9, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      final firstPlay = await streakRepo.recordQualifyingPlay();
      expect(firstPlay, isTrue);
      expect(streakRepo.getCurrentStreak(), equals(1));

      // Same day, 2 hours later
      simulatedTime = DateTime(2026, 10, 14, 11, 0);
      final secondPlay = await streakRepo.recordQualifyingPlay();
      expect(secondPlay, isFalse);
      expect(streakRepo.getCurrentStreak(), equals(1));

      // Same day, evening
      simulatedTime = DateTime(2026, 10, 14, 21, 30);
      final thirdPlay = await streakRepo.recordQualifyingPlay();
      expect(thirdPlay, isFalse);
      expect(streakRepo.getCurrentStreak(), equals(1));
      expect(streakRepo.getBestStreak(), equals(1));
    });

    test('3. Consecutive calendar days increment the streak', () async {
      DateTime simulatedTime = DateTime(2026, 10, 14, 14, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));

      // Day 2
      simulatedTime = DateTime(2026, 10, 15, 12, 0);
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(2));
      expect(streakRepo.getBestStreak(), equals(2));

      // Day 3
      simulatedTime = DateTime(2026, 10, 16, 18, 0);
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(3));
      expect(streakRepo.getBestStreak(), equals(3));
    });

    test('4. A missed calendar day resets the active streak', () async {
      DateTime simulatedTime = DateTime(2026, 10, 14, 12, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));

      // Day 2 played
      simulatedTime = DateTime(2026, 10, 15, 12, 0);
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(2));

      // Day 3 is MISSED (no play). Fast-forward to Day 4 morning
      simulatedTime = DateTime(2026, 10, 17, 9, 0);
      streakRepo.refreshStreakStatus();

      // Since yesterday (Oct 16) was missed, active streak resets to 0
      expect(streakRepo.getCurrentStreak(), equals(0));
    });

    test('5. Returning after a missed day starts a new streak of 1', () async {
      DateTime simulatedTime = DateTime(2026, 10, 14, 12, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));

      // Miss 3 days, arrive on Day 4
      simulatedTime = DateTime(2026, 10, 18, 15, 0);
      streakRepo.refreshStreakStatus();
      expect(streakRepo.getCurrentStreak(), equals(0));

      // Complete a level on Day 4
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));
      expect(
        streakRepo.getLastQualifyingPlayDate(),
        equals(DateTime(2026, 10, 18)),
      );
    });

    test('6. Best streak remains unchanged when the current streak resets',
        () async {
      DateTime simulatedTime = DateTime(2026, 10, 1, 12, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      // Build a 4-day streak
      for (int i = 0; i < 4; i++) {
        simulatedTime = DateTime(2026, 10, 1 + i, 12, 0);
        await streakRepo.recordQualifyingPlay();
      }
      expect(streakRepo.getCurrentStreak(), equals(4));
      expect(streakRepo.getBestStreak(), equals(4));

      // Miss Oct 5 and Oct 6. Open app on Oct 7
      simulatedTime = DateTime(2026, 10, 7, 10, 0);
      streakRepo.refreshStreakStatus();

      expect(streakRepo.getCurrentStreak(), equals(0));
      // Best streak must still be 4!
      expect(streakRepo.getBestStreak(), equals(4));

      // Play on Oct 7 -> current streak becomes 1, best streak remains 4
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));
      expect(streakRepo.getBestStreak(), equals(4));
    });

    test('7. Midnight boundaries work correctly (11:55 PM to 12:05 AM)',
        () async {
      // Play at 11:55 PM on Oct 14
      DateTime simulatedTime = DateTime(2026, 10, 14, 23, 55);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));

      // Play 10 minutes later at 12:05 AM on Oct 15
      simulatedTime = DateTime(2026, 10, 15, 0, 5);
      await streakRepo.recordQualifyingPlay();

      // Calendar day changed, so streak must increment to 2
      expect(streakRepo.getCurrentStreak(), equals(2));
      expect(
        streakRepo.getLastQualifyingPlayDate(),
        equals(DateTime(2026, 10, 15)),
      );
    });

    test('8. Date calculations do not depend on fixed 24-hour intervals',
        () async {
      // Leap year boundary: Feb 28 -> Feb 29 -> Mar 1 (2024 is a leap year)
      DateTime simulatedTime = DateTime(2024, 2, 28, 14, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));

      // Leap day
      simulatedTime = DateTime(2024, 2, 29, 23, 0);
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(2));

      // March 1st
      simulatedTime = DateTime(2024, 3, 1, 6, 0);
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(3));

      // Month rollover: Dec 31 -> Jan 1
      simulatedTime = DateTime(2024, 12, 31, 23, 30);
      await streakRepo.recordQualifyingPlay();

      simulatedTime = DateTime(2025, 1, 1, 1, 30);
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(2));
    });

    testWidgets('9. App resume refreshes the displayed streak', (tester) async {
      DateTime simulatedTime = DateTime(2026, 10, 14, 12, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);
      await streakRepo.recordQualifyingPlay();

      final fakeNotifications = FakeNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            streakRepositoryProvider.overrideWith((ref) => streakRepo),
            notificationServiceProvider.overrideWithValue(fakeNotifications),
            playUpdateServiceProvider.overrideWithValue(NoOpUpdateService()),
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

      expect(find.byKey(const Key('lobby_streak_text')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Now 2 days pass without playing (missed day)
      simulatedTime = DateTime(2026, 10, 16, 10, 0);

      // Simulate app resuming from background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Displayed streak should now be refreshed to 0
      expect(find.text('0'), findsOneWidget);
    });

    test('10. Completing a level suppresses that day\'s reminder', () async {
      final simulatedTime = DateTime(2026, 10, 14, 14, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);
      final fakeNotifications = FakeNotificationService();

      // User has streak 1 from yesterday (Oct 13)
      await streakRepo.recordQualifyingPlay(DateTime(2026, 10, 13, 20, 0));
      await streakRepo.setRemindersEnabled(true);

      // Prior to today's play, reminder is scheduled for today 8:00 PM
      await streakRepo.syncReminders(fakeNotifications, simulatedTime);
      expect(await fakeNotifications.isReminderScheduled(), isTrue);
      expect(fakeNotifications.scheduledHour, equals(20));

      // Now user completes a level today at 2:00 PM
      await streakRepo.recordQualifyingPlay(simulatedTime, fakeNotifications);

      // Completing the level must cancel/suppress today's reminder
      expect(fakeNotifications.cancelCallCount, greaterThanOrEqualTo(1));
      // And schedules for tomorrow at 8:00 PM
      expect(await fakeNotifications.isReminderScheduled(), isTrue);
      expect(fakeNotifications.scheduledHour, equals(20));
    });

    test('11. Reminder scheduling is idempotent', () async {
      final simulatedTime = DateTime(2026, 10, 14, 10, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);
      final fakeNotifications = FakeNotificationService();

      await streakRepo.recordQualifyingPlay(DateTime(2026, 10, 13, 12, 0));
      await streakRepo.setRemindersEnabled(true);

      // Sync once
      await streakRepo.syncReminders(fakeNotifications, simulatedTime);

      // Sync again with identical conditions
      await streakRepo.syncReminders(fakeNotifications, simulatedTime);

      // Reminder remains scheduled once with stable configuration without creating duplicates
      expect(await fakeNotifications.isReminderScheduled(), isTrue);
      expect(fakeNotifications.scheduledHour, equals(20));
      expect(fakeNotifications.scheduledMinute, equals(0));
    });

    test('12. Disabling reminders cancels pending notifications', () async {
      final simulatedTime = DateTime(2026, 10, 14, 10, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);
      final fakeNotifications = FakeNotificationService();

      await streakRepo.recordQualifyingPlay(DateTime(2026, 10, 13, 12, 0));
      await streakRepo.setRemindersEnabled(true, fakeNotifications);
      expect(await fakeNotifications.isReminderScheduled(), isTrue);

      // Disable reminders
      await streakRepo.setRemindersEnabled(false, fakeNotifications);
      expect(await fakeNotifications.isReminderScheduled(), isFalse);
    });

    test('13. Permission denial does not break gameplay or corrupt data',
        () async {
      final simulatedTime = DateTime(2026, 10, 14, 12, 0);
      final streakRepo = StreakRepository(prefs, clock: () => simulatedTime);

      // Notification service with denied permission
      final fakeNotifications =
          FakeNotificationService(initialHasPermission: false);

      // Enabling reminders when denied
      await streakRepo.setRemindersEnabled(true, fakeNotifications);
      expect(await fakeNotifications.isReminderScheduled(), isFalse);

      // Playing a level succeeds completely without exceptions
      final recorded = await streakRepo.recordQualifyingPlay(
          simulatedTime, fakeNotifications);
      expect(recorded, isTrue);
      expect(streakRepo.getCurrentStreak(), equals(1));
      expect(streakRepo.isTodayCompleted(), isTrue);
    });

    test('14. Corrupted or migrated local data is handled safely', () async {
      // Put corrupted JSON in SharedPreferences
      await prefs.setString('arrowz.streak', '{ corrupted_not_json: true');

      // Loading streak repository must not crash
      final streakRepo = StreakRepository(prefs);
      expect(streakRepo.getCurrentStreak(), equals(0));
      expect(streakRepo.getBestStreak(), equals(0));
      expect(streakRepo.getLastQualifyingPlayDate(), isNull);

      // Verify saving and normal operations still work safely
      await streakRepo.recordQualifyingPlay();
      expect(streakRepo.getCurrentStreak(), equals(1));
    });

    testWidgets(
        '15. The Streak screen works with all five themes and large text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final fakeNotifications = FakeNotificationService();

      for (final themeMode in AppThemeMode.values) {
        final streakRepo = StreakRepository(prefs);
        await streakRepo.recordQualifyingPlay(DateTime(2026, 10, 14));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              streakRepositoryProvider.overrideWith((ref) => streakRepo),
              notificationServiceProvider.overrideWithValue(fakeNotifications),
            ],
            child: MediaQuery(
              // Large text scale factor
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: MaterialApp(
                theme: AppThemes.buildThemeData(
                  AppThemes.tokensFor(themeMode, Brightness.light),
                  isDark: themeMode.isDark,
                ),
                home: const StreakScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify elements render without overflow
        expect(find.text('Daily Streak'), findsOneWidget);
        expect(find.byKey(const Key('streak_current_count')), findsOneWidget);
        expect(find.byKey(const Key('streak_best_count')), findsOneWidget);
        expect(find.byKey(const Key('streak_last_date')), findsOneWidget);
        expect(find.byKey(const Key('streak_today_status')), findsOneWidget);
        expect(find.text('Recent Activity'), findsOneWidget);
        expect(find.text('How Streaks Work'), findsOneWidget);
        expect(find.byKey(const Key('streak_reminder_switch')), findsOneWidget);
      }
    });

    testWidgets('16. Tapping lobby Streak button opens the Streak screen',
        (tester) async {
      final streakRepo = StreakRepository(prefs);
      await streakRepo.recordQualifyingPlay(DateTime(2026, 10, 14));

      final testRouter = GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.streak,
            builder: (context, state) => const StreakScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            streakRepositoryProvider.overrideWith((ref) => streakRepo),
            notificationServiceProvider
                .overrideWithValue(FakeNotificationService()),
            playUpdateServiceProvider.overrideWithValue(NoOpUpdateService()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
            theme: AppThemes.buildThemeData(
              AppThemes.tokensFor(AppThemeMode.sageLinen, Brightness.light),
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lobby_streak_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('lobby_streak_button')));
      await tester.pumpAndSettle();

      expect(find.text('Daily Streak'), findsOneWidget);
      expect(find.byKey(const Key('streak_current_count')), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // Back button navigates back to Lobby
      await tester.tap(find.byKey(const Key('streak_back_button')));
      await tester.pumpAndSettle();

      expect(find.text('ArrowZ'), findsOneWidget);
    });

    test('17. GameController completion triggers streak qualification',
        () async {
      final progressRepo = ProgressRepository(prefs);
      final snapshotRepo = SnapshotRepository(prefs);
      final streakRepo = StreakRepository(prefs);
      final fakeNotifications = FakeNotificationService();
      final container = ProviderContainer();
      final animator = BoardAnimator(vsync: _FakeTickerProvider());

      // Create a test level with 1 thread
      final testLevel = Level(
        id: 1,
        rows: 2,
        cols: 2,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
        ],
      );

      final controller = GameController(
        level: testLevel,
        animator: animator,
        audio: container.read(audioServiceProvider),
        haptics: container.read(hapticsServiceProvider),
        progress: progressRepo,
        snapshotRepo: snapshotRepo,
        streakRepo: streakRepo,
        notificationService: fakeNotifications,
      );

      expect(streakRepo.getCurrentStreak(), equals(0));

      // Tap the arrow to clear the level
      controller.handleThreadTap(1, 24.0);

      // Wait for completion delay (350ms in controller + padding)
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(streakRepo.getCurrentStreak(), equals(1));
      expect(streakRepo.isTodayCompleted(), isTrue);

      controller.dispose();
      animator.dispose();
      container.dispose();
    });
  });
}
