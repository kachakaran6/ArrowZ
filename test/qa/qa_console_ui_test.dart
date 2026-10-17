import 'package:arrowtapout/core/qa_config.dart';
import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/qa/qa_console_screen.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockLevelRepository implements LevelRepository {
  Level _sampleLevel(int id) => Level(
        id: id,
        rows: 5,
        cols: 5,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
        ],
      );

  @override
  int get cachedTotalLevels => 500;

  @override
  Future<int> getTotalLevelCount() async => 500;

  @override
  Future<bool> isValidLevelId(int id) async => id >= 1 && id <= 500;

  @override
  Future<Level?> tryLoadLevel(int id) async => _sampleLevel(id);

  @override
  Future<Level> loadLevel(int id) async => _sampleLevel(id);

  @override
  Future<List<Level>> loadChapter(int chapterNumber) async =>
      [_sampleLevel(chapterNumber * 20)];
}

void main() {
  setUp(() {
    QaConfig.testOverride = true;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    QaConfig.testOverride = null;
  });

  Widget buildQaConsoleTestWidget() {
    final mockRepo = _MockLevelRepository();
    return ProviderScope(
      overrides: [
        levelRepositoryProvider.overrideWithValue(mockRepo),
        hapticsServiceProvider.overrideWith((ref) => HapticsService(ref)),
      ],
      child: MaterialApp(
        theme:
            AppThemes.buildThemeData(AppThemes.sageLinenTokens, isDark: false),
        home: const QaConsoleScreen(),
      ),
    );
  }

  group('QA Console UI & Interaction Tests', () {
    testWidgets(
        '1. Renders title, subtitle, environment badge and overview card',
        (tester) async {
      await tester.pumpWidget(buildQaConsoleTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ArrowZ QA Console'), findsOneWidget);
      expect(find.text('Internal Game Testing Tools'), findsOneWidget);
      expect(find.text('DEBUG'), findsOneWidget);

      expect(find.text('A. Environment Overview'), findsOneWidget);
      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('Build Mode'), findsOneWidget);
      expect(find.text('QA Tooling Access'), findsOneWidget);
      expect(find.text('Total Available Levels'), findsOneWidget);
      expect(find.text('500 (25 Chapters)'), findsOneWidget);
    });

    testWidgets('2. Quick action "Reset Puzzle State" displays confirmation',
        (tester) async {
      await tester.pumpWidget(buildQaConsoleTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Puzzle State'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Temporary in-memory puzzle state reset to clean initial state.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('3. Chapter filter dropdown filters level browser correctly',
        (tester) async {
      await tester.pumpWidget(buildQaConsoleTestWidget());
      await tester.pumpAndSettle();

      // Find the Chapter Dropdown
      final dropdown = find.byType(DropdownButton<int>);
      await tester.scrollUntilVisible(
        dropdown,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(dropdown, findsOneWidget);

      // Tap and select Chapter 2
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ch 2: Loose Ends').last);
      await tester.pumpAndSettle();

      // Chapter 2 has 20 levels (21 to 40)
      expect(find.text('Showing 20 levels (tap to test)'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
    });

    testWidgets('4. Search query filters level items by number or name',
        (tester) async {
      await tester.pumpWidget(buildQaConsoleTestWidget());
      await tester.pumpAndSettle();

      final searchField =
          find.widgetWithText(TextField, 'Search level or chapter...');
      await tester.scrollUntilVisible(
        searchField,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(searchField, findsOneWidget);

      // Search for specific level number
      await tester.enterText(searchField, '105');
      await tester.pumpAndSettle();

      // Verify the level tile is present in the filtered grid
      expect(find.widgetWithText(InkWell, '105'), findsOneWidget);
    });

    testWidgets('5. Level inspection displays real geometry and copy button',
        (tester) async {
      await tester.pumpWidget(buildQaConsoleTestWidget());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '1');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Inspection: Level 1'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Inspection: Level 1'), findsOneWidget);
      expect(find.text('5 Rows × 5 Columns'), findsOneWidget);
      expect(find.text('Copy Diagnostics'), findsOneWidget);

      await tester.tap(find.text('Copy Diagnostics'));
      await tester.pumpAndSettle();

      expect(
        find.text('Level diagnostic information copied to clipboard.'),
        findsOneWidget,
      );
    });

    testWidgets(
        '6. Small screen layout (320x480) renders without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 480 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(buildQaConsoleTestWidget());
      await tester.pumpAndSettle();

      // Must render smoothly without overflow errors
      expect(find.byType(QaConsoleScreen), findsOneWidget);

      // Reset test surface
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  });
}
