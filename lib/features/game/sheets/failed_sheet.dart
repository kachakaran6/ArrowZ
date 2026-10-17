import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:flutter/material.dart';

class FailedSheet extends StatefulWidget {
  const FailedSheet({
    super.key,
    required this.onRetry,
    required this.onLevels,
  });

  final VoidCallback onRetry;
  final VoidCallback onLevels;

  @override
  State<FailedSheet> createState() => _FailedSheetState();
}

class _FailedSheetState extends State<FailedSheet> {
  bool _actionTriggered = false;

  void _handleRetry() {
    if (_actionTriggered) return;
    _actionTriggered = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onRetry();
  }

  void _handleLevels() {
    if (_actionTriggered) return;
    _actionTriggered = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onLevels();
  }

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
                'Out of mistakes',
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
              onPressed: _handleRetry,
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
              onPressed: _handleLevels,
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
