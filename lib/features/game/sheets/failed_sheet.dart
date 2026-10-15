import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:flutter/material.dart';

class FailedSheet extends StatelessWidget {
  const FailedSheet({
    super.key,
    required this.onRetry,
    required this.onLevels,
  });

  final VoidCallback onRetry;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Primitives.radiusSheet),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Primitives.space24,
        vertical: Primitives.space24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Out of lives',
                style: tokens.typography.title,
              ),
            ),
            const SizedBox(height: Primitives.space12),
            Center(
              child: Text(
                'Take your time and plan the exit order.',
                style: tokens.typography.body.copyWith(color: tokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Primitives.space24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
                minimumSize: const Size.fromHeight(48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Primitives.radiusButton),
                ),
              ),
              child: Text('Retry',
                  style:
                      tokens.typography.label.copyWith(color: tokens.onAccent)),
            ),
            const SizedBox(height: Primitives.space12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onLevels();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.ink,
                side: BorderSide(color: tokens.threadFaint, width: 1.5),
                minimumSize: const Size.fromHeight(48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Primitives.radiusButton),
                ),
              ),
              child: Text('Levels', style: tokens.typography.label),
            ),
          ],
        ),
      ),
    );
  }
}
