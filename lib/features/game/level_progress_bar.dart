import 'dart:ui' show lerpDouble;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:flutter/material.dart';

/// A slim, minimal, pastel-colored level progress bar.
///
/// Displays a smooth animated fill representing player progress through the
/// current level without any visible numbers, percentages, or textual indicators.
class LevelProgressBar extends StatefulWidget {
  const LevelProgressBar({
    super.key,
    required this.progress,
    this.reduceMotion = false,
    this.height = 4.0,
    this.radius = 2.0,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeInOut,
    this.trackColor,
    this.fillColor,
  });

  /// Authoritative normalized level progress in the range [0.0, 1.0].
  final double progress;

  /// Whether reduced-motion mode is active.
  final bool reduceMotion;

  /// Height of the progress bar track. Defaults to 4.0.
  final double height;

  /// Corner radius for track and fill. Defaults to 2.0 (pill-shaped).
  final double radius;

  /// Transition duration for progress updates. Defaults to 220ms.
  final Duration duration;

  /// Easing curve for progress animation. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Optional track color override. Defaults to [AppTokens.progressTrack].
  final Color? trackColor;

  /// Optional fill color override. Defaults to [AppTokens.progressFill].
  final Color? fillColor;

  @override
  State<LevelProgressBar> createState() => _LevelProgressBarState();
}

class _LevelProgressBarState extends State<LevelProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curvedAnimation;
  late double _startProgress;
  late double _targetProgress;

  @override
  void initState() {
    super.initState();
    _targetProgress =
        (widget.progress.isNaN ? 0.0 : widget.progress).clamp(0.0, 1.0);
    _startProgress = _targetProgress;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
  }

  double get _currentProgress {
    if (widget.reduceMotion || widget.duration == Duration.zero) {
      return _targetProgress;
    }
    return lerpDouble(
          _startProgress,
          _targetProgress,
          _curvedAnimation.value,
        ) ??
        _targetProgress;
  }

  @override
  void didUpdateWidget(LevelProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTarget =
        (widget.progress.isNaN ? 0.0 : widget.progress).clamp(0.0, 1.0);

    if (newTarget != _targetProgress) {
      _startProgress = _currentProgress;
      _targetProgress = newTarget;

      if (widget.reduceMotion || widget.duration == Duration.zero) {
        _controller.value = 1.0;
        _startProgress = _targetProgress;
        setState(() {});
      } else {
        _controller.duration = widget.duration;
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final track = widget.trackColor ?? tokens.progressTrack;
    final fill = widget.fillColor ?? tokens.progressFill;
    final clamped =
        (widget.progress.isNaN ? 0.0 : widget.progress).clamp(0.0, 1.0);
    final percent = (clamped * 100).round();

    // Semantic progress node for assistive technology without visible text/percentage.
    // The value updates only with authoritative game-state changes, not on each animation frame.
    return Semantics(
      label: 'Level progress',
      value: '$percent% complete',
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _curvedAnimation,
          builder: (context, _) {
            return CustomPaint(
              size: Size.fromHeight(widget.height),
              painter: _ProgressBarPainter(
                progress: _currentProgress,
                trackColor: track,
                fillColor: fill,
                radius: widget.radius,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  const _ProgressBarPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.radius,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || progress.isNaN) return;

    final r = Radius.circular(radius);
    final trackRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      r,
    );

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, trackPaint);

    // Fill
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0) {
      final fillWidth = size.width * clampedProgress;
      final fillPaint = Paint()
        ..color = fillColor
        ..isAntiAlias = true
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillWidth, size.height),
          r,
        ),
        fillPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.radius != radius;
  }
}
