import 'dart:math' as math;

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/features/game/board_painter.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Professional, elegant, production-ready lobby screen for ArrowZ.
///
/// Features:
/// - Top status-safe header with daily streak pill, chapter browser, and settings
/// - Refined brand identity with official emblem, wordmark, and subtitle
/// - Interactive miniature puzzle showcase demonstrating arrow mechanics
/// - Polished chapter & level progression card with star display and chapter progress
/// - Premium, high-contrast primary Play action with fluid press micro-interactions
/// - Calm, architectural geometric background painter
/// - Staggered entrance animations respecting accessibility preferences
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isNavigating = false;
  DateTime? _lastNavTime;

  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();

    // Check Play in-app updates and sync streak status at session start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(playUpdateServiceProvider).checkForUpdates(context);
        ref.read(streakRepositoryProvider.notifier).refreshStreakStatus();
        ref.read(streakRepositoryProvider.notifier).syncReminders(
              ref.read(notificationServiceProvider),
            );
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _resetNav();
      ref.read(streakRepositoryProvider.notifier).refreshStreakStatus();
      ref.read(streakRepositoryProvider.notifier).syncReminders(
            ref.read(notificationServiceProvider),
          );
    }
  }

  bool _canNavigate() {
    final now = DateTime.now();
    if (_isNavigating) return false;
    if (_lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(milliseconds: 500)) {
      return false;
    }
    _lastNavTime = now;
    _isNavigating = true;
    return true;
  }

  void _resetNav() {
    if (mounted) {
      setState(() {
        _isNavigating = false;
      });
    }
  }

  void _onPlay(int levelId) {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.play(levelId)).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  void _onStreak() {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.streak).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  void _onSettings() {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.settings).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  void _onBrowseLevels() {
    if (!_canNavigate()) return;
    ref.read(hapticsServiceProvider).selection();
    context.push(Routes.levels).whenComplete(_resetNav);
    Future.delayed(const Duration(milliseconds: 600), _resetNav);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = ref.watch(progressProvider);
    final streak = ref.watch(streakRepositoryProvider);
    final snapshot = ref.watch(snapshotRepositoryProvider).getSnapshot();
    final currentStreak = streak.currentStreak;

    // Derive active level: if an active in-progress snapshot exists for an unlocked level,
    // resume that level; otherwise launch the player's next unlocked level.
    final currentLevel =
        (snapshot != null && snapshot.levelId <= progress.highestUnlocked)
            ? snapshot.levelId.clamp(1, 200)
            : progress.highestUnlocked.clamp(1, 200);

    final chapterNumber = ((currentLevel - 1) ~/ 20) + 1;
    final levelInChapter = ((currentLevel - 1) % 20) + 1;
    final starsEarned = progress.stars[currentLevel] ?? 0;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // Ambient architectural background lines
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _entranceController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _LobbyBackgroundPainter(
                    color: tokens.ink.withValues(alpha: 0.035),
                    accentColor: tokens.accent.withValues(alpha: 0.04),
                    progress: _entranceController.value,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 620;
                final isVeryCompact = constraints.maxHeight < 520;
                final isSmallWidth = constraints.maxWidth < 360;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420.0),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  isSmallWidth ? 16.0 : Primitives.space24,
                              vertical: isCompact
                                  ? Primitives.space12
                                  : Primitives.space16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── 1. Top Status-Safe Header ───────────────
                                _buildHeader(
                                  tokens: tokens,
                                  currentStreak: currentStreak,
                                  isSmallWidth: isSmallWidth,
                                ),

                                const Spacer(flex: 1),

                                // ── 2. Central Brand Identity ───────────────
                                _buildBrandIdentity(
                                  tokens: tokens,
                                  isCompact: isCompact,
                                  isVeryCompact: isVeryCompact,
                                ),

                                SizedBox(
                                  height: isCompact
                                      ? Primitives.space8
                                      : Primitives.space16,
                                ),

                                // ── 3. Interactive Miniature Puzzle Preview ─
                                if (!isVeryCompact) ...[
                                  _InteractivePuzzlePreview(
                                    tokens: tokens,
                                    isCompact: isCompact,
                                  ),
                                  SizedBox(
                                    height: isCompact
                                        ? Primitives.space12
                                        : Primitives.space16,
                                  ),
                                ],

                                // ── 4. Chapter & Level Progression Box (Level Number) ──
                                _buildProgressionCard(
                                  tokens: tokens,
                                  currentLevel: currentLevel,
                                  chapterNumber: chapterNumber,
                                  levelInChapter: levelInChapter,
                                  starsEarned: starsEarned,
                                  isCompact: isCompact,
                                ),

                                SizedBox(
                                  height: isCompact
                                      ? Primitives.space12
                                      : Primitives.space16,
                                ),

                                // ── 5. Primary Play Action Button (BELOW level number) ──
                                _buildPlayButton(
                                  tokens: tokens,
                                  currentLevel: currentLevel,
                                  isCompact: isCompact,
                                ),

                                const Spacer(flex: 2),

                                SizedBox(
                                  height: isCompact
                                      ? Primitives.space4
                                      : Primitives.space8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Header Component
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHeader({
    required AppTokens tokens,
    required int currentStreak,
    required bool isSmallWidth,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Daily Streak Indicator Pill
          Semantics(
            button: true,
            label: 'Streak: $currentStreak days',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('lobby_streak_button'),
                onTap: _onStreak,
                borderRadius: BorderRadius.circular(20.0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallWidth ? 10.0 : 14.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: currentStreak > 0
                          ? const Color(0xFFE9842B).withValues(alpha: 0.5)
                          : tokens.threadFaint,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.ink.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 20.0,
                        color: currentStreak > 0
                            ? const Color(0xFFE9842B)
                            : tokens.inkMuted,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        '$currentStreak',
                        key: const Key('lobby_streak_text'),
                        style: tokens.typography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              currentStreak > 0 ? tokens.ink : tokens.inkMuted,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Quick Action Navigation Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chapter & Level Browser Icon Button
              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.threadFaint,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.ink.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.grid_view_rounded,
                    color: tokens.ink,
                    size: 20.0,
                  ),
                  tooltip: 'Browse Chapters',
                  onPressed: _onBrowseLevels,
                  constraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: Primitives.space8),

              // Settings Button
              Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.threadFaint,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.ink.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  key: const Key('lobby_settings_button'),
                  icon: Icon(
                    Icons.settings_outlined,
                    color: tokens.ink,
                    size: 20.0,
                  ),
                  tooltip: 'Settings',
                  onPressed: _onSettings,
                  constraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Central Brand Identity
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBrandIdentity({
    required AppTokens tokens,
    required bool isCompact,
    required bool isVeryCompact,
  }) {
    final scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.60, curve: Curves.easeOutCubic),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1.0).animate(scaleAnimation),
      child: FadeTransition(
        opacity: scaleAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Official Game Icon Emblem
            Container(
              width: isCompact ? 64.0 : 80.0,
              height: isCompact ? 64.0 : 80.0,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(isCompact ? 18.0 : 22.0),
                border: Border.all(
                  color: tokens.threadFaint,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tokens.ink.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isCompact ? 16.5 : 20.5),
                child: Image.asset(
                  'assets/icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            SizedBox(
              height: isCompact ? Primitives.space8 : Primitives.space16,
            ),

            // Game Wordmark
            Text(
              'ArrowZ',
              key: const Key('lobby_game_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Primitives.fontDisplay,
                fontSize: isCompact ? 36.0 : 42.0,
                height: 1.1,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              'Escape Puzzle',
              textAlign: TextAlign.center,
              style: tokens.typography.caption.copyWith(
                color: tokens.inkMuted,
                letterSpacing: 2.4,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Progression Card (Level Number Box - Display Only)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildProgressionCard({
    required AppTokens tokens,
    required int currentLevel,
    required int chapterNumber,
    required int levelInChapter,
    required int starsEarned,
    required bool isCompact,
  }) {
    final slideAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    );

    final chapterProgress = (levelInChapter / 20.0).clamp(0.05, 1.0);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.10),
        end: Offset.zero,
      ).animate(slideAnimation),
      child: FadeTransition(
        opacity: slideAnimation,
        child: Semantics(
          label: 'Current level: $currentLevel in chapter $chapterNumber',
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 20.0 : 24.0,
              vertical: isCompact ? 16.0 : 20.0,
            ),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: tokens.threadFaint,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.ink.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Chapter header & stars / count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'CHAPTER $chapterNumber',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.caption.copyWith(
                          color: tokens.accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontSize: 11.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    if (starsEarned > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final filled = i < starsEarned;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            child: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 16.0,
                              color: filled
                                  ? const Color(0xFFE5A93C)
                                  : tokens.threadFaint,
                            ),
                          );
                        }),
                      )
                    else
                      Text(
                        '$levelInChapter of 20',
                        style: tokens.typography.caption.copyWith(
                          color: tokens.inkMuted,
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8.0),

                // Prominent Level Number Box Text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Level $currentLevel',
                        key: const Key('lobby_level_number'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.heading.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          fontSize: isCompact ? 24.0 : 26.0,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12.0),

                // Chapter Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: LinearProgressIndicator(
                    value: chapterProgress,
                    backgroundColor: tokens.threadFaint.withValues(alpha: 0.6),
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                    minHeight: 4.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Primary Play Button
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPlayButton({
    required AppTokens tokens,
    required int currentLevel,
    required bool isCompact,
  }) {
    final slideAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.50, 1.0, curve: Curves.easeOutCubic),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.12),
        end: Offset.zero,
      ).animate(slideAnimation),
      child: FadeTransition(
        opacity: slideAnimation,
        child: FilledButton(
          key: const Key('lobby_play_button'),
          onPressed: () => _onPlay(currentLevel),
          style: FilledButton.styleFrom(
            backgroundColor: tokens.accent,
            foregroundColor: tokens.onAccent,
            minimumSize: Size.fromHeight(isCompact ? 50.0 : 56.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Primitives.radiusButton),
            ),
            elevation: 2,
            shadowColor: tokens.accent.withValues(alpha: 0.35),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                size: 26.0,
              ),
              const SizedBox(width: Primitives.space8),
              Text(
                'Play',
                style: tokens.typography.label.copyWith(
                  color: tokens.onAccent,
                  fontSize: isCompact ? 16.5 : 18.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Interactive Miniature Puzzle Showcase Widget
// ────────────────────────────────────────────────────────────────────────────
class _InteractivePuzzlePreview extends StatefulWidget {
  const _InteractivePuzzlePreview({
    required this.tokens,
    required this.isCompact,
  });

  final AppTokens tokens;
  final bool isCompact;

  @override
  State<_InteractivePuzzlePreview> createState() =>
      _InteractivePuzzlePreviewState();
}

class _InteractivePuzzlePreviewState extends State<_InteractivePuzzlePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final List<double> _slideProgress = [0.0, 0.0, 0.0, 0.0];
  final List<bool> _isExiting = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController.value = 0.5;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onTapArrow(int index) {
    if (_isExiting[index]) return;
    setState(() {
      _isExiting[index] = true;
      _slideProgress[index] = 1.0;
    });

    // Reset back to starting position smoothly
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _slideProgress[index] = 0.0;
        _isExiting[index] = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final width = widget.isCompact ? 200.0 : 230.0;
    final height = widget.isCompact ? 96.0 : 110.0;

    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: tokens.threadFaint,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.ink.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19.0),
          child: Stack(
            children: [
              // Canvas painting grid dots & interactive arrow threads
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _MiniBoardPainter(
                        tokens: tokens,
                        pulseValue: _pulseController.value,
                        slideProgress: _slideProgress,
                      ),
                    );
                  },
                ),
              ),

              // 4 Interactive Tap Zones overlaying the 4 arrow threads
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) {
                    return Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _onTapArrow(0),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _onTapArrow(1),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _onTapArrow(2),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _onTapArrow(3),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Custom Painter for Miniature Puzzle Showcase
// ────────────────────────────────────────────────────────────────────────────
class _MiniBoardPainter extends CustomPainter {
  const _MiniBoardPainter({
    required this.tokens,
    required this.pulseValue,
    required this.slideProgress,
  });

  final AppTokens tokens;
  final double pulseValue;
  final List<double> slideProgress;

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 5;
    const rows = 3;
    final cellW = size.width / (cols + 0.4);
    final cellH = size.height / (rows + 0.4);
    final startX = (size.width - (cols - 1) * cellW) / 2.0;
    final startY = (size.height - (rows - 1) * cellH) / 2.0;

    // 1. Lattice Grid Dots
    final dotPaint = Paint()
      ..color = tokens.gridDot.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(startX + c * cellW, startY + r * cellH),
          1.8,
          dotPaint,
        );
      }
    }

    final threadPaint = Paint()
      ..color = tokens.thread
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final accentThreadPaint = Paint()
      ..color = tokens.accent
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final subtleOffset = (pulseValue - 0.5) * 2.0;

    // Arrow 0: Upward thread (Col 1, Row 2 -> Row 1)
    _drawThread(
      canvas: canvas,
      p1: Offset(startX + 1 * cellW, startY + 2 * cellH),
      p2: Offset(startX + 1 * cellW, startY + 1 * cellH),
      dirAngle: -math.pi / 2,
      paint: accentThreadPaint,
      slideOffset: Offset(0, -slideProgress[0] * cellH * 1.5 + subtleOffset),
      alpha: 1.0 - slideProgress[0],
    );

    // Arrow 1: Rightward thread (Col 1, Row 0 -> Col 2, Row 0)
    _drawThread(
      canvas: canvas,
      p1: Offset(startX + 1 * cellW, startY + 0 * cellH),
      p2: Offset(startX + 2 * cellW, startY + 0 * cellH),
      dirAngle: 0.0,
      paint: threadPaint,
      slideOffset: Offset(slideProgress[1] * cellW * 1.5 - subtleOffset, 0),
      alpha: 1.0 - slideProgress[1],
    );

    // Arrow 2: Downward thread (Col 3, Row 0 -> Row 1)
    _drawThread(
      canvas: canvas,
      p1: Offset(startX + 3 * cellW, startY + 0 * cellH),
      p2: Offset(startX + 3 * cellW, startY + 1 * cellH),
      dirAngle: math.pi / 2,
      paint: threadPaint,
      slideOffset: Offset(0, slideProgress[2] * cellH * 1.5 + subtleOffset),
      alpha: 1.0 - slideProgress[2],
    );

    // Arrow 3: Leftward thread (Col 4, Row 2 -> Col 3, Row 2)
    _drawThread(
      canvas: canvas,
      p1: Offset(startX + 4 * cellW, startY + 2 * cellH),
      p2: Offset(startX + 3 * cellW, startY + 2 * cellH),
      dirAngle: math.pi,
      paint: accentThreadPaint,
      slideOffset: Offset(-slideProgress[3] * cellW * 1.5 - subtleOffset, 0),
      alpha: 1.0 - slideProgress[3],
    );
  }

  void _drawThread({
    required Canvas canvas,
    required Offset p1,
    required Offset p2,
    required double dirAngle,
    required Paint paint,
    required Offset slideOffset,
    required double alpha,
  }) {
    if (alpha <= 0.0) return;

    final effectivePaint = Paint()
      ..color =
          paint.color.withValues(alpha: paint.color.a * alpha.clamp(0.0, 1.0))
      ..strokeWidth = paint.strokeWidth
      ..strokeCap = paint.strokeCap
      ..strokeJoin = paint.strokeJoin
      ..style = paint.style;

    final shiftedP1 = p1 + slideOffset;
    final shiftedP2 = p2 + slideOffset;

    canvas.drawLine(shiftedP1, shiftedP2, effectivePaint);

    drawChevronArrowhead(
      canvas: canvas,
      headPoint: shiftedP2,
      angleRad: dirAngle,
      armLengthPx: 10.5,
      paint: effectivePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniBoardPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.slideProgress != slideProgress ||
        oldDelegate.tokens != tokens;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Ambient Lobby Background Painter
// ────────────────────────────────────────────────────────────────────────────
class _LobbyBackgroundPainter extends CustomPainter {
  const _LobbyBackgroundPainter({
    required this.color,
    required this.accentColor,
    required this.progress,
  });

  final Color color;
  final Color accentColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final accentPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final offset = progress * 6.0;

    // Gentle diagonal thread lines
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.15 + offset),
      Offset(size.width * 0.9, size.height * 0.35 + offset),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.05, size.height * 0.65 - offset),
      Offset(size.width * 0.95, size.height * 0.85 - offset),
      accentPaint,
    );

    // Subtle ambient circles
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.22 + offset),
      22.0,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.78 - offset),
      28.0,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LobbyBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.accentColor != accentColor;
  }
}
