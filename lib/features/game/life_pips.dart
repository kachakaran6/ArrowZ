import 'package:arrowtapout/design/app_tokens.dart';
import 'package:flutter/material.dart';

/// Three painted tactile capsule pips (14 x 6 dp) representing player lives.
///
/// Fully replaces generic red hearts with theme accent capsules.
/// Lost pips drop with a 160 ms fall and fade into empty hairline outlines.
class LifePips extends StatelessWidget {
  const LifePips({
    super.key,
    required this.remainingLives,
    this.maxLives = 3,
    this.pipWidth = 14.0,
    this.pipHeight = 6.0,
    this.spacing = 6.0,
    this.reduceMotion = false,
  });

  final int remainingLives;
  final int maxLives;
  final double pipWidth;
  final double pipHeight;
  final double spacing;
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
            _Pip(
              index: i,
              isActive: i < clampedLives,
              width: pipWidth,
              height: pipHeight,
              tokens: tokens,
            ),
          ],
        ],
      ),
    );
  }
}

class _Pip extends StatefulWidget {
  const _Pip({
    required this.index,
    required this.isActive,
    required this.width,
    required this.height,
    required this.tokens,
  });

  final int index;
  final bool isActive;
  final double width;
  final double height;
  final AppTokens tokens;

  @override
  State<_Pip> createState() => _PipState();
}

class _PipState extends State<_Pip> with SingleTickerProviderStateMixin {
  late final AnimationController _dropController;
  late final Animation<double> _fallAnimation;
  late final Animation<double> _fadeAnimation;
  bool _wasActive = true;

  @override
  void initState() {
    super.initState();
    _wasActive = widget.isActive;
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _fallAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _dropController, curve: Curves.easeIn),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dropController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant _Pip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      // Just lost this life: trigger 160 ms fall and fade
      _wasActive = true;
      _dropController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _wasActive = false;
          });
        }
      });
    } else if (!oldWidget.isActive && widget.isActive) {
      // Restored life (e.g. restart)
      _wasActive = true;
      _dropController.reset();
    }
  }

  @override
  void dispose() {
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final radius = Radius.circular(widget.height / 2);

    return SizedBox(
      width: widget.width,
      height: widget.height + 8.0, // extra height for falling drop animation
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Underlying outline representing lost life
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(radius),
              border: Border.all(
                color: tokens.isDark
                    ? tokens.line.withValues(alpha: 0.8)
                    : tokens.ink.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
          ),

          // Active solid pip, or dropping animated pip
          if (widget.isActive)
            Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: BorderRadius.all(radius),
                boxShadow: [
                  BoxShadow(
                    color: tokens.accentGlow,
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            )
          else if (_dropController.isAnimating || _wasActive)
            AnimatedBuilder(
              animation: _dropController,
              builder: (context, _) {
                return Positioned(
                  top: _fallAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      width: widget.width,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.all(radius),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
