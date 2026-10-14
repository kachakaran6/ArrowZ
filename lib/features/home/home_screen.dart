import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/data/streak_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:arrowtapout/platform/play_update_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Professional, elegant lobby screen for ArrowZ.
///
/// Features:
/// - Refined game branding with the official game icon emblem
/// - Ambient decorative arrow motifs that breathe calmly
/// - Interactive cardinal arrow tiles with haptic tactile response
/// - Chapter and level progression card with star display
/// - High-contrast, satisfying primary Play action
/// - Sleek daily streak indicator pill
/// - Direct access to the Level Browser and Settings
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
  int _tappedArrowIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
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

  void _onTapArrowTile(int index) {
    ref.read(hapticsServiceProvider).light();
    setState(() {
      _tappedArrowIndex = index;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _tappedArrowIndex = -1;
        });
      }
    });
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
    final starsEarned = progress.stars[currentLevel] ?? 0;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // Ambient animated background arrows
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
                final isCompact = constraints.maxHeight < 540;

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
                            padding: const EdgeInsets.symmetric(
                              horizontal: Primitives.space24,
                              vertical: Primitives.space16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Top Header Row ─────────────────────────
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Daily Streak Pill
                                    Semantics(
                                      button: true,
                                      label: 'Streak: $currentStreak days',
                                      child: InkWell(
                                        key: const Key('lobby_streak_button'),
                                        onTap: _onStreak,
                                        borderRadius: BorderRadius.circular(
                                          Primitives.radiusButton,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14.0,
                                            vertical: 8.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tokens.surface,
                                            borderRadius: BorderRadius.circular(
                                              Primitives.radiusButton,
                                            ),
                                            border: Border.all(
                                              color: currentStreak > 0
                                                  ? const Color(0xFFE5A93C)
                                                      .withValues(alpha: 0.45)
                                                  : tokens.threadFaint,
                                              width: 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: tokens.ink
                                                    .withValues(alpha: 0.03),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons
                                                    .local_fire_department_rounded,
                                                size: 20.0,
                                                color: currentStreak > 0
                                                    ? const Color(0xFFE57B24)
                                                    : tokens.inkMuted,
                                              ),
                                              const SizedBox(width: 6.0),
                                              Text(
                                                '$currentStreak',
                                                key: const Key(
                                                    'lobby_streak_text'),
                                                style: tokens.typography.body
                                                    .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: currentStreak > 0
                                                      ? tokens.ink
                                                      : tokens.inkMuted,
                                                  fontSize: 15.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Quick Action Buttons
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
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const SizedBox(
                                            width: Primitives.space8),

                                        // Settings Button
                                        Container(
                                          decoration: BoxDecoration(
                                            color: tokens.surface,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: tokens.threadFaint,
                                              width: 1.0,
                                            ),
                                          ),
                                          child: IconButton(
                                            key: const Key(
                                                'lobby_settings_button'),
                                            icon: Icon(
                                              Icons.settings_outlined,
                                              color: tokens.ink,
                                              size: 20.0,
                                            ),
                                            tooltip: 'Settings',
                                            onPressed: _onSettings,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const Spacer(flex: 2),

                                // ── Center Brand & Interactive Game Showcase ─
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Official Game Icon Emblem
                                      Container(
                                        width: isCompact ? 60.0 : 84.0,
                                        height: isCompact ? 60.0 : 84.0,
                                        decoration: BoxDecoration(
                                          color: tokens.surface,
                                          borderRadius: BorderRadius.circular(
                                              isCompact ? 16.0 : 24.0),
                                          border: Border.all(
                                            color: tokens.threadFaint,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: tokens.ink
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              isCompact ? 14.5 : 22.5),
                                          child: Image.asset(
                                            'assets/icon.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),

                                      SizedBox(
                                        height: isCompact
                                            ? Primitives.space8
                                            : Primitives.space16,
                                      ),

                                      // Game Title
                                      Text(
                                        'ArrowZ',
                                        key: const Key('lobby_game_title'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: Primitives.fontDisplay,
                                          fontSize: isCompact ? 36.0 : 44.0,
                                          height: 1.1,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.5,
                                          color: tokens.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4.0),
                                      Text(
                                        'Thread Puzzle',
                                        textAlign: TextAlign.center,
                                        style:
                                            tokens.typography.caption.copyWith(
                                          color: tokens.inkMuted,
                                          letterSpacing: 2.2,
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),

                                      SizedBox(
                                        height: isCompact
                                            ? Primitives.space12
                                            : Primitives.space20,
                                      ),

                                      // Interactive Mini Arrow Showcase
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildArrowTile(
                                            0,
                                            Icons.arrow_upward_rounded,
                                            const Offset(0, -5),
                                            tokens,
                                            isCompact,
                                          ),
                                          const SizedBox(
                                              width: Primitives.space8),
                                          _buildArrowTile(
                                            1,
                                            Icons.arrow_forward_rounded,
                                            const Offset(5, 0),
                                            tokens,
                                            isCompact,
                                          ),
                                          const SizedBox(
                                              width: Primitives.space8),
                                          _buildArrowTile(
                                            2,
                                            Icons.arrow_downward_rounded,
                                            const Offset(0, 5),
                                            tokens,
                                            isCompact,
                                          ),
                                          const SizedBox(
                                              width: Primitives.space8),
                                          _buildArrowTile(
                                            3,
                                            Icons.arrow_back_rounded,
                                            const Offset(-5, 0),
                                            tokens,
                                            isCompact,
                                          ),
                                        ],
                                      ),

                                      SizedBox(
                                        height: isCompact
                                            ? Primitives.space12
                                            : Primitives.space20,
                                      ),

                                      // Current Level Progression Badge
                                      Semantics(
                                        button: true,
                                        label: 'Play Level $currentLevel',
                                        child: InkWell(
                                          onTap: () => _onPlay(currentLevel),
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  isCompact ? 16.0 : 22.0,
                                              vertical: isCompact ? 8.0 : 10.0,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tokens.surface,
                                              borderRadius:
                                                  BorderRadius.circular(16.0),
                                              border: Border.all(
                                                color: tokens.threadFaint,
                                                width: 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: tokens.ink
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Chapter $chapterNumber',
                                                  style: tokens
                                                      .typography.caption
                                                      .copyWith(
                                                    color: tokens.accent,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.2,
                                                    fontSize: 11.0,
                                                  ),
                                                ),
                                                const SizedBox(height: 2.0),
                                                Text(
                                                  'Level $currentLevel',
                                                  key: const Key(
                                                      'lobby_level_number'),
                                                  textAlign: TextAlign.center,
                                                  style: tokens
                                                      .typography.heading
                                                      .copyWith(
                                                    color: tokens.ink,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                    fontSize:
                                                        isCompact ? 18.0 : 20.0,
                                                  ),
                                                ),
                                                if (starsEarned > 0) ...[
                                                  const SizedBox(height: 4.0),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children:
                                                        List.generate(3, (i) {
                                                      final filled =
                                                          i < starsEarned;
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    2.0),
                                                        child: Icon(
                                                          filled
                                                              ? Icons
                                                                  .star_rounded
                                                              : Icons
                                                                  .star_border_rounded,
                                                          size: 15.0,
                                                          color: filled
                                                              ? const Color(
                                                                  0xFFE5A93C)
                                                              : tokens
                                                                  .threadFaint,
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(flex: 3),

                                // ── Primary Play Action Button ──────────────
                                FilledButton(
                                  key: const Key('lobby_play_button'),
                                  onPressed: () => _onPlay(currentLevel),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: tokens.accent,
                                    foregroundColor: tokens.onAccent,
                                    minimumSize: Size.fromHeight(
                                        isCompact ? 48.0 : 56.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        Primitives.radiusButton,
                                      ),
                                    ),
                                    elevation: 2,
                                    shadowColor:
                                        tokens.accent.withValues(alpha: 0.35),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 24.0,
                                      ),
                                      const SizedBox(width: Primitives.space8),
                                      Text(
                                        'Play',
                                        style: tokens.typography.label.copyWith(
                                          color: tokens.onAccent,
                                          fontSize: isCompact ? 16.0 : 18.0,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: Primitives.space12),
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

  Widget _buildArrowTile(
    int index,
    IconData icon,
    Offset shift,
    AppTokens tokens,
    bool isCompact,
  ) {
    final isTapped = _tappedArrowIndex == index;
    final size = isCompact ? 36.0 : 42.0;

    return GestureDetector(
      onTap: () => _onTapArrowTile(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          isTapped ? shift.dx : 0.0,
          isTapped ? shift.dy : 0.0,
          0.0,
        ),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color:
              isTapped ? tokens.accent.withValues(alpha: 0.15) : tokens.surface,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isTapped ? tokens.accent : tokens.threadFaint,
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
        child: Icon(
          icon,
          size: isCompact ? 16.0 : 18.0,
          color: isTapped ? tokens.accent : tokens.inkMuted,
        ),
      ),
    );
  }
}

/// Custom painter for serene, ambient geometric thread lines across the lobby background.
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
