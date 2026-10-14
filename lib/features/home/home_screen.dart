import 'dart:async';

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/game/board_view.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late BoardAnimator _ambientAnimator;
  late Level _ambientLevel;
  late Set<int> _ambientActiveIds;
  Timer? _ambientLoopTimer;

  static const List<String> _chapterNames = [
    'First Threads',
    'Loose Ends',
    'Straight Talk',
    'Corners',
    'Spirals',
    'Crosscurrents',
    'Dense Weave',
    'Labyrinth',
    'Long Form',
    'Masterworks',
  ];

  @override
  void initState() {
    super.initState();
    _ambientAnimator = BoardAnimator(vsync: this);
    _initAmbientBoard();

    // Check Play in-app updates at session start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playUpdateServiceProvider).checkForUpdates(context);
    });
  }

  void _initAmbientBoard() {
    _ambientLevel = Level(
      id: 999,
      rows: 7,
      cols: 8,
      threads: [
        Thread(1, [const Cell(1, 1), const Cell(1, 2), const Cell(1, 3)]),
        Thread(2, [const Cell(2, 5), const Cell(2, 4), const Cell(2, 3)]),
        Thread(3, [const Cell(4, 1), const Cell(3, 1), const Cell(2, 1)]),
        Thread(4, [const Cell(3, 6), const Cell(4, 6), const Cell(5, 6)]),
        Thread(5, [const Cell(5, 2), const Cell(5, 3), const Cell(5, 4)]),
        Thread(6, [const Cell(0, 4), const Cell(0, 5), const Cell(0, 6)]),
      ],
    );
    _ambientActiveIds = {1, 2, 3, 4, 5, 6};
    _ambientAnimator.setLevel(_ambientLevel, 24.0);

    final reduceMotion = ref.read(settingsProvider).reduceMotion;
    if (!reduceMotion) {
      _startAmbientLoop();
    }
  }

  void _startAmbientLoop() {
    _ambientLoopTimer?.cancel();
    _ambientLoopTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_ambientActiveIds.isEmpty) {
        _ambientActiveIds = {1, 2, 3, 4, 5, 6};
        _ambientAnimator.setLevel(_ambientLevel, 24.0);
        setState(() {});
      } else {
        final nextId = _ambientActiveIds.first;
        _ambientActiveIds.remove(nextId);
        _ambientAnimator.triggerExit(nextId, reduceMotion: false);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ambientLoopTimer?.cancel();
    _ambientAnimator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = ref.watch(progressProvider);
    final snapshot = ref.watch(snapshotRepositoryProvider).getSnapshot();
    final haptics = ref.read(hapticsServiceProvider);

    // If there is an active snapshot for unlocked level, continue that level
    final currentLevel =
        snapshot != null && snapshot.levelId <= progress.highestUnlocked
            ? snapshot.levelId
            : progress.highestUnlocked;

    final chapterIndex = ((currentLevel - 1) ~/ 20).clamp(0, 9);
    final chapterName = _chapterNames[chapterIndex];

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Faint ambient background board
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Center(
                  child: BoardView(
                    level: _ambientLevel,
                    activeIds: _ambientActiveIds,
                    animator: _ambientAnimator,
                    interactive: false,
                    onThreadTap: (_) {},
                  ),
                ),
              ),
            ),

            // Foreground UI
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Primitives.space24,
                vertical: Primitives.space16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Wordmark & Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ArrowZ',
                        style: tokens.typography.title.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.bar_chart_rounded,
                                color: tokens.ink, size: 22.0),
                            tooltip: 'Stats',
                            onPressed: () {
                              haptics.selection();
                              context.push(Routes.stats);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.settings_outlined,
                                color: tokens.ink, size: 22.0),
                            tooltip: 'Settings',
                            onPressed: () {
                              haptics.selection();
                              context.push(Routes.settings);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Center Level Numeral Display
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$currentLevel',
                          style: TextStyle(
                            fontFamily: Primitives.fontDisplay,
                            fontSize: 72.0,
                            height: 1.0,
                            fontWeight: FontWeight.w400,
                            color: tokens.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: Primitives.space8),
                        Text(
                          'Level $currentLevel',
                          style: tokens.typography.heading.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: Primitives.space4),
                        Text(
                          chapterName,
                          style: tokens.typography.body.copyWith(
                            color: tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Action buttons
                  FilledButton(
                    onPressed: () {
                      haptics.selection();
                      context.push(Routes.play(currentLevel));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: tokens.onAccent,
                      minimumSize: const Size.fromHeight(52.0),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: tokens.typography.label.copyWith(
                        color: tokens.onAccent,
                        fontSize: 15.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: Primitives.space12),

                  OutlinedButton(
                    onPressed: () {
                      haptics.selection();
                      context.push(Routes.levels);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.ink,
                      side: BorderSide(color: tokens.threadFaint, width: 1.5),
                      minimumSize: const Size.fromHeight(52.0),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    child: Text(
                      'Levels',
                      style: tokens.typography.label.copyWith(fontSize: 15.0),
                    ),
                  ),

                  const SizedBox(height: Primitives.space8),

                  TextButton(
                    onPressed: () {
                      haptics.selection();
                      context.push(Routes.howToPlay);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.inkMuted,
                      minimumSize: const Size.fromHeight(44.0),
                    ),
                    child: Text(
                      'How to play',
                      style: tokens.typography.label.copyWith(
                        color: tokens.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: Primitives.space8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
