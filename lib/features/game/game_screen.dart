import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/component_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/board_view.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/heart_life_indicator.dart';
import 'package:arrowtapout/features/game/sheets/complete_sheet.dart';
import 'package:arrowtapout/features/game/sheets/failed_sheet.dart';
import 'package:arrowtapout/features/game/sheets/howto_sheet.dart';
import 'package:arrowtapout/features/game/sheets/pause_sheet.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    required this.levelId,
  });

  final int levelId;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late BoardAnimator _animator;
  GameController? _controller;
  Level? _level;
  bool _isLoading = true;
  String? _errorMessage;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _animator = BoardAnimator(vsync: this);
    _loadLevel();
  }

  Future<void> _loadLevel() async {
    try {
      final level =
          await ref.read(levelRepositoryProvider).loadLevel(widget.levelId);
      final snapshot = ref.read(snapshotRepositoryProvider).getSnapshot();
      final validSnapshot =
          (snapshot != null && snapshot.levelId == widget.levelId)
              ? snapshot
              : null;
      final coachShown = ref.read(progressProvider).coachMarkShown;

      final controller = GameController(
        level: level,
        animator: _animator,
        audio: ref.read(audioServiceProvider),
        haptics: ref.read(hapticsServiceProvider),
        progress: ref.read(progressProvider.notifier),
        snapshotRepo: ref.read(snapshotRepositoryProvider),
        reduceMotion: ref.read(settingsProvider).reduceMotion,
        initialSnapshot: validSnapshot,
        coachMarkShown: coachShown,
      );

      controller.addListener((_) {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _level = level;
          _controller = controller;
          _isLoading = false;
        });
        _animator.startEntrance(
          level.threads.length,
          reduceMotion: ref.read(settingsProvider).reduceMotion,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'This level could not be loaded.';
        });
      }
    }
  }

  @override
  void dispose() {
    _animator.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _openPauseSheet() {
    if (_sheetOpen || _controller == null) return;
    _sheetOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => PauseSheet(
        onResume: () {
          _sheetOpen = false;
        },
        onRestart: () {
          _sheetOpen = false;
          _handleRestart();
        },
        onLevels: () {
          _sheetOpen = false;
          context.go(Routes.levels);
        },
      ),
    ).then((_) => _sheetOpen = false);
  }

  void _handleRestart() {
    if (_controller == null || _level == null) return;
    final state = _controller!.currentState;
    final clearedCount = _level!.threads.length - state.activeIds.length;

    if (clearedCount == 0) {
      // Nothing cleared yet, restart directly without confirmation
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cellSize = ComponentTokens.computeLatticeCellSize(
        screenWidth: MediaQuery.sizeOf(context).width,
        boardRegionHeight: MediaQuery.sizeOf(context).height * 0.65,
        rows: _level!.rows,
        cols: _level!.cols,
        devicePixelRatio: dpr,
      );
      _controller?.restartLevel(cellSize);
      return;
    }

    // Show small confirm sheet
    final tokens = context.tokens;
    final haptics = ref.read(hapticsServiceProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: Primitives.space24,
          right: Primitives.space24,
          top: Primitives.space24,
          bottom: MediaQuery.paddingOf(context).bottom + Primitives.space24,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Primitives.radiusSheet),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Restart level?',
              style: tokens.typography.title,
            ),
            const SizedBox(height: Primitives.space8),
            Text(
              'Your current puzzle progress will be reset.',
              style: tokens.typography.body.copyWith(color: tokens.inkMuted),
            ),
            const SizedBox(height: Primitives.space24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      haptics.selection();
                      Navigator.of(ctx).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.ink,
                      side: BorderSide(color: tokens.threadFaint),
                      minimumSize: const Size(double.infinity, 48.0),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    child: Text('Cancel', style: tokens.typography.label),
                  ),
                ),
                const SizedBox(width: Primitives.space16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      haptics.selection();
                      Navigator.of(ctx).pop();
                      final dpr = MediaQuery.devicePixelRatioOf(context);
                      final cellSize = ComponentTokens.computeLatticeCellSize(
                        screenWidth: MediaQuery.sizeOf(context).width,
                        boardRegionHeight:
                            MediaQuery.sizeOf(context).height * 0.65,
                        rows: _level!.rows,
                        cols: _level!.cols,
                        devicePixelRatio: dpr,
                      );
                      _controller?.restartLevel(cellSize);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48.0),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    child: Text('Restart',
                        style: tokens.typography.label
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openHowToPlaySheet() {
    if (_sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const HowToPlaySheet(),
    ).then((_) => _sheetOpen = false);
  }

  void _showCompleteSheet(GameState state) {
    if (_sheetOpen) return;
    _sheetOpen = true;

    final isFinale = state.level.id % 20 == 0;
    const chapterNames = [
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
    final chName = chapterNames[state.level.chapter - 1];

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: true,
      builder: (ctx) => CompleteSheet(
        levelId: state.level.id,
        chapterName: chName,
        isChapterFinale: isFinale,
        stars: state.stars,
        threadsCleared: state.level.threads.length,
        mistakes: state.mistakes,
        onNextLevel: () {
          _sheetOpen = false;
          context.pushReplacement(Routes.play(state.level.id + 1));
        },
        onLevels: () {
          _sheetOpen = false;
          context.go(Routes.levels);
        },
      ),
    ).then((_) => _sheetOpen = false);
  }

  void _showFailedSheet(GameState state) {
    if (_sheetOpen) return;
    _sheetOpen = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: true,
      builder: (ctx) => FailedSheet(
        onRetry: () {
          _sheetOpen = false;
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final cellSize = ComponentTokens.computeLatticeCellSize(
            screenWidth: MediaQuery.sizeOf(context).width,
            boardRegionHeight: MediaQuery.sizeOf(context).height * 0.65,
            rows: _level!.rows,
            cols: _level!.cols,
            devicePixelRatio: dpr,
          );
          _controller?.restartLevel(cellSize);
        },
        onLevels: () {
          _sheetOpen = false;
          context.go(Routes.levels);
        },
      ),
    ).then((_) => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = ref.watch(settingsProvider);
    final reduceMotion = settings.reduceMotion;
    final hintBank = ref.watch(progressProvider).hintBank;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: tokens.bg,
        body: const SizedBox.shrink(),
      );
    }

    if (_errorMessage != null || _level == null || _controller == null) {
      return Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage ?? 'Level not found',
                  style: tokens.typography.body,
                ),
                const SizedBox(height: Primitives.space16),
                OutlinedButton(
                  onPressed: () => context.go(Routes.levels),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.ink,
                    side: BorderSide(color: tokens.threadFaint),
                  ),
                  child: Text('Levels', style: tokens.typography.label),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final gameState = _controller!.currentState;

    // Check completion & failure transitions
    if (gameState.status == GameStatus.completed && !_sheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompleteSheet(gameState);
      });
    } else if (gameState.status == GameStatus.failed && !_sheetOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFailedSheet(gameState);
      });
    }

    final canUseHint = hintBank > 0 && gameState.hintsUsed < 3;
    final totalThreads = _level!.threads.length;
    final remainingThreads = gameState.activeIds.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _openPauseSheet();
        }
      },
      child: Scaffold(
        backgroundColor: tokens.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. Header (Height 64) ---
              SizedBox(
                height: 64.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ComponentTokens.pagePadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Back button + Level Title
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: tokens.ink,
                              size: 24.0,
                            ),
                            tooltip: 'Pause',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: ComponentTokens.minTapTargetSize,
                              minHeight: ComponentTokens.minTapTargetSize,
                            ),
                            onPressed: () {
                              ref.read(hapticsServiceProvider).selection();
                              _openPauseSheet();
                            },
                          ),
                          const SizedBox(width: Primitives.space4),
                          Text(
                            'Level ${widget.levelId}',
                            style: TextStyle(
                              fontFamily: Primitives.fontDisplay,
                              fontSize: 24.0,
                              fontWeight: FontWeight.w500,
                              color: tokens.ink,
                            ),
                          ),
                        ],
                      ),

                      // Centre: Heart life indicator (3 lives: red = active, white = lost)
                      HeartLifeIndicator(
                        remainingLives: gameState.remainingLives,
                        reduceMotion: reduceMotion,
                      ),

                      // Right: Remaining counter ("12" / "of 12")
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 120),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                    opacity: animation, child: child),
                            child: Text(
                              '$remainingThreads',
                              key: ValueKey(remainingThreads),
                              style: TextStyle(
                                fontFamily: Primitives.fontDisplay,
                                fontSize: 28.0,
                                height: 1.0,
                                fontWeight: FontWeight.w500,
                                color: tokens.ink,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                          Text(
                            'of $totalThreads',
                            style: TextStyle(
                              fontFamily: Primitives.fontUi,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- 2. Top Hairline ---
              Container(
                height: 1.0,
                margin: const EdgeInsets.symmetric(
                  horizontal: ComponentTokens.pagePadding,
                ),
                color: tokens.threadFaint,
              ),

              // Coach Mark (Level 1)
              if (gameState.showCoachMark)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ComponentTokens.pagePadding,
                    vertical: Primitives.space8,
                  ),
                  child: Text(
                    'Tap a thread that has a clear path.',
                    style: tokens.typography.body.copyWith(
                      color: tokens.accent,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // --- 3. Board Region ---
              Expanded(
                child: BoardView(
                  level: _level!,
                  activeIds: gameState.activeIds,
                  animator: _animator,
                  reduceMotion: reduceMotion,
                  interactive:
                      !_sheetOpen && gameState.status == GameStatus.playing,
                  onThreadTap: (id) {
                    final dpr = MediaQuery.devicePixelRatioOf(context);
                    final cellSize = ComponentTokens.computeLatticeCellSize(
                      screenWidth: MediaQuery.sizeOf(context).width,
                      boardRegionHeight:
                          MediaQuery.sizeOf(context).height * 0.65,
                      rows: _level!.rows,
                      cols: _level!.cols,
                      devicePixelRatio: dpr,
                    );
                    _controller?.handleThreadTap(id, cellSize);
                    setState(() {});
                  },
                ),
              ),

              // --- 4. Bottom Hairline ---
              Container(
                height: 1.0,
                margin: const EdgeInsets.symmetric(
                  horizontal: ComponentTokens.pagePadding,
                ),
                color: tokens.threadFaint,
              ),

              // --- 5. Bottom Bar (Height 56 + Inset) ---
              SizedBox(
                height: 56.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ComponentTokens.pagePadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Restart (Left aligned)
                      InkWell(
                        onTap: () {
                          ref.read(hapticsServiceProvider).selection();
                          _handleRestart();
                        },
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: ComponentTokens.minTapTargetSize,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 20.0,
                                color: tokens.inkMuted,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                'Restart',
                                style: TextStyle(
                                  fontFamily: Primitives.fontUi,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Hint (Centred)
                      InkWell(
                        onTap: canUseHint
                            ? () {
                                ref.read(hapticsServiceProvider).selection();
                                _controller?.useHint();
                              }
                            : null,
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: ComponentTokens.minTapTargetSize,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20.0,
                                color: canUseHint
                                    ? tokens.accent
                                    : tokens.inkFaint,
                              ),
                              const SizedBox(width: 6.0),
                              RichText(
                                text: TextSpan(
                                  text: 'Hint  ',
                                  style: TextStyle(
                                    fontFamily: Primitives.fontUi,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    color: canUseHint
                                        ? tokens.inkMuted
                                        : tokens.inkFaint,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '$hintBank',
                                      style: TextStyle(
                                        fontFamily: Primitives.fontUi,
                                        fontSize: 14.0,
                                        fontWeight: FontWeight.w700,
                                        color: canUseHint
                                            ? tokens.accent
                                            : tokens.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // How to play (Right aligned)
                      InkWell(
                        onTap: () {
                          ref.read(hapticsServiceProvider).selection();
                          _openHowToPlaySheet();
                        },
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: ComponentTokens.minTapTargetSize,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                size: 20.0,
                                color: tokens.inkMuted,
                              ),
                              const SizedBox(width: 6.0),
                              Text(
                                'How to play',
                                style: TextStyle(
                                  fontFamily: Primitives.fontUi,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
