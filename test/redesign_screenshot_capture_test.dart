import 'dart:io';
import 'dart:ui' as ui;

import 'package:arrowtapout/data/daily_thread_service.dart';
import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/game_screen.dart';
import 'package:arrowtapout/features/game/sheets/complete_sheet.dart';
import 'package:arrowtapout/features/home/home_screen.dart';
import 'package:arrowtapout/features/levels/levels_screen.dart';
import 'package:arrowtapout/features/settings/settings_screen.dart';
import 'package:arrowtapout/features/settings/theme_picker_screen.dart';
import 'package:arrowtapout/platform/ad_service.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLevelRepository implements LevelRepository {
  final Level _showcase = Level(
    id: 1,
    chapter: 1,
    rows: 6,
    cols: 6,
    threads: [
      Thread(1, [const Cell(0, 1), const Cell(0, 2), const Cell(0, 3), const Cell(0, 4)]),
      Thread(2, [const Cell(1, 5), const Cell(2, 5), const Cell(3, 5), const Cell(4, 5)]),
      Thread(3, [const Cell(5, 4), const Cell(5, 3), const Cell(5, 2), const Cell(5, 1)]),
      Thread(4, [const Cell(4, 0), const Cell(3, 0), const Cell(2, 0), const Cell(1, 0)]),
      Thread(5, [const Cell(2, 2), const Cell(2, 3), const Cell(3, 3)]),
    ],
  );

  @override
  Future<void> init() async {}

  @override
  Future<List<Level>> loadChapter(int chapterNumber) async =>
      List.generate(20, (i) => Level(
        id: (chapterNumber - 1) * 20 + i + 1,
        chapter: chapterNumber,
        rows: 6,
        cols: 6,
        threads: _showcase.threads,
      ));

  @override
  Future<Level> loadLevel(int id) async => _showcase;

  @override
  Future<void> preloadNext(int currentId) async {}

  @override
  Future<int> totalLevels() async => 200;

  @override
  Level? getLevelSync(int id) => _showcase;
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository(SettingsState initial) : super(null) {
    state = initial;
  }
}

class _FakeProgressRepository extends ProgressRepository {
  _FakeProgressRepository(ProgressState initial) : super(null) {
    state = initial;
  }
}

class _TestSoundService implements SoundService {
  @override
  Diagnostics get stats => Diagnostics.instance;
  @override
  Future<void> init() async {}
  @override
  void play(SoundEvent e) {}
  @override
  void onResume() {}
  @override
  void dispose() {}
}

class _TestHapticPlatformExecutor implements HapticPlatformExecutor {
  @override
  Future<void> lightImpact() async {}
  @override
  Future<void> mediumImpact() async {}
  @override
  Future<void> heavyImpact() async {}
  @override
  Future<void> selectionClick() async {}
}

Future<void> _captureToFile(WidgetTester tester, GlobalKey key, String path) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary != null) {
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        File(path).writeAsBytesSync(byteData.buffer.asUint8List());
      }
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final themesToCapture = [
    (id: 'obsidian', name: 'Obsidian_Lime'),
    (id: 'gold', name: 'Gold_Noir'),
    (id: 'classic', name: 'Classic_Sage'),
  ];

  final screenSizes = [
    (w: 360.0, h: 800.0, label: '360x800'),
    (w: 393.0, h: 852.0, label: '393x852'),
    (w: 411.0, h: 915.0, label: '411x915'),
  ];

  setUpAll(() {
    Directory('docs/shots').createSync(recursive: true);
  });

  for (final themeItem in themesToCapture) {
    final themeTokens = AppThemes.themeForId(themeItem.id);

    for (final size in screenSizes) {
      testWidgets('Capture Home screen [${themeItem.name} - ${size.label}]', (tester) async {
        tester.view.physicalSize = Size(size.w, size.h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              levelRepositoryProvider.overrideWithValue(_FakeLevelRepository()),
              settingsProvider.overrideWith((ref) => _FakeSettingsRepository(SettingsState(themeId: themeItem.id, reduceMotion: true))),
              notificationServiceProvider.overrideWithValue(FakeNotificationService()),
              hapticsServiceProvider.overrideWith((ref) => HapticsService(ref, executor: _TestHapticPlatformExecutor())),
              soundServiceProvider.overrideWithValue(_TestSoundService()),
            ],
            child: RepaintBoundary(
              key: repaintKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppThemes.buildThemeData(themeTokens, isDark: themeTokens.isDark),
                home: const HomeScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _captureToFile(tester, repaintKey, 'docs/shots/home_${themeItem.name}_${size.label}.png');
      });

      testWidgets('Capture Levels screen [${themeItem.name} - ${size.label}]', (tester) async {
        tester.view.physicalSize = Size(size.w, size.h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              levelRepositoryProvider.overrideWithValue(_FakeLevelRepository()),
              settingsProvider.overrideWith((ref) => _FakeSettingsRepository(SettingsState(themeId: themeItem.id, reduceMotion: true))),
              progressProvider.overrideWith((ref) => _FakeProgressRepository(const ProgressState(highestUnlocked: 36, stars: {1: 3, 2: 3, 3: 2}))),
              notificationServiceProvider.overrideWithValue(FakeNotificationService()),
              hapticsServiceProvider.overrideWith((ref) => HapticsService(ref, executor: _TestHapticPlatformExecutor())),
              soundServiceProvider.overrideWithValue(_TestSoundService()),
            ],
            child: RepaintBoundary(
              key: repaintKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppThemes.buildThemeData(themeTokens, isDark: themeTokens.isDark),
                home: const LevelsScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _captureToFile(tester, repaintKey, 'docs/shots/levels_${themeItem.name}_${size.label}.png');
      });

      testWidgets('Capture Game screen [${themeItem.name} - ${size.label}]', (tester) async {
        tester.view.physicalSize = Size(size.w, size.h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              levelRepositoryProvider.overrideWithValue(_FakeLevelRepository()),
              settingsProvider.overrideWith((ref) => _FakeSettingsRepository(SettingsState(themeId: themeItem.id, reduceMotion: true))),
              rewardedAdServiceProvider.overrideWithValue(FakeRewardedAdService()),
              notificationServiceProvider.overrideWithValue(FakeNotificationService()),
              hapticsServiceProvider.overrideWith((ref) => HapticsService(ref, executor: _TestHapticPlatformExecutor())),
              soundServiceProvider.overrideWithValue(_TestSoundService()),
            ],
            child: RepaintBoundary(
              key: repaintKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppThemes.buildThemeData(themeTokens, isDark: themeTokens.isDark),
                home: const GameScreen(levelId: 36),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _captureToFile(tester, repaintKey, 'docs/shots/game_${themeItem.name}_${size.label}.png');
      });

      testWidgets('Capture Settings screen [${themeItem.name} - ${size.label}]', (tester) async {
        tester.view.physicalSize = Size(size.w, size.h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith((ref) => _FakeSettingsRepository(SettingsState(themeId: themeItem.id))),
              notificationServiceProvider.overrideWithValue(FakeNotificationService()),
              hapticsServiceProvider.overrideWith((ref) => HapticsService(ref, executor: _TestHapticPlatformExecutor())),
              soundServiceProvider.overrideWithValue(_TestSoundService()),
            ],
            child: RepaintBoundary(
              key: repaintKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppThemes.buildThemeData(themeTokens, isDark: themeTokens.isDark),
                home: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _captureToFile(tester, repaintKey, 'docs/shots/settings_${themeItem.name}_${size.label}.png');
      });

      testWidgets('Capture Theme Picker screen [${themeItem.name} - ${size.label}]', (tester) async {
        tester.view.physicalSize = Size(size.w, size.h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith((ref) => _FakeSettingsRepository(SettingsState(themeId: themeItem.id))),
              notificationServiceProvider.overrideWithValue(FakeNotificationService()),
              hapticsServiceProvider.overrideWith((ref) => HapticsService(ref, executor: _TestHapticPlatformExecutor())),
              soundServiceProvider.overrideWithValue(_TestSoundService()),
            ],
            child: RepaintBoundary(
              key: repaintKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppThemes.buildThemeData(themeTokens, isDark: themeTokens.isDark),
                home: const ThemePickerScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _captureToFile(tester, repaintKey, 'docs/shots/theme_picker_${themeItem.name}_${size.label}.png');
      });

      testWidgets('Capture Complete Sheet [${themeItem.name} - ${size.label}]', (tester) async {
        tester.view.physicalSize = Size(size.w, size.h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repaintKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith((ref) => _FakeSettingsRepository(SettingsState(themeId: themeItem.id))),
              notificationServiceProvider.overrideWithValue(FakeNotificationService()),
              hapticsServiceProvider.overrideWith((ref) => HapticsService(ref, executor: _TestHapticPlatformExecutor())),
              soundServiceProvider.overrideWithValue(_TestSoundService()),
            ],
            child: RepaintBoundary(
              key: repaintKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppThemes.buildThemeData(themeTokens, isDark: themeTokens.isDark),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: CompleteSheet(
                      levelId: 36,
                      chapterName: 'Loose Ends',
                      isChapterFinale: false,
                      stars: 3,
                      threadsCleared: 18,
                      mistakes: 0,
                      bestChain: 12,
                      onNextLevel: () {},
                      onReplay: () {},
                      onLevels: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _captureToFile(tester, repaintKey, 'docs/shots/complete_${themeItem.name}_${size.label}.png');
      });
    }
  }
}
