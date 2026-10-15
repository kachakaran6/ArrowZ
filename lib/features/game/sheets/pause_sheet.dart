import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PauseSheet extends ConsumerWidget {
  const PauseSheet({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onLevels,
    this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onLevels;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final haptics = ref.read(hapticsServiceProvider);

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
                'Paused',
                style: tokens.typography.title,
              ),
            ),
            const SizedBox(height: Primitives.space24),
            // Resume
            FilledButton(
              onPressed: () {
                haptics.selection();
                Navigator.of(context).pop();
                onResume();
              },
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: tokens.onAccent,
                minimumSize: const Size.fromHeight(48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Primitives.radiusButton),
                ),
              ),
              child: Text(
                'Resume',
                style: tokens.typography.label.copyWith(color: tokens.onAccent),
              ),
            ),
            const SizedBox(height: Primitives.space12),
            // Restart
            OutlinedButton(
              onPressed: () {
                haptics.selection();
                Navigator.of(context).pop();
                onRestart();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.ink,
                side: BorderSide(color: tokens.threadFaint, width: 1.5),
                minimumSize: const Size.fromHeight(48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Primitives.radiusButton),
                ),
              ),
              child: Text('Restart', style: tokens.typography.label),
            ),
            const SizedBox(height: Primitives.space12),
            // Levels
            OutlinedButton(
              onPressed: () {
                haptics.selection();
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
            if (onQuit != null) ...[
              const SizedBox(height: Primitives.space12),
              // Quit to Home
              OutlinedButton(
                onPressed: () {
                  haptics.selection();
                  Navigator.of(context).pop();
                  onQuit!();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.inkMuted,
                  side: BorderSide(color: tokens.threadFaint, width: 1.0),
                  minimumSize: const Size.fromHeight(48.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Primitives.radiusButton),
                  ),
                ),
                child: Text('Quit to Home', style: tokens.typography.label),
              ),
            ],
            const SizedBox(height: Primitives.space20),
            Divider(color: tokens.threadFaint, height: 1.0),
            const SizedBox(height: Primitives.space12),
            // Sound & Haptics switches
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sound', style: tokens.typography.body),
                Switch(
                  value: settings.sound,
                  activeThumbColor: tokens.accent,
                  onChanged: (val) {
                    haptics.selection();
                    settingsNotifier.setSound(val);
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Haptics', style: tokens.typography.body),
                Switch(
                  value: settings.haptics,
                  activeThumbColor: tokens.accent,
                  onChanged: (val) {
                    haptics.selection();
                    settingsNotifier.setHaptics(val);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
