import 'dart:math' as math;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-width 64 dp primary action button with tactile press feedback and slow breathing glow.
class PrimaryPlayButton extends ConsumerStatefulWidget {
  const PrimaryPlayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.reduceMotion = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool reduceMotion;

  @override
  ConsumerState<PrimaryPlayButton> createState() => _PrimaryPlayButtonState();
}

class _PrimaryPlayButtonState extends ConsumerState<PrimaryPlayButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    if (!widget.reduceMotion) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PrimaryPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      if (widget.reduceMotion) {
        _glowController.stop();
      } else {
        _glowController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    ref.read(hapticsServiceProvider).selection();
    ref.read(soundServiceProvider).play(SoundEvent.ui);
    widget.onPressed();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AnimatedBuilder(
      animation: Listenable.merge([_pressController, _glowController]),
      builder: (context, child) {
        final glowOpacity = widget.reduceMotion
            ? 0.20
            : (0.18 + (math.sin(_glowController.value * math.pi) * 0.12));

        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 64.0,
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: BorderRadius.circular(AppTokens.radius16),
                boxShadow: [
                  if (tokens.isDark)
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: glowOpacity),
                      blurRadius: 24.0,
                      spreadRadius: 1.0,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                style: tokens.typography.label.copyWith(
                  color: tokens.onAccent,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
