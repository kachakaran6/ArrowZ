import 'package:arrowtapout/core/qa_config.dart';
import 'package:arrowtapout/data/arrow_skin.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/platform/share_service.dart';
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

  void _showArrowSkinSheet() {
    final tokens = context.tokens;
    final haptics = ref.read(hapticsServiceProvider);
    final currentSkin = ref.read(settingsProvider).arrowSkin;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Primitives.radiusSheet),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Primitives.space20,
          vertical: Primitives.space20,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: tokens.threadFaint,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: Primitives.space16),
              Center(
                child: Text(
                  'Choose Arrow Skin',
                  style: tokens.typography.title,
                ),
              ),
              const SizedBox(height: Primitives.space4),
              Center(
                child: Text(
                  'Customise arrowheads and emojis across all levels',
                  style: tokens.typography.caption
                      .copyWith(color: tokens.inkMuted),
                ),
              ),
              const SizedBox(height: Primitives.space16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ArrowSkin.values.length,
                  separatorBuilder: (_, __) => Divider(
                    color: tokens.threadFaint,
                    height: 1.0,
                    indent: 12.0,
                    endIndent: 12.0,
                  ),
                  itemBuilder: (context, index) {
                    final skin = ArrowSkin.values[index];
                    final isSelected = skin == currentSkin;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Primitives.space12,
                        vertical: Primitives.space4,
                      ),
                      leading: Container(
                        width: 44.0,
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tokens.accent.withValues(alpha: 0.15)
                              : tokens.surfaceRaised,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color:
                                isSelected ? tokens.accent : tokens.threadFaint,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          skin.previewIcon,
                          style: const TextStyle(fontSize: 22.0),
                        ),
                      ),
                      title: Text(
                        skin.displayName,
                        style: tokens.typography.body.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? tokens.accent : tokens.ink,
                        ),
                      ),
                      subtitle: Text(
                        skin.description,
                        style: tokens.typography.caption,
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded,
                              color: tokens.accent, size: 24.0)
                          : null,
                      onTap: () {
                        haptics.selection();
                        ref.read(settingsProvider.notifier).setArrowSkin(skin);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            context.pop();
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
            // Section: Appearance & Customisation
            _SectionHeader(title: 'Customisation', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.threadFaint, width: 1.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Arrow Skin', style: tokens.typography.body),
                    subtitle: Text(
                      '${settings.arrowSkin.previewIcon}  ${settings.arrowSkin.displayName}',
                      style: tokens.typography.caption
                          .copyWith(color: tokens.accent),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: tokens.inkMuted),
                    onTap: () {
                      haptics.selection();
                      _showArrowSkinSheet();
                    },
                  ),
                  Divider(
                    color: tokens.threadFaint,
                    height: 1.0,
                    indent: 16.0,
                    endIndent: 16.0,
                  ),
                  ListTile(
                    title: Text('Theme', style: tokens.typography.body),
                    subtitle: Text(
                      settings.themeChoice.label,
                      style: tokens.typography.caption
                          .copyWith(color: tokens.accent),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: tokens.inkMuted),
                    onTap: () {
                      haptics.selection();
                      context.push(Routes.theme);
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
                side: BorderSide(color: tokens.threadFaint, width: 1.0),
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
                      settingsNotifier.setSound(val);
                      haptics.selection();
                      if (val) {
                        ref.read(audioServiceProvider).playUi();
                      }
                    },
                  ),
                  Divider(
                      color: tokens.threadFaint,
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
                      settingsNotifier.setHaptics(val);
                      haptics.updateHapticsEnabled(val);
                      if (val) {
                        haptics.selection();
                      }
                    },
                  ),
                  Divider(
                      color: tokens.threadFaint,
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

            // Section: Help
            _SectionHeader(title: 'Help', tokens: tokens),
            Card(
              color: tokens.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Primitives.radiusCard),
                side: BorderSide(color: tokens.threadFaint, width: 1.0),
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
                side: BorderSide(color: tokens.threadFaint, width: 1.0),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Share ArrowZ', style: tokens.typography.body),
                    subtitle: Text('Invite friends to play',
                        style: tokens.typography.caption),
                    trailing: Icon(Icons.share_rounded, color: tokens.accent),
                    onTap: () {
                      haptics.selection();
                      ShareService.shareApp();
                    },
                  ),
                  Divider(
                      color: tokens.threadFaint,
                      height: 1.0,
                      indent: 16.0,
                      endIndent: 16.0),
                  ListTile(
                    title: Text('Version', style: tokens.typography.body),
                    trailing: Text(_version, style: tokens.typography.caption),
                  ),
                  Divider(
                      color: tokens.threadFaint,
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
                      color: tokens.threadFaint,
                      height: 1.0,
                      indent: 16.0,
                      endIndent: 16.0),
                  Padding(
                    padding: const EdgeInsets.all(Primitives.space16),
                    child: Text(
                      'Nothing is collected. The game works fully offline.',
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

            if (QaConfig.isQaAvailable) ...[
              const SizedBox(height: Primitives.space24),
              _SectionHeader(title: 'Internal Testing', tokens: tokens),
              Card(
                color: tokens.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Primitives.radiusCard),
                  side: BorderSide(color: tokens.threadFaint, width: 1.0),
                ),
                child: ListTile(
                  key: const Key('qa_console_tile'),
                  leading:
                      Icon(Icons.build_circle_outlined, color: tokens.accent),
                  title:
                      Text('ArrowZ QA Console', style: tokens.typography.body),
                  subtitle: Text(
                    'Level jumping, puzzle diagnostics & testing tools',
                    style: tokens.typography.caption
                        .copyWith(color: tokens.inkMuted),
                  ),
                  trailing:
                      Icon(Icons.chevron_right_rounded, color: tokens.inkMuted),
                  onTap: () {
                    haptics.selection();
                    context.push(Routes.qaConsole);
                  },
                ),
              ),
            ],

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
