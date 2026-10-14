import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/component_tokens.dart';
import 'package:flutter/material.dart';

/// Heart-based life indicator widget displaying player's remaining lives in ArrowZ.
///
/// Exactly three heart icons are displayed:
/// - Active life: Red heart.
/// - Lost life: White heart (with subtle border for visibility against light backgrounds).
class HeartLifeIndicator extends StatelessWidget {
  const HeartLifeIndicator({
    super.key,
    required this.remainingLives,
    this.maxLives = 3,
    this.heartSize = ComponentTokens.heartSize,
    this.spacing = ComponentTokens.heartGap,
    this.activeColor = const Color(0xFFE53935),
    this.lostColor = Colors.white,
    this.reduceMotion = false,
  });

  /// Authoritative number of lives remaining (clamped to 0..maxLives).
  final int remainingLives;

  /// Maximum lives allowed for a level (default: 3).
  final int maxLives;

  /// Size of each heart icon in logical pixels.
  final double heartSize;

  /// Spacing between heart icons.
  final double spacing;

  /// Color for active remaining lives.
  final Color activeColor;

  /// Color for lost lives.
  final Color lostColor;

  /// Whether reduce-motion accessibility mode is active.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final clampedLives = remainingLives.clamp(0, maxLives);

    return Semantics(
      label: 'Lives remaining: $clampedLives of $maxLives',
      value: '$clampedLives',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < maxLives; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            _buildHeart(
              index: i,
              isActive: i < clampedLives,
              tokens: tokens,
              context: context,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeart({
    required int index,
    required bool isActive,
    required AppTokens tokens,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? tokens.inkMuted.withValues(alpha: 0.6)
        : tokens.ink.withValues(alpha: 0.35);

    final heartWidget = isActive
        ? Icon(
            Icons.favorite_rounded,
            key: ValueKey('active_heart_$index'),
            size: heartSize,
            color: activeColor,
          )
        : Stack(
            alignment: Alignment.center,
            key: ValueKey('lost_heart_$index'),
            children: [
              // Solid white heart fill representing lost life
              Icon(
                Icons.favorite_rounded,
                size: heartSize,
                color: lostColor,
              ),
              // Subtle border outline ensuring contrast against light theme backgrounds
              Icon(
                Icons.favorite_border_rounded,
                size: heartSize,
                color: borderColor,
              ),
            ],
          );

    return Semantics(
      label: isActive ? 'Active life' : 'Lost life',
      excludeSemantics: true,
      child: reduceMotion
          ? heartWidget
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale:
                      Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: heartWidget,
            ),
    );
  }
}
