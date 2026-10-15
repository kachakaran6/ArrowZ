import 'dart:math' as math;

import 'package:arrowtapout/data/achievements_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/router/nav_utils.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final achievements = ref.watch(achievementsProvider);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.ink),
          onPressed: () => context.safeBack(fallbackRoute: Routes.home),
        ),
        title: Text('Achievements', style: tokens.typography.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppTokens.radius10),
                  border: Border.all(color: tokens.line),
                ),
                child: Text(
                  '$unlockedCount of ${achievements.length}',
                  style: tokens.typography.caption.copyWith(
                    color: tokens.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          itemCount: achievements.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12.0),
          itemBuilder: (context, index) {
            final item = achievements[index];
            return _AchievementCard(item: item, tokens: tokens);
          },
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.item,
    required this.tokens,
  });

  final AchievementItem item;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        _showDetailSheet(context);
      },
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(
            color: item.isUnlocked
                ? tokens.accent.withValues(alpha: 0.35)
                : tokens.line,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // Drawn Badge
            Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isUnlocked
                    ? tokens.accent.withValues(alpha: 0.15)
                    : tokens.surfaceRaised,
                border: Border.all(
                  color: item.isUnlocked ? tokens.accent : tokens.line,
                  width: item.isUnlocked ? 1.5 : 1.0,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(24.0, 24.0),
                  painter: _BadgePainter(
                    iconCode: item.iconCode,
                    color: item.isUnlocked ? tokens.accent : tokens.inkMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16.0),
            // Text and progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.title,
                        style: tokens.typography.label.copyWith(
                          color: item.isUnlocked ? tokens.ink : tokens.inkMuted,
                          fontSize: 16.0,
                        ),
                      ),
                      if (item.isUnlocked)
                        Icon(Icons.check_circle_rounded,
                            size: 18.0, color: tokens.accent)
                      else
                        Text(
                          '${item.current}/${item.target}',
                          style: tokens.typography.caption.copyWith(
                            color: tokens.inkMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    item.description,
                    style: tokens.typography.caption.copyWith(
                      color: tokens.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  // Thin progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.0),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 3.5,
                      backgroundColor: tokens.surfaceRaised,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.isUnlocked ? tokens.accent : tokens.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Primitives.radiusSheet),
          ),
          border: Border(top: BorderSide(color: tokens.line)),
        ),
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 24.0,
          bottom: MediaQuery.paddingOf(context).bottom + 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64.0,
                height: 64.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isUnlocked
                      ? tokens.accent.withValues(alpha: 0.15)
                      : tokens.surfaceRaised,
                  border: Border.all(
                    color: item.isUnlocked ? tokens.accent : tokens.line,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(32.0, 32.0),
                    painter: _BadgePainter(
                      iconCode: item.iconCode,
                      color: item.isUnlocked ? tokens.accent : tokens.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Center(
              child: Text(
                item.title,
                style: tokens.typography.title.copyWith(color: tokens.ink),
              ),
            ),
            const SizedBox(height: 8.0),
            Center(
              child: Text(
                item.description,
                style: tokens.typography.body.copyWith(color: tokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20.0),
            Center(
              child: Text(
                item.isUnlocked
                    ? 'Completed'
                    : 'Progress: ${item.current} / ${item.target}',
                style: tokens.typography.label.copyWith(
                  color: item.isUnlocked ? tokens.accent : tokens.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.surfaceRaised,
                foregroundColor: tokens.ink,
                minimumSize: const Size.fromHeight(48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radius16),
                  side: BorderSide(color: tokens.line),
                ),
              ),
              child: Text('Close', style: tokens.typography.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter({
    required this.iconCode,
    required this.color,
  });

  final int iconCode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final path = Path();

    switch (iconCode) {
      case 0: // Thread / Arrow
        path.moveTo(w * 0.2, h * 0.5);
        path.lineTo(w * 0.8, h * 0.5);
        path.moveTo(w * 0.55, h * 0.25);
        path.lineTo(w * 0.8, h * 0.5);
        path.lineTo(w * 0.55, h * 0.75);
        break;
      case 1: // Trophy / Crown
        path.moveTo(w * 0.2, h * 0.35);
        path.lineTo(w * 0.35, h * 0.7);
        path.lineTo(w * 0.65, h * 0.7);
        path.lineTo(w * 0.8, h * 0.35);
        path.lineTo(w * 0.5, h * 0.55);
        path.close();
        path.moveTo(w * 0.5, h * 0.7);
        path.lineTo(w * 0.5, h * 0.85);
        path.moveTo(w * 0.35, h * 0.85);
        path.lineTo(w * 0.65, h * 0.85);
        break;
      case 2: // Lightning / Flow
        path.moveTo(w * 0.55, h * 0.15);
        path.lineTo(w * 0.3, h * 0.55);
        path.lineTo(w * 0.5, h * 0.55);
        path.lineTo(w * 0.45, h * 0.85);
        path.lineTo(w * 0.7, h * 0.45);
        path.lineTo(w * 0.5, h * 0.45);
        path.close();
        break;
      case 3: // Star
        for (var i = 0; i < 5; i++) {
          final angle = -math.pi / 2 + i * (2 * math.pi / 5);
          final innerAngle = angle + math.pi / 5;
          final ox = w * 0.5 + math.cos(angle) * (w * 0.45);
          final oy = h * 0.5 + math.sin(angle) * (h * 0.45);
          final ix = w * 0.5 + math.cos(innerAngle) * (w * 0.22);
          final iy = h * 0.5 + math.sin(innerAngle) * (h * 0.22);
          if (i == 0) {
            path.moveTo(ox, oy);
          } else {
            path.lineTo(ox, oy);
          }
          path.lineTo(ix, iy);
        }
        path.close();
        break;
      case 4: // Flame
      default:
        path.moveTo(w * 0.5, h * 0.15);
        path.cubicTo(w * 0.65, h * 0.35, w * 0.85, h * 0.55, w * 0.8, h * 0.75);
        path.cubicTo(w * 0.75, h * 0.9, w * 0.55, h * 0.95, w * 0.5, h * 0.95);
        path.cubicTo(w * 0.45, h * 0.95, w * 0.25, h * 0.9, w * 0.2, h * 0.75);
        path.cubicTo(w * 0.15, h * 0.55, w * 0.35, h * 0.35, w * 0.5, h * 0.15);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BadgePainter oldDelegate) =>
      oldDelegate.iconCode != iconCode || oldDelegate.color != color;
}
