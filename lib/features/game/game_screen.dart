import 'dart:async';

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
import 'package:arrowtapout/features/game/board_view.dart';
import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/features/game/heart_life_indicator.dart';
import 'package:arrowtapout/features/game/hint_service.dart';
import 'package:arrowtapout/features/game/level_progress_bar.dart';
import 'package:arrowtapout/features/game/sheets/complete_sheet.dart';
import 'package:arrowtapout/features/game/sheets/failed_sheet.dart';
import 'package:arrowtapout/features/game/sheets/howto_sheet.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/ad_service.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late BoardAnimator _animator;
  GameController? _controller;
  Level? _level;
  bool _isLoading = true;
  String? _errorMessage;
  bool _sheetOpen = false;
  bool _showDiagnostics = false;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickerTimer;
  int _elapsedSeconds = 0;

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animator = BoardAnimator(vsync: this);
    _stopwatch.start();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_sheetOpen && (_controller?.currentState.status == GameStatus.playing)) {
        setState(() {
          _elapsedSeconds = _stopwatch.elapsed.inSeconds;
        });
      }
    });
    _loadLevel();
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
        if (state.status == GameStatus.completed && !_sheetOpen) {
          _showCompleteSheet(state);
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
    _tickerTimer?.cancel();
    _stopwatch.stop();
    WidgetsBinding.instance.removeObserver(this);
    _animator.finalizeAllRunningAnimations();
    _controller?.dispose();
    _animator.dispose();
    super.dispose();
  }

  bool _isNavigating = false;

  void _handleBackToHome() {
    if (_isNavigating) return;
    _isNavigating = true;

    _animator.finalizeAllRunningAnimations();
    ref.read(hapticsServiceProvider).selection();
    _sheetOpen = false;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  void _handleRestart() {
    if (_controller == null || _level == null || _sheetOpen) return;
    final state = _controller!.currentState;
    final clearedCount = _level!.threads.length - state.activeIds.length;
    final hasProgress = clearedCount > 0 || state.mistakes > 0;

    if (!hasProgress) {
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

    // Preload next level in background while Complete sheet is showing
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
        elapsedSeconds: _elapsedSeconds,
        onNextLevel: () {
          _sheetOpen = false;
          _animator.finalizeAllRunningAnimations();
          context.pushReplacement(Routes.play(state.level.id + 1));
        },
        onLevels: () {
          _sheetOpen = false;
          _animator.finalizeAllRunningAnimations();
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

    final totalThreads = _level!.threads.length;
    final remainingThreads = gameState.activeIds.length;
    Diagnostics.instance.recordGameScreenRebuild();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackToHome();
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
                      horizontal: ComponentTokens.pagePadding,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Back button + Level Title (Long-press enables DiagnosticsOverlay)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const Key('game_back_button'),
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: tokens.ink,
                                size: 24.0,
                              ),
                              tooltip: 'Back to Home',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: ComponentTokens.minTapTargetSize,
                                minHeight: ComponentTokens.minTapTargetSize,
                              ),
                              onPressed: _handleBackToHome,
                            ),
                            const SizedBox(width: Primitives.space4),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () {
                                if (!kReleaseMode) {
                                  setState(() {
                                    _showDiagnostics = !_showDiagnostics;
                                  });
                                }
                              },
                              child: Text(
                                'Level ${widget.levelId}',
                                style: TextStyle(
                                  fontFamily: Primitives.fontDisplay,
                                  fontSize: 22.0,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.ink,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Centre: Heart life indicator + live timer badge
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListenableBuilder(
                            listenable: _controller!.gameStateNotifier,
                            builder: (context, _) => HeartLifeIndicator(
                              remainingLives:
                                  _controller!.currentState.remainingLives,
                              reduceMotion: reduceMotion,
                            ),
                          ),
                          const SizedBox(height: 3.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: tokens.threadFaint.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 12.0,
                                  color: tokens.inkFaint,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  _formatTime(_elapsedSeconds),
                                  style: TextStyle(
                                    fontFamily: Primitives.fontUi,
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.inkMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Right: Replay button + Hint button (top-right corner)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const Key('game_replay_button'),
                            icon: Icon(
                              Icons.refresh_rounded,
                              color: tokens.ink,
                              size: 24.0,
                            ),
                            tooltip: 'Restart level',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: ComponentTokens.minTapTargetSize,
                              minHeight: ComponentTokens.minTapTargetSize,
                            ),
                            onPressed: () {
                              ref.read(hapticsServiceProvider).selection();
                              _handleRestart();
                            },
                          ),
                          const SizedBox(width: Primitives.space4),
                          _HintButton(
                            key: const Key('game_hint_button'),
                            controller: _controller!,
                            tokens: tokens,
                            onHintTap: _handleHintTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- 2. Level Progress Bar ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ComponentTokens.pagePadding,
                  vertical: Primitives.space8,
                ),
                child: ListenableBuilder(
                  listenable: _controller!.gameStateNotifier,
                  builder: (context, _) {
                    Diagnostics.instance.recordHeaderCounterRebuild();
                    return LevelProgressBar(
                      key: const Key('level_progress_bar'),
                      progress: _controller!.currentState.progress,
                      reduceMotion: reduceMotion,
                    );
                  },
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

              // --- 3. Board Region ---
              Expanded(
                child: BoardView(
                  level: _level!,
                  getActiveIds: () => _controller!.currentState.activeIds,
                  animator: _animator,
                  arrowSkin: settings.arrowSkin,
                  reduceMotion: reduceMotion,
                  interactive: !_sheetOpen,
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
                      // Remaining threads counter
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 120),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                    opacity: animation, child: child),
                            child: Builder(
                              key: ValueKey(remainingThreads),
                              builder: (context) {
                                Diagnostics.instance.recordHeaderCounterRebuild();
                                return Text(
                                  '$remainingThreads',
                                  style: TextStyle(
                                    fontFamily: Primitives.fontDisplay,
                                    fontSize: 20.0,
                                    height: 1.0,
                                    fontWeight: FontWeight.w500,
                                    color: tokens.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            'of $totalThreads remaining',
                            style: TextStyle(
                              fontFamily: Primitives.fontUi,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              color: tokens.inkMuted,
                            ),
                          ),
                        ],
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
  });

  final GameController controller;
  final AppTokens tokens;
  final VoidCallback onHintTap;

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

    return Semantics(
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
  }
}
