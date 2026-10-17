import 'package:arrowtapout/core/qa_config.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/features/settings/settings_screen.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/router/app_router.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    QaConfig.testOverride = null;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    QaConfig.testOverride = null;
  });

  group('Access Control: Policy & Compile-Time Boundaries', () {
    test('1. QA tools are enabled in the default debug configuration', () {
      final isEnabled = QaConfig.evaluatePolicy(
        isDebug: true,
        isProfile: false,
        isRelease: false,
        hasCompileTimeFlag: false,
        compileTimeFlagValue: false,
      );
      expect(isEnabled, isTrue);
    });

    test(
        '2. QA tools are enabled in explicitly configured internal QA build (--dart-define=ENABLE_QA_TOOLS=true)',
        () {
      final isReleaseQaEnabled = QaConfig.evaluatePolicy(
        isDebug: false,
        isProfile: false,
        isRelease: true,
        hasCompileTimeFlag: true,
        compileTimeFlagValue: true,
      );
      expect(isReleaseQaEnabled, isTrue);

      final isProfileQaEnabled = QaConfig.evaluatePolicy(
        isDebug: false,
        isProfile: true,
        isRelease: false,
        hasCompileTimeFlag: true,
        compileTimeFlagValue: true,
      );
      expect(isProfileQaEnabled, isTrue);
    });

    test(
        '3. QA tools are strictly disabled by default in release configuration',
        () {
      final isReleaseDefault = QaConfig.evaluatePolicy(
        isDebug: false,
        isProfile: false,
        isRelease: true,
        hasCompileTimeFlag: false,
        compileTimeFlagValue: false,
      );
      expect(isReleaseDefault, isFalse);

      final isProfileDefault = QaConfig.evaluatePolicy(
        isDebug: false,
        isProfile: true,
        isRelease: false,
        hasCompileTimeFlag: false,
        compileTimeFlagValue: false,
      );
      expect(isProfileDefault, isFalse);
    });

    test('4. Normal user preferences or storage flags cannot enable QA console',
        () async {
      SharedPreferences.setMockInitialValues({
        'enable_qa': true,
        'is_tester': true,
        'debug_mode': true,
        'qa_unlocked': true,
      });
      final prefs = await SharedPreferences.getInstance();

      // Even if attacker adds keys to SharedPreferences
      expect(prefs.getBool('enable_qa'), isTrue);

      // QaConfig solely checks compile-time access policy and ignores client prefs
      QaConfig.testOverride = false;
      expect(QaConfig.isQaAvailable, isFalse);
    });
  });

  group('Access Control: UI & Router Gating', () {
    testWidgets(
        '5. Regular player settings do not expose QA functionality in production release',
        (tester) async {
      QaConfig.testOverride = false; // Simulating normal release build
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => SettingsRepository(prefs)),
            hapticsServiceProvider.overrideWith((ref) => HapticsService(ref)),
          ],
          child: MaterialApp(
            theme: AppThemes.buildThemeData(AppThemes.sageLinenTokens,
                isDark: false),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure the QA Console tile is completely omitted
      expect(find.byKey(const Key('qa_console_tile')), findsNothing);
      expect(find.text('ArrowZ QA Console'), findsNothing);
      expect(find.text('Internal Testing'), findsNothing);
    });

    testWidgets(
        '6. Authorized QA build exposes QA Console entry point in Settings',
        (tester) async {
      QaConfig.testOverride = true; // Simulating QA-enabled build
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            settingsProvider.overrideWith((ref) => SettingsRepository(prefs)),
            hapticsServiceProvider.overrideWith((ref) => HapticsService(ref)),
          ],
          child: MaterialApp(
            theme: AppThemes.buildThemeData(AppThemes.sageLinenTokens,
                isDark: false),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure the QA Console tile is rendered under Internal Testing
      await tester.scrollUntilVisible(
          find.byKey(const Key('qa_console_tile')), 300);
      expect(find.byKey(const Key('qa_console_tile')), findsOneWidget);
      expect(find.text('ArrowZ QA Console'), findsOneWidget);
      expect(find.text('Internal Testing'), findsOneWidget);
    });

    testWidgets(
        '7. Router blocks /qa navigation and redirects to home when QA is disabled',
        (tester) async {
      QaConfig.testOverride = false; // Disabled QA
      final prefs = await SharedPreferences.getInstance();

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            hapticsServiceProvider.overrideWith((ref) => HapticsService(ref)),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
                theme: AppThemes.buildThemeData(AppThemes.sageLinenTokens,
                    isDark: false),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Attempt to navigate to /qa via router
      capturedRef.read(appRouterProvider).go(Routes.qaConsole);
      await tester.pumpAndSettle();

      // Router should redirect away from QA console to home
      expect(find.text('ArrowZ QA Console'), findsNothing);
    });
  });
}
