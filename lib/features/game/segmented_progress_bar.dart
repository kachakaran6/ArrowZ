import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:flutter/material.dart';

/// Segmented progress bar with numeral roll counter and chain flow indicator.
class SegmentedProgressBar extends StatelessWidget {
  const SegmentedProgressBar({
    super.key,
    required this.totalThreads,
    required this.clearedThreads,
    required this.chainCount,
    this.onHowToPlay,
  });

  final int totalThreads;
  final int clearedThreads;
  final int chainCount;
  final VoidCallback? onHowToPlay;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final remaining = (totalThreads - clearedThreads).clamp(0, totalThreads);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top row: Numeral roll counter left, Chain chip & How-to-play right
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Remaining counter with numeral roll animation
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, -0.4),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Text(
                      '$remaining',
                      key: ValueKey<int>(remaining),
                      style: TextStyle(
                        fontFamily: Primitives.fontDisplay,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    'left',
                    style: tokens.typography.caption.copyWith(
                      color: tokens.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Right side: Chain flow chip + quiet How to Play button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (chainCount >= 3) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(Primitives.radiusChip),
                        border: Border.all(color: tokens.accent, width: 1.0),
                      ),
                      child: Text(
                        'Chain x$chainCount',
                        style: TextStyle(
                          fontFamily: Primitives.fontDisplay,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          color: tokens.accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                  ],

                  if (onHowToPlay != null)
                    IconButton(
                      icon: Icon(
                        Icons.help_outline_rounded,
                        size: 20.0,
                        color: tokens.inkMuted,
                      ),
                      tooltip: 'How to play',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36.0,
                        minHeight: 36.0,
                      ),
                      onPressed: onHowToPlay,
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8.0),

        // Segmented bar: one segment per thread
        if (totalThreads > 0)
          Row(
            children: List.generate(totalThreads, (index) {
              final isFilled = index < clearedThreads;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < totalThreads - 1 ? 3.0 : 0.0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 5.0,
                    decoration: BoxDecoration(
                      color: isFilled ? tokens.accent : tokens.surfaceRaised,
                      borderRadius: BorderRadius.circular(2.5),
                      border: isFilled
                          ? null
                          : Border.all(color: tokens.line, width: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
