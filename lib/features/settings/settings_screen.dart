import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/router/nav_utils.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {}
  }

  void _showResetConfirmSheet() {
    final tokens = context.tokens;
    final haptics = ref.read(hapticsServiceProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
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
                  'Reset progress?',
                  style: tokens.typography.title,
                ),
              ),
              const SizedBox(height: Primitives.space12),
              Center(
                child: Text(
                  'This will clear all unlocked levels, earned stars and session statistics. This action cannot be undone.',
                  style:
                      tokens.typography.body.copyWith(color: tokens.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Primitives.space24),
              FilledButton(
                onPressed: () {
                  haptics.medium();
                  ref.read(progressProvider.notifier).resetProgress();
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Progress has been reset.')),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.danger,
                  foregroundColor: tokens.onAccent,
                  minimumSize: const Size.fromHeight(48.0),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(Primitives.radiusButton),
                  ),
                ),
                child: Text(
                  'Reset all progress',
                  style:
                      tokens.typography.label.copyWith(color: tokens.onAccent),
                ),
              ),
              const SizedBox(height: Primitives.space12),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.ink,
                  side: BorderSide(color: tokens.threadFaint),
                  minimumSize: const Size.fromHeight(48.0),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(Primitives.radiusButton),
                  ),
                ),
                child: Text('Cancel', style: tokens.typography.label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final haptics = ref.read(hapticsServiceProvider);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: Text('Settings', style: tokens.typography.title),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.ink),
          tooltip: 'Back',
          onPressed: () {
            haptics.selection();
            context.safeBack(fallbackRoute: Routes.home);
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Primitives.space20,
            vertical: Primitives.space16,
          ),
          children: [
            // Section: Appearance
            _SectionHeader(title: 'Appearance', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.line, width: 1.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Theme', style: tokens.typography.body),
                    subtitle: Text(
                      tokens.displayName,
                      style: tokens.typography.caption.copyWith(color: tokens.accent),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18.0,
                          height: 18.0,
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: tokens.line, width: 1.0),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
                      ],
                    ),
                    onTap: () {
                      haptics.selection();
                      context.push(Routes.theme);
                    },
                  ),
                  Divider(color: tokens.line, height: 1.0),
                  ListTile(
                    title: Text('Reset to Classic Sage', style: tokens.typography.body),
                    subtitle: Text(
                      'Revert to the original sage linen appearance',
                      style: tokens.typography.caption.copyWith(color: tokens.inkMuted),
                    ),
                    trailing: Icon(Icons.restore_rounded, color: tokens.inkMuted),
                    onTap: () {
                      haptics.selection();
                      ref.read(settingsProvider.notifier).resetToClassicSage();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Theme reset to Classic Sage',
                              style: tokens.typography.caption),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: Primitives.space24),

            // Section: Feedback
            _SectionHeader(title: 'Feedback', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.line, width: 1.0),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Sound', style: tokens.typography.body),
                    subtitle: Text('Wooden tactile audio effects',
                        style: tokens.typography.caption),
                    value: settings.sound,
                    activeTrackColor: tokens.accent,
                    onChanged: (val) {
                      haptics.selection();
                      settingsNotifier.setSound(val);
                    },
                  ),
                  Divider(
                      color: tokens.line,
                      height: 1.0,
                      indent: 16.0,
                      endIndent: 16.0),
                  SwitchListTile(
                    title: Text('Haptics', style: tokens.typography.body),
                    subtitle: Text('Subtle vibration pulses on actions',
                        style: tokens.typography.caption),
                    value: settings.haptics,
                    activeTrackColor: tokens.accent,
                    onChanged: (val) {
                      haptics.selection();
                      settingsNotifier.setHaptics(val);
                    },
                  ),
                  Divider(
                      color: tokens.line,
                      height: 1.0,
                      indent: 16.0,
                      endIndent: 16.0),
                  SwitchListTile(
                    title: Text('Reduce motion', style: tokens.typography.body),
                    subtitle: Text(
                        'Replaces sliding animations with gentle fades',
                        style: tokens.typography.caption),
                    value: settings.reduceMotion,
                    activeTrackColor: tokens.accent,
                    onChanged: (val) {
                      haptics.selection();
                      settingsNotifier.setReduceMotion(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: Primitives.space24),

            // Section: Game
            _SectionHeader(title: 'Game', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.line, width: 1.0),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Show chain counter', style: tokens.typography.body),
                    subtitle: Text('Displays flow combos during consecutive pulls',
                        style: tokens.typography.caption),
                    value: settings.showChainCounter,
                    activeTrackColor: tokens.accent,
                    onChanged: (val) {
                      haptics.selection();
                      settingsNotifier.setShowChainCounter(val);
                    },
                  ),
                  Divider(
                      color: tokens.line,
                      height: 1.0,
                      indent: 16.0,
                      endIndent: 16.0),
                  SwitchListTile(
                    title: Text('Idle hint nudge', style: tokens.typography.body),
                    subtitle: Text('Gently pulses hint button after 30s of inactivity',
                        style: tokens.typography.caption),
                    value: settings.idleHintNudge,
                    activeTrackColor: tokens.accent,
                    onChanged: (val) {
                      haptics.selection();
                      settingsNotifier.setIdleHintNudge(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: Primitives.space24),

            // Section: Help
            _SectionHeader(title: 'Help', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.line, width: 1.0),
              ),
              child: ListTile(
                title: Text('How to play', style: tokens.typography.body),
                subtitle: Text('Rules and visual guides',
                    style: tokens.typography.caption),
                trailing:
                    Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
                onTap: () {
                  haptics.selection();
                  context.push(Routes.howToPlay);
                },
              ),
            ),

            const SizedBox(height: Primitives.space24),

            // Section: About
            _SectionHeader(title: 'About', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.line, width: 1.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Version', style: tokens.typography.body),
                    subtitle: Text(_version, style: tokens.typography.caption),
                  ),
                  Divider(
                      color: tokens.line,
                      height: 1.0,
                      indent: 16.0,
                      endIndent: 16.0),
                  ListTile(
                    title: Text('Licences', style: tokens.typography.body),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: tokens.inkMuted),
                    onTap: () {
                      haptics.selection();
                      showLicensePage(
                        context: context,
                        applicationName: 'ArrowZ',
                        applicationVersion: _version,
                      );
                    },
                  ),
                  Divider(
                      color: tokens.line,
                      height: 1.0,
                      indent: 16.0,
                      endIndent: 16.0),
                  Padding(
                    padding: const EdgeInsets.all(Primitives.space16),
                    child: Text(
                      'Nothing is collected. ArrowZ works fully offline.',
                      style: tokens.typography.caption
                          .copyWith(color: tokens.inkMuted),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Primitives.space24),

            // Section: Danger Zone
            _SectionHeader(title: 'Danger', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(
                    color: tokens.danger.withValues(alpha: 0.3), width: 1.0),
              ),
              child: ListTile(
                title: Text('Reset progress',
                    style:
                        tokens.typography.body.copyWith(color: tokens.danger)),
                subtitle: Text('Clears all stars and unlocks',
                    style: tokens.typography.caption),
                trailing:
                    Icon(Icons.delete_outline_rounded, color: tokens.danger),
                onTap: () {
                  haptics.medium();
                  _showResetConfirmSheet();
                },
              ),
            ),
            const SizedBox(height: Primitives.space32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.tokens});
  final String title;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: Primitives.space4,
        bottom: Primitives.space8,
      ),
      child: Text(
        title,
        style: tokens.typography.label.copyWith(
          color: tokens.inkMuted,
          fontSize: 12.0,
        ),
      ),
    );
  }
}
