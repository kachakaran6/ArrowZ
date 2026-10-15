import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/features/levels/chapter_art_strip.dart';
import 'package:flutter/material.dart';

class ChapterCompleteView extends StatefulWidget {
  const ChapterCompleteView({
    super.key,
    required this.chapterNumber,
    required this.chapterName,
    required this.nextChapterName,
    required this.totalStars,
    required this.onContinue,
  });

  final int chapterNumber;
  final String chapterName;
  final String nextChapterName;
  final int totalStars;
  final VoidCallback onContinue;

  @override
  State<ChapterCompleteView> createState() => _ChapterCompleteViewState();
}

class _ChapterCompleteViewState extends State<ChapterCompleteView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Primitives.curveEnter),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      // Chapter Art Strip
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radius16),
                        child: Container(
                          height: 56.0,
                          color: tokens.surfaceRaised,
                          child: ChapterArtStrip(
                            chapterId: widget.chapterNumber,
                            accentColor: tokens.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      Text(
                        'Chapter ${widget.chapterNumber} Clear',
                        style: tokens.typography.caption.copyWith(
                          color: tokens.accent,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        widget.chapterName,
                        style: tokens.typography.display.copyWith(
                          fontSize: 34.0,
                          color: tokens.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'All 20 levels cleared with distinction.',
                        style: tokens.typography.body.copyWith(color: tokens.inkMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32.0),
                      // Stats Card
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(AppTokens.radius24),
                          border: Border.all(color: tokens.line),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '20 / 20',
                                  style: tokens.typography.heading.copyWith(
                                    color: tokens.ink,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Levels',
                                  style: tokens.typography.caption.copyWith(
                                    color: tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 32, color: tokens.line),
                            Column(
                              children: [
                                Text(
                                  '${widget.totalStars}',
                                  style: tokens.typography.heading.copyWith(
                                    color: tokens.accent,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Stars',
                                  style: tokens.typography.caption.copyWith(
                                    color: tokens.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      if (widget.nextChapterName.isNotEmpty) ...[
                        Text(
                          'Next: ${widget.nextChapterName}',
                          style: tokens.typography.body.copyWith(
                            color: tokens.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const Spacer(),
                      FilledButton(
                        onPressed: widget.onContinue,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.accent,
                          foregroundColor: tokens.onAccent,
                          minimumSize: const Size.fromHeight(60.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radius16),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: tokens.typography.label.copyWith(
                            color: tokens.onAccent,
                            fontSize: 16.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
