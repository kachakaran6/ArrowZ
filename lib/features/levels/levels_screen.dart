import 'dart:math' as math;

import 'package:arrowtapout/data/chapter_data.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/play_review_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

export 'package:arrowtapout/data/chapter_data.dart';

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
