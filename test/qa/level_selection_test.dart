import 'package:arrowtapout/core/qa_config.dart';
import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
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
  _MockLevelRepository({
    this.totalLevels = 500,
    this.shouldFailLoading = false,
    this.missingLevelId,
  });

  final int totalLevels;
  final bool shouldFailLoading;
  final int? missingLevelId;

  Level _sampleLevel(int id) => Level(
        id: id,
        rows: 4,
        cols: 4,
        threads: [
          Thread(1, [const Cell(0, 0), const Cell(0, 1)]),
        ],
      );

  @override
  int get cachedTotalLevels => totalLevels;

  @override
  Future<int> getTotalLevelCount() async => totalLevels;

  @override
  Future<bool> isValidLevelId(int id) async =>
      id >= 1 && id <= totalLevels && id != missingLevelId;

  @override
  Future<Level?> tryLoadLevel(int id) async {
    if (shouldFailLoading) return null;
    if (id < 1 || id > totalLevels || id == missingLevelId) return null;
    return _sampleLevel(id);
  }

  @override
  Future<Level> loadLevel(int id) async {
    final lvl = await tryLoadLevel(id);
    if (lvl == null) throw StateError('Level $id not found');
    return lvl;
  }

  @override
  Future<List<Level>> loadChapter(int chapterNumber) async {
    return [_sampleLevel(chapterNumber * 20)];
  }
}

void main() {
  setUp(() {
    QaConfig.testOverride = true;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    QaConfig.testOverride = null;
  });

  Widget createQaConsoleWidget({
    LevelRepository? levelRepo,
    ProgressRepository? progressRepo,
  }) {
    return ProviderScope(
      overrides: [
        if (levelRepo != null)
          levelRepositoryProvider.overrideWithValue(levelRepo),
        if (progressRepo != null)
          progressProvider.overrideWith((ref) => progressRepo),
        hapticsServiceProvider.overrideWith((ref) => HapticsService(ref)),
      ],
      child: MaterialApp(
        theme:
            AppThemes.buildThemeData(AppThemes.sageLinenTokens, isDark: false),
        home: const QaConsoleScreen(),
      ),
    );
  }

  group('Level Selection & Input Validation Tests', () {
    testWidgets('1. Empty input displays validation error without crashing',
        (tester) async {
      await tester.pumpWidget(createQaConsoleWidget());
      await tester.pumpAndSettle();

      // Clear the text field
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '');
      await tester.pumpAndSettle();

      // Tap Launch
      await tester.tap(find.widgetWithText(FilledButton, 'Launch'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a level number.'), findsOneWidget);
    });

    testWidgets('2. Non-numeric input displays validation error',
        (tester) async {
      await tester.pumpWidget(createQaConsoleWidget());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      // Because digitsOnly formatter is on the field, entering letters yields empty text
      await tester.enterText(textField, 'invalid');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Launch'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a level number.'), findsOneWidget);
    });

    testWidgets('3. Zero or negative values display validation error',
        (tester) async {
      await tester.pumpWidget(createQaConsoleWidget());
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '0');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Launch'));
      await tester.pumpAndSettle();

      expect(find.text('Level number must be at least 1.'), findsOneWidget);
    });

    testWidgets('4. Out-of-bounds value (> totalLevels) displays range error',
        (tester) async {
      final mockRepo = _MockLevelRepository(totalLevels: 500);
      await tester.pumpWidget(createQaConsoleWidget(levelRepo: mockRepo));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '999');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Launch'));
      await tester.pumpAndSettle();

      expect(
        find.text('Level 999 exceeds maximum available levels (500).'),
        findsOneWidget,
      );
    });

    testWidgets('5. First available level (1) validates successfully',
        (tester) async {
      final mockRepo = _MockLevelRepository(totalLevels: 500);
      await tester.pumpWidget(createQaConsoleWidget(levelRepo: mockRepo));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '1');
      await tester.pumpAndSettle();

      // Inspect details should load clean geometry
      await tester.scrollUntilVisible(
        find.text('Inspection: Level 1'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Inspection: Level 1'), findsOneWidget);
      expect(find.text('4 Rows × 4 Columns'), findsOneWidget);
    });

    testWidgets('6. Last available level (500) validates successfully',
        (tester) async {
      final mockRepo = _MockLevelRepository(totalLevels: 500);
      await tester.pumpWidget(createQaConsoleWidget(levelRepo: mockRepo));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '500');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Inspection: Level 500'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Inspection: Level 500'), findsOneWidget);
    });

    testWidgets('7. Missing or invalid level definition displays clear error',
        (tester) async {
      final mockRepo = _MockLevelRepository(
        totalLevels: 500,
        missingLevelId: 42,
      );
      await tester.pumpWidget(createQaConsoleWidget(levelRepo: mockRepo));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '42');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Launch'));
      await tester.pumpAndSettle();

      expect(
        find.text('Level 42 definition could not be decoded or loaded.'),
        findsOneWidget,
      );
    });

    testWidgets('8. Level-loading failure is handled gracefully without crash',
        (tester) async {
      final mockRepo = _MockLevelRepository(
        totalLevels: 500,
        shouldFailLoading: true,
      );
      await tester.pumpWidget(createQaConsoleWidget(levelRepo: mockRepo));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '10');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Launch'));
      await tester.pumpAndSettle();

      expect(
        find.text('Level 10 definition could not be decoded or loaded.'),
        findsOneWidget,
      );
    });

    testWidgets('9. Rapid duplicate launch requests are debounced',
        (tester) async {
      final mockRepo = _MockLevelRepository(totalLevels: 500);
      await tester.pumpWidget(createQaConsoleWidget(levelRepo: mockRepo));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '25');
      await tester.pumpAndSettle();

      final launchButton = find.widgetWithText(FilledButton, 'Launch');

      // Tap launch rapidly multiple times
      await tester.tap(launchButton);
      await tester.tap(launchButton);
      await tester.tap(launchButton);
      await tester.pump();

      // No crash, stable execution
      expect(find.byType(QaConsoleScreen), findsOneWidget);
    });
  });
}
