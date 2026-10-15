import 'dart:async';
import 'dart:math' as math;

import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/component_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:arrowtapout/diagnostics/diagnostics_overlay.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/board_plate.dart';
import 'package:arrowtapout/features/game/board_view.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/hint_service.dart';
import 'package:arrowtapout/features/game/life_pips.dart';
import 'package:arrowtapout/features/game/segmented_progress_bar.dart';
import 'package:arrowtapout/features/game/sheets/chapter_complete_view.dart';
import 'package:arrowtapout/features/game/sheets/complete_sheet.dart';
import 'package:arrowtapout/features/game/sheets/failed_sheet.dart';
import 'package:arrowtapout/features/game/sheets/howto_sheet.dart';
import 'package:arrowtapout/features/game/sheets/pause_sheet.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/ad_service.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:arrowtapout/router/nav_utils.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/foundation.dart';
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late BoardAnimator _animator;
  late AnimationController _sweepController;
  late AnimationController _chainPulseController;
  late AnimationController _hintNudgeController;

  GameController? _controller;
  Level? _level;
  bool _isLoading = true;
  String? _errorMessage;
  bool _sheetOpen = false;
  bool _showDiagnostics = false;
  Timer? _idleTimer;
  int _lastChain = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animator = BoardAnimator(vsync: this);

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _chainPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _hintNudgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _resetIdleTimer();
    _loadLevel();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && (_controller?.currentState.status == GameStatus.playing)) {
        if (!ref.read(settingsProvider).reduceMotion) {
          _hintNudgeController.forward(from: 0.0);
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _animator.finalizeAllRunningAnimations();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(soundServiceProvider).onResume();
    }
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
        streakRepo: ref.read(streakRepositoryProvider.notifier),
        notificationService: ref.read(notificationServiceProvider),
        reduceMotion: ref.read(settingsProvider).reduceMotion,
        initialSnapshot: validSnapshot,
        coachMarkShown: coachShown,
      );

      controller.addListener((state) {
        if (!mounted) return;

        // Chain pulse feedback on milestones 5, 10, 15
        if (state.chainCount >= 5 &&
            state.chainCount != _lastChain &&
            (state.chainCount % 5 == 0)) {
          _lastChain = state.chainCount;
          if (!ref.read(settingsProvider).reduceMotion) {
            _chainPulseController.forward(from: 0.0);
          }
        } else if (state.chainCount == 0) {
          _lastChain = 0;
        }

        if (state.status == GameStatus.completed && !_sheetOpen) {
          _triggerLevelComplete(state);
        } else if (state.status == GameStatus.failed && !_sheetOpen) {
          _showFailedSheet(state);
        }
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
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _sweepController.dispose();
    _chainPulseController.dispose();
    _hintNudgeController.dispose();
    _animator.finalizeAllRunningAnimations();
    _controller?.dispose();
    _animator.dispose();
    super.dispose();
  }

  void _handleBackOrPause() {
    if (_sheetOpen) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    _openPauseSheet();
  }

  void _openPauseSheet() {
    if (_sheetOpen) return;
    _sheetOpen = true;
    _animator.finalizeAllRunningAnimations();
    ref.read(hapticsServiceProvider).selection();

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
          _animator.finalizeAllRunningAnimations();
          context.safeBack(fallbackRoute: Routes.levels);
        },
        onQuit: () {
          _sheetOpen = false;
          _animator.finalizeAllRunningAnimations();
          context.safeBack(fallbackRoute: Routes.home);
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _sheetOpen = false;
        });
      }
    });
  }

  void _handleRestart() {
    if (_controller == null || _level == null || _sheetOpen) return;
    final state = _controller!.currentState;
    final clearedCount = _level!.threads.length - state.activeIds.length;
    final hasProgress = clearedCount > 0 || state.mistakes > 0;

    if (!hasProgress) {
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

    _sheetOpen = true;
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
                    key: const Key('restart_cancel_button'),
                    onPressed: () {
                      haptics.selection();
                      Navigator.of(ctx).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.ink,
                      side: BorderSide(color: tokens.line),
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
                    key: const Key('restart_confirm_button'),
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
    ).then((_) => _sheetOpen = false);
  }

  Future<void> _handleHintTap() async {
    if (_controller == null || _sheetOpen) return;

    _resetIdleTimer();
    unawaited(ref.read(hapticsServiceProvider).selection());
    final hintService = ref.read(hintServiceProvider);

    final result = await hintService.requestRewardedHint(
      controller: _controller!,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      unawaited(ref.read(hapticsServiceProvider).light());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Hint applied! Look for the highlighted arrow.',
            style: const TextStyle(fontFamily: Primitives.fontUi),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (result.status != HintResultStatus.alreadyInProgress) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? 'Hint unavailable.',
              style: const TextStyle(fontFamily: Primitives.fontUi),
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openHowToPlaySheet() {
    if (_sheetOpen) return;
    _resetIdleTimer();
    _sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const HowToPlaySheet(),
    ).then((_) => _sheetOpen = false);
  }

  Future<void> _triggerLevelComplete(GameState state) async {
    _idleTimer?.cancel();

    // 350 ms stillness
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    // 500 ms perimeter sweep
    if (!ref.read(settingsProvider).reduceMotion) {
      await _sweepController.forward(from: 0.0);
    }
    if (!mounted) return;

    if (state.level.id % 20 == 0) {
      _showChapterCompleteView(state);
    } else {
      _showCompleteSheet(state);
    }
  }

  void _showChapterCompleteView(GameState state) {
    if (_sheetOpen) return;
    _sheetOpen = true;
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
    final chIdx = state.level.chapter - 1;
    final chName = (chIdx >= 0 && chIdx < chapterNames.length)
        ? chapterNames[chIdx]
        : 'Chapter ${state.level.chapter}';
    final nextName = (chIdx + 1 < chapterNames.length)
        ? chapterNames[chIdx + 1]
        : '';

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secAnim) => ChapterCompleteView(
          chapterNumber: state.level.chapter,
          chapterName: chName,
          nextChapterName: nextName,
          totalStars: ref.read(progressProvider).totalStars,
          onContinue: () {
            Navigator.of(ctx).pop();
            _sheetOpen = false;
            _animator.finalizeAllRunningAnimations();
            context.pushReplacement(Routes.play(state.level.id + 1));
          },
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _sheetOpen = false);
      }
    });
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
    final chIdx = state.level.chapter - 1;
    final chName = (chIdx >= 0 && chIdx < chapterNames.length)
        ? chapterNames[chIdx]
        : 'Chapter ${state.level.chapter}';

    unawaited(ref.read(levelRepositoryProvider).loadLevel(state.level.id + 1));

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
        bestChain: state.bestChain,
        onNextLevel: () {
          _sheetOpen = false;
          _animator.finalizeAllRunningAnimations();
          context.pushReplacement(Routes.play(state.level.id + 1));
        },
        onReplay: () {
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
          _animator.finalizeAllRunningAnimations();
          context.safeBack(fallbackRoute: Routes.levels);
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _sheetOpen = false;
        });
      }
    });
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
          context.safeBack(fallbackRoute: Routes.levels);
        },
      ),
    ).then((_) => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = ref.watch(settingsProvider);
    final reduceMotion = settings.reduceMotion;

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
                  onPressed: () => context.safeBack(fallbackRoute: Routes.levels),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.ink,
                    side: BorderSide(color: tokens.line),
                  ),
                  child: Text('Levels', style: tokens.typography.label),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
    final chIdx = _level!.chapter - 1;
    final currentChapterName = (chIdx >= 0 && chIdx < chapterNames.length)
        ? chapterNames[chIdx]
        : 'Chapter ${_level!.chapter}';

    final totalThreads = _level!.threads.length;
    Diagnostics.instance.recordGameScreenRebuild();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackOrPause();
        }
      },
      child: DiagnosticsOverlay(
        isVisible: _showDiagnostics,
        onClose: () => setState(() => _showDiagnostics = false),
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
                      horizontal: 14.0,
                    ),
                    child: Row(
                      children: [
                        // Left: Back button + Level Title + Chapter Caption
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                key: const Key('game_back_button'),
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: tokens.ink,
                                  size: 24.0,
                                ),
                                tooltip: 'Pause / Back',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40.0,
                                  minHeight: 40.0,
                                ),
                                onPressed: _handleBackOrPause,
                              ),
                              const SizedBox(width: 4.0),
                              Flexible(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onLongPress: () {
                                    if (!kReleaseMode) {
                                      setState(() {
                                        _showDiagnostics = !_showDiagnostics;
                                      });
                                    }
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Level ${widget.levelId}',
                                        style: TextStyle(
                                          fontFamily: Primitives.fontDisplay,
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        currentChapterName,
                                        style: tokens.typography.caption.copyWith(
                                          color: tokens.inkMuted,
                                          height: 1.0,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Centre: Life Pips (Accent capsules)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ListenableBuilder(
                            listenable: _controller!.gameStateNotifier,
                            builder: (context, _) => LifePips(
                              remainingLives:
                                  _controller!.currentState.remainingLives,
                              reduceMotion: reduceMotion,
                            ),
                          ),
                        ),

                        // Right: Restart + Hint Button
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const Key('game_replay_button'),
                              icon: Icon(
                                Icons.refresh_rounded,
                                color: tokens.ink,
                                size: 22.0,
                              ),
                              tooltip: 'Restart level',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40.0,
                                minHeight: 40.0,
                              ),
                              onPressed: () {
                                ref.read(hapticsServiceProvider).selection();
                                _handleRestart();
                              },
                            ),
                            const SizedBox(width: 2.0),
                            _HintButton(
                              key: const Key('game_hint_button'),
                              controller: _controller!,
                              tokens: tokens,
                              onHintTap: _handleHintTap,
                              nudgeAnimation: _hintNudgeController,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Coach Mark (Level 1)
                ListenableBuilder(
                  listenable: _controller!.gameStateNotifier,
                  builder: (context, _) {
                    if (!_controller!.currentState.showCoachMark) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
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
                    );
                  },
                ),

                // --- 2. Board Region inside BoardPlate ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                          [_chainPulseController, _sweepController]),
                      builder: (context, child) {
                        return BoardPlate(
                          chainPulseProgress: _chainPulseController.value,
                          completeSweepProgress: _sweepController.value,
                          child: BoardView(
                            level: _level!,
                            getActiveIds: () =>
                                _controller!.currentState.activeIds,
                            animator: _animator,
                            reduceMotion: reduceMotion,
                            interactive: !_sheetOpen,
                            onThreadTap: (id) {
                              _resetIdleTimer();
                              _controller?.handleThreadTap(id, _animator.cellSize);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // --- 3. Bottom Segmented Progress Bar & Chain ---
                ListenableBuilder(
                  listenable: _controller!.gameStateNotifier,
                  builder: (context, _) {
                    final state = _controller!.currentState;
                    final cleared = totalThreads - state.activeIds.length;
                    return SegmentedProgressBar(
                      totalThreads: totalThreads,
                      clearedThreads: cleared,
                      chainCount: state.chainCount,
                      onHowToPlay: _openHowToPlaySheet,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintButton extends ConsumerWidget {
  const _HintButton({
    super.key,
    required this.controller,
    required this.tokens,
    required this.onHintTap,
    this.nudgeAnimation,
  });

  final GameController controller;
  final AppTokens tokens;
  final VoidCallback onHintTap;
  final Animation<double>? nudgeAnimation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hintService = ref.watch(hintServiceProvider);
    final adService = ref.watch(rewardedAdServiceProvider);
    final gameState = controller.currentState;

    final isLevelPlaying = gameState.status == GameStatus.playing;
    final isRequesting = hintService.isRequestInProgress;
    final isAdLoading = adService.state == RewardedAdState.loading;

    final isInteractive = isLevelPlaying && !isRequesting;

    Widget iconWidget;
    if (isRequesting || isAdLoading) {
      iconWidget = SizedBox(
        width: 18.0,
        height: 18.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
        ),
      );
    } else {
      iconWidget = Icon(
        Icons.lightbulb_outline_rounded,
        color: isInteractive ? tokens.accent : tokens.inkFaint,
        size: 24.0,
      );
    }

    final Widget button = Semantics(
      button: true,
      label: 'Hint',
      enabled: isInteractive,
      child: IconButton(
        icon: iconWidget,
        tooltip: 'Hint',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: ComponentTokens.minTapTargetSize,
          minHeight: ComponentTokens.minTapTargetSize,
        ),
        onPressed: isInteractive ? onHintTap : null,
      ),
    );

    if (nudgeAnimation != null) {
      return AnimatedBuilder(
        animation: nudgeAnimation!,
        builder: (context, child) {
          final scale = 1.0 + (math.sin(nudgeAnimation!.value * math.pi) * 0.18);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: button,
      );
    }

    return button;
  }
}
