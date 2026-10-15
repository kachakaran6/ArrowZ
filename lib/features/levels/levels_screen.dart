import 'dart:math' as math;

import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/levels/level_miniature_painter.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/play_review_service.dart';
import 'package:arrowtapout/router/nav_utils.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChapterInfo {
  const ChapterInfo({
    required this.number,
    required this.name,
    required this.description,
  });

  final int number;
  final String name;
  final String description;
}

const List<ChapterInfo> allChapters = [
  ChapterInfo(
      number: 1,
      name: 'First Threads',
      description: 'Gentle introduction to clearing paths.'),
  ChapterInfo(
      number: 2,
      name: 'Loose Ends',
      description: 'New silhouette showpieces and branching routes.'),
  ChapterInfo(
      number: 3,
      name: 'Straight Talk',
      description: 'Long straight paths with varied ray lengths.'),
  ChapterInfo(
      number: 4,
      name: 'Corners',
      description: 'High turn density and interlocking threads.'),
  ChapterInfo(
      number: 5,
      name: 'Spirals',
      description: 'Woven spirals and nested pockets.'),
  ChapterInfo(
      number: 6,
      name: 'Crosscurrents',
      description: 'Crossing exit paths and layered sequencing.'),
  ChapterInfo(
      number: 7,
      name: 'Dense Weave',
      description: 'Tightly packed threads with few open gaps.'),
  ChapterInfo(
      number: 8,
      name: 'Labyrinth',
      description: 'Deep chains with minimal initial free threads.'),
  ChapterInfo(
      number: 9,
      name: 'Long Form',
      description: 'Extended thread paths and complex cascades.'),
  ChapterInfo(
      number: 10,
      name: 'Masterworks',
      description: 'Grand silhouette boards and master puzzles.'),
  ChapterInfo(
      number: 11,
      name: 'Convergences',
      description: 'Intricate crossing threads requiring careful foresight.'),
  ChapterInfo(
      number: 12,
      name: 'Vortex',
      description: 'Centripetal paths spiraling inward and outward.'),
  ChapterInfo(
      number: 13,
      name: 'Tanglewood',
      description: 'Dense branching patterns with tight clearances.'),
  ChapterInfo(
      number: 14,
      name: 'Circuitry',
      description: 'Precision angles and interlocking directional relays.'),
  ChapterInfo(
      number: 15,
      name: 'Echo Chamber',
      description: 'Deflector-heavy chambers with bouncing cascades.'),
  ChapterInfo(
      number: 16,
      name: 'Iron Lattice',
      description: 'Rigid interlocking grids testing multi-step dependencies.'),
  ChapterInfo(
      number: 17,
      name: 'Shadow Labyrinth',
      description: 'Complex animal and geometric silhouettes.'),
  ChapterInfo(
      number: 18,
      name: 'Zenith',
      description: 'Ascending challenges pushing high turn-density navigation.'),
  ChapterInfo(
      number: 19,
      name: 'Grand Tapestry',
      description: 'Expansive 28x28 canvases with deep solve chains.'),
  ChapterInfo(
      number: 20,
      name: 'Quantum Threads',
      description: 'Paired color locks and multi-arrow simultaneous exits.'),
  ChapterInfo(
      number: 21,
      name: 'Nexus',
      description: 'Centralized junction hubs demanding exact clearance order.'),
  ChapterInfo(
      number: 22,
      name: 'Infinity Grid',
      description: 'Colossal 30x30 fields with intertwined arrows.'),
  ChapterInfo(
      number: 23,
      name: 'Celestial Knot',
      description: 'Mythic geometric showpieces with tight deflector routes.'),
  ChapterInfo(
      number: 24,
      name: 'Apex Legends',
      description: 'Peak boss puzzles designed for expert tactile strategists.'),
  ChapterInfo(
      number: 25,
      name: 'Grand Ascendance',
      description: 'The ultimate 500-level mastery campaign finale.'),
];

class LevelsScreen extends ConsumerStatefulWidget {
  const LevelsScreen({super.key});

  /// Deterministically computes the scroll offset for a given highestUnlocked level.
  static double computeChapterOffset(int highestUnlocked,
      {double chapterHeight = 560.0}) {
    final chapterIdx = ((highestUnlocked - 1) ~/ 20).clamp(0, 24);
    return chapterIdx * chapterHeight;
  }

  @override
  ConsumerState<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends ConsumerState<LevelsScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;
  int? _lockedShakeLevelId;
  String? _lockedHintMessage;
  bool _showCurrentPill = false;

  @override
  void initState() {
    super.initState();
    final highest = ref.read(progressProvider).highestUnlocked;
    final initialOffset = LevelsScreen.computeChapterOffset(highest);
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_onScroll);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playReviewServiceProvider).scheduleReviewIfEligible(context);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final highest = ref.read(progressProvider).highestUnlocked;
    final target = LevelsScreen.computeChapterOffset(highest);
    final diff = (_scrollController.offset - target).abs();
    final shouldShow = diff > 400.0;
    if (shouldShow != _showCurrentPill && mounted) {
      setState(() {
        _showCurrentPill = shouldShow;
      });
    }
  }

  void _scrollToCurrent() {
    final highest = ref.read(progressProvider).highestUnlocked;
    final target = LevelsScreen.computeChapterOffset(highest);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 360),
        curve: Primitives.curveEnter,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onLockedTapped(int levelId) {
    ref.read(hapticsServiceProvider).medium();
    final highest = ref.read(progressProvider).highestUnlocked;
    setState(() {
      _lockedShakeLevelId = levelId;
      _lockedHintMessage = 'Finish level $highest first';
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _lockedShakeLevelId = null;
          _lockedHintMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = ref.watch(progressProvider);
    final levelRepo = ref.watch(levelRepositoryProvider);
    final haptics = ref.read(hapticsServiceProvider);

    // Calculate total stars
    var totalStars = 0;
    for (final s in progress.stars.values) {
      totalStars += s;
    }

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Levels', style: tokens.typography.title),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.ink),
          tooltip: 'Back',
          onPressed: () {
            haptics.selection();
            context.safeBack(fallbackRoute: Routes.home);
          },
        ),
        actions: [
          // Total stars chip
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(Primitives.radiusChip),
              border: Border.all(color: tokens.line, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 16.0, color: tokens.accent),
                const SizedBox(width: 4.0),
                Text(
                  '$totalStars',
                  style: TextStyle(
                    fontFamily: Primitives.fontDisplay,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Helper line when locked tile tapped
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _lockedHintMessage != null ? 36.0 : 0.0,
                  alignment: Alignment.center,
                  child: _lockedHintMessage != null
                      ? Text(
                          _lockedHintMessage!,
                          style: tokens.typography.body.copyWith(
                            color: tokens.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Chapters list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Primitives.space20,
                      vertical: Primitives.space8,
                    ),
                    itemCount: allChapters.length,
                    itemBuilder: (context, chapterIdx) {
                      final chapter = allChapters[chapterIdx];
                      final startLevel = chapterIdx * 20 + 1;
                      final endLevel = startLevel + 19;

                      var clearedInChapter = 0;
                      for (var lid = startLevel; lid <= endLevel; lid++) {
                        if (progress.stars.containsKey(lid)) {
                          clearedInChapter++;
                        }
                      }

                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: Primitives.space32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Chapter Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  chapter.name,
                                  style: tokens.typography.heading,
                                ),
                                Text(
                                  '$clearedInChapter of 20',
                                  style: tokens.typography.caption.copyWith(
                                    color: tokens.inkMuted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Primitives.space4),
                            Text(
                              chapter.description,
                              style: tokens.typography.body.copyWith(
                                color: tokens.inkMuted,
                                fontSize: 13.0,
                              ),
                            ),
                            const SizedBox(height: 8.0),

                            // Chapter progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2.0),
                              child: LinearProgressIndicator(
                                value: (clearedInChapter / 20.0).clamp(0.0, 1.0),
                                backgroundColor: tokens.surfaceRaised,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(tokens.accent),
                                minHeight: 3.0,
                              ),
                            ),
                            const SizedBox(height: 12.0),

                            // 48dp chapter art strip with mini motifs
                            Container(
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: tokens.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8.0),
                                border:
                                    Border.all(color: tokens.line, width: 1.0),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(8, (i) {
                                  return Opacity(
                                    opacity: 0.35,
                                    child: Icon(
                                      Icons.polyline_rounded,
                                      size: 16.0,
                                      color: tokens.accent,
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: Primitives.space16),

                            // 4-Column Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: Primitives.space12,
                                mainAxisSpacing: Primitives.space12,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: 20,
                              itemBuilder: (context, idx) {
                                final levelId = startLevel + idx;
                                final isLocked =
                                    levelId > progress.highestUnlocked;
                                final isCurrent =
                                    levelId == progress.highestUnlocked;
                                final stars = progress.stars[levelId] ?? 0;
                                final isCompleted = stars > 0;
                                final isShaking =
                                    _lockedShakeLevelId == levelId;

                                // Showpiece silhouette corner mark for special levels (e.g. multiple of 10 or 20)
                                final isShowpiece = levelId % 10 == 0;

                                // Synchronously resolve level miniature
                                final levelObj = levelRepo.getLevelSync(levelId);

                                return RepaintBoundary(
                                  child: AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      final pulseVal = isCurrent
                                          ? _pulseController.value
                                          : 0.0;
                                      return LevelTile(
                                        levelId: levelId,
                                        level: levelObj,
                                        isLocked: isLocked,
                                        isCurrent: isCurrent,
                                        isCompleted: isCompleted,
                                        isShowpiece: isShowpiece,
                                        pulseFactor: pulseVal,
                                        stars: stars,
                                        isShaking: isShaking,
                                        onTap: () {
                                          if (isLocked) {
                                            _onLockedTapped(levelId);
                                          } else {
                                            haptics.selection();
                                            context.push(Routes.play(levelId));
                                          }
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Floating "Current level" pill when user scrolls away
            if (_showCurrentPill)
              Positioned(
                bottom: 24.0,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      haptics.selection();
                      _scrollToCurrent();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceRaised,
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusChip),
                        border: Border.all(color: tokens.accent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.accent.withValues(alpha: 0.2),
                            blurRadius: 16.0,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location_rounded,
                              size: 16.0, color: tokens.accent),
                          const SizedBox(width: 8.0),
                          Text(
                            'Current Level ${progress.highestUnlocked}',
                            style: tokens.typography.label.copyWith(
                              color: tokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LevelTile extends StatelessWidget {
  const LevelTile({
    super.key,
    required this.levelId,
    this.level,
    required this.isLocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.isShowpiece,
    this.pulseFactor = 0.0,
    required this.stars,
    required this.isShaking,
    required this.onTap,
  });

  final int levelId;
  final Level? level;
  final bool isLocked;
  final bool isCurrent;
  final bool isCompleted;
  final bool isShowpiece;
  final double pulseFactor;
  final int stars;
  final bool isShaking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    BoxDecoration decoration;
    if (isCompleted) {
      decoration = BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: BorderRadius.circular(Primitives.radius16),
        border: Border.all(color: tokens.line, width: 1.0),
      );
    } else if (isCurrent) {
      final outlineOpacity = 0.6 + 0.4 * pulseFactor;
      decoration = BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(Primitives.radius16),
        border: Border.all(
          color: tokens.accent.withValues(alpha: outlineOpacity),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.accent.withValues(alpha: 0.25 * pulseFactor),
            blurRadius: 10.0,
            spreadRadius: 1.0,
          ),
        ],
      );
    } else if (isLocked) {
      decoration = BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Primitives.radius16),
        border: Border.all(
            color: tokens.line.withValues(alpha: 0.5), width: 1.0),
      );
    } else {
      decoration = BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(Primitives.radius16),
        border: Border.all(color: tokens.line, width: 1.0),
      );
    }

    Widget tile = Semantics(
      label: isLocked
          ? 'Level $levelId locked'
          : isCompleted
              ? 'Level $levelId completed, $stars stars'
              : 'Level $levelId',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Primitives.radius16),
        child: Container(
          decoration: decoration,
          child: Stack(
            children: [
              // Top-left: Level number in display numerals
              Positioned(
                top: 6.0,
                left: 8.0,
                child: Text(
                  '$levelId',
                  style: TextStyle(
                    fontFamily: Primitives.fontDisplay,
                    fontSize: 12.0,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isLocked
                        ? tokens.inkFaint
                        : isCurrent
                            ? tokens.accent
                            : tokens.inkMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // Top-right: Showpiece silhouette corner mark
              if (isShowpiece && !isLocked)
                Positioned(
                  top: 6.0,
                  right: 6.0,
                  child: Container(
                    width: 5.0,
                    height: 5.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.accent,
                    ),
                  ),
                ),

              // Center: Real level miniature or lock glyph
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: isLocked
                      ? Icon(
                          Icons.lock_rounded,
                          size: 18.0,
                          color: tokens.inkFaint.withValues(alpha: 0.6),
                        )
                      : LevelMiniatureWidget(
                          level: level,
                          isLocked: false,
                          size: 42.0,
                        ),
                ),
              ),

              // Bottom: Star ticks for completed levels
              if (isCompleted)
                Positioned(
                  bottom: 6.0,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var s = 1; s <= 3; s++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 4.0,
                          height: 4.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s <= stars ? tokens.accent : tokens.line,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (isShaking) {
      tile = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 140),
        builder: (context, val, child) {
          final offset = math.sin(val * math.pi * 4) * 6.0;
          return Transform.translate(
            offset: Offset(offset, 0.0),
            child: child,
          );
        },
        child: tile,
      );
    }

    return tile;
  }
}
