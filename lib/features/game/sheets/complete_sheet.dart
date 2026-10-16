import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:flutter/material.dart';

class CompleteSheet extends StatefulWidget {
  const CompleteSheet({
    super.key,
    required this.levelId,
    this.chapterName = '',
    this.isChapterFinale = false,
    required this.stars,
    required this.threadsCleared,
    required this.mistakes,
    required this.onNextLevel,
    required this.onReplay,
    this.onLevels,
    this.elapsedSeconds,
  });

  final int levelId;
  final String chapterName;
  final bool isChapterFinale;
  final int stars; // 1, 2, or 3
  final int threadsCleared;
  final int mistakes;
  final VoidCallback onNextLevel;
  final VoidCallback onReplay;
  final VoidCallback? onLevels;
  final int? elapsedSeconds;

  @override
  State<CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<CompleteSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    // Arrow terminology instead of Thread, keeping Mistake
    final arrowCount = widget.threadsCleared;
    final mistakeCount = widget.mistakes;

    final String arrowPart = '$arrowCount ${arrowCount == 1 ? 'Arrow' : 'Arrows'}';
    final String mistakePart = mistakeCount == 0
        ? '0 Mistakes'
        : '$mistakeCount ${mistakeCount == 1 ? 'Mistake' : 'Mistakes'}';

    String statsText = '$arrowPart · $mistakePart';

    if (widget.elapsedSeconds != null && widget.elapsedSeconds! > 0) {
      final m = widget.elapsedSeconds! ~/ 60;
      final s = widget.elapsedSeconds! % 60;
      final formattedTime =
          '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      statsText = '$statsText · ⏱️ $formattedTime';
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: tokens.surface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
          side: BorderSide(color: tokens.threadFaint, width: 1.0),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title: "Complete"
              Center(
                child: Text(
                  'Complete',
                  style: tokens.typography.title.copyWith(
                    fontSize: 26.0,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20.0),

              // Three Solid-Colored Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 3; i++) ...[
                    if (i > 1) const SizedBox(width: 14.0),
                    Icon(
                      Icons.star_rounded,
                      size: 46.0,
                      color: widget.stars >= i
                          ? const Color(0xFFFFB800)
                          : tokens.threadFaint.withValues(alpha: 0.6),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18.0),

              // Stats details
              Center(
                child: Text(
                  statsText,
                  style: tokens.typography.body.copyWith(
                    color: tokens.inkMuted,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28.0),

              // Exactly two buttons: Replay and Next Level
              Row(
                children: [
                  // Replay button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onReplay();
                      },
                      icon: const Icon(Icons.replay_rounded, size: 20.0),
                      label: Text(
                        'Replay',
                        style: tokens.typography.label.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.ink,
                        side: BorderSide(color: tokens.threadFaint, width: 1.5),
                        minimumSize: const Size.fromHeight(50.0),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(Primitives.radiusButton),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  // Next Level button
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onNextLevel();
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20.0),
                      label: Text(
                        'Next Level',
                        style: tokens.typography.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.onAccent,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: tokens.onAccent,
                        minimumSize: const Size.fromHeight(50.0),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(Primitives.radiusButton),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
