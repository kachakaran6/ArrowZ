import 'dart:math' as math;

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/play_review_service.dart';
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
      description: 'Deflector-heavy chambers with bouncing trajectory cascades.'),
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
      description: 'Colossal 30x30 fields with 100+ intertwined arrows.'),
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

  @override
  ConsumerState<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends ConsumerState<LevelsScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _lockedShakeLevelId;
  String? _lockedHintMessage;

  @override
  void initState() {
    super.initState();
    // In-app review trigger check with 600ms delay after landing on level select
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playReviewServiceProvider).scheduleReviewIfEligible(context);
      _autoScrollToCurrent();
    });
  }

  void _autoScrollToCurrent() {
    final highest = ref.read(progressProvider).highestUnlocked;
    final chapterIdx = ((highest - 1) ~/ 20).clamp(0, 24);
    // Rough estimate: each chapter takes ~320dp height
    final targetOffset = chapterIdx * 320.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Primitives.curveEnter,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
    final haptics = ref.read(hapticsServiceProvider);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: Text('Levels', style: tokens.typography.title),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.ink),
          tooltip: 'Back',
          onPressed: () {
            haptics.selection();
            context.go(Routes.home);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Hint line when a locked tile is tapped
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

            // Scrollable list of 10 chapters
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
                    padding: const EdgeInsets.only(bottom: Primitives.space32),
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
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Primitives.space4),
                        Text(
                          chapter.description,
                          style: tokens.typography.caption,
                        ),
                        const SizedBox(height: Primitives.space16),

                        // 5-column tile grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: Primitives.space8,
                            mainAxisSpacing: Primitives.space8,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: 20,
                          itemBuilder: (context, idx) {
                            final levelId = startLevel + idx;
                            final isLocked = levelId > progress.highestUnlocked;
                            final isCurrent =
                                levelId == progress.highestUnlocked;
                            final stars = progress.stars[levelId] ?? 0;
                            final isCompleted = stars > 0;
                            final isShaking = _lockedShakeLevelId == levelId;

                            return LevelTile(
                              levelId: levelId,
                              isLocked: isLocked,
                              isCurrent: isCurrent,
                              isCompleted: isCompleted,
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
                      ],
                    ),
                  );
                },
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
    required this.isLocked,
    required this.isCurrent,
    required this.isCompleted,
    required this.stars,
    required this.isShaking,
    required this.onTap,
  });

  final int levelId;
  final bool isLocked;
  final bool isCurrent;
  final bool isCompleted;
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
        borderRadius: BorderRadius.circular(Primitives.radiusButton),
        border: Border.all(color: tokens.threadFaint, width: 1.0),
      );
    } else if (isCurrent) {
      decoration = BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(Primitives.radiusButton),
        border: Border.all(color: tokens.accent, width: 2.0),
      );
    } else if (isLocked) {
      decoration = BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Primitives.radiusButton),
        border: Border.all(
            color: tokens.threadFaint.withValues(alpha: 0.4), width: 1.0),
      );
    } else {
      // Unlocked
      decoration = BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(Primitives.radiusButton),
        border: Border.all(color: tokens.threadFaint, width: 1.0),
      );
    }

    Widget content;
    if (isLocked) {
      content =
          Icon(Icons.lock_outline_rounded, size: 16.0, color: tokens.inkFaint);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$levelId',
            style: TextStyle(
              fontFamily: Primitives.fontDisplay,
              fontSize: 18.0,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? tokens.accent : tokens.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (isCompleted) ...[
            const SizedBox(height: 2.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var s = 1; s <= 3; s++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.0),
                    width: 4.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s <= stars ? tokens.accent : tokens.threadFaint,
                    ),
                  ),
              ],
            ),
          ],
        ],
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
        borderRadius: BorderRadius.circular(Primitives.radiusButton),
        child: Container(
          decoration: decoration,
          alignment: Alignment.center,
          child: content,
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
