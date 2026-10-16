import 'dart:io';

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class UpdateService {
  Future<void> checkForUpdates(BuildContext context);
  Future<void> completeFlexibleUpdateIfReady();
}

class NoOpUpdateService implements UpdateService {
  @override
  Future<void> checkForUpdates(BuildContext context) async {}

  @override
  Future<void> completeFlexibleUpdateIfReady() async {}
}

class PlayUpdateService implements UpdateService {
  PlayUpdateService(this._prefs);

  final SharedPreferences? _prefs;
  static const String _keyLastCheck = 'unwind.play.lastUpdateCheck';
  static const String _keyLastDismiss = 'unwind.play.lastUpdateDismiss';

  bool _flexibleDownloaded = false;

  @override
  Future<void> checkForUpdates(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCheck = _prefs?.getInt(_keyLastCheck) ?? 0;
    final lastDismiss = _prefs?.getInt(_keyLastDismiss) ?? 0;

    // Rate limit 1: Check at most once per 12 hours
    if (now - lastCheck < 12 * 3600 * 1000) return;

    // Rate limit 2: If dismissed, wait at least 3 days
    if (now - lastDismiss < 3 * 24 * 3600 * 1000) return;

    try {
      await _prefs?.setInt(_keyLastCheck, now);
      final updateInfo = await InAppUpdate.checkForUpdate();

      // Case A: A developer-triggered update is currently running
      if (updateInfo.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      // Case B: An update was already downloaded in background and is ready to install
      if (updateInfo.installStatus == InstallStatus.downloaded) {
        _flexibleDownloaded = true;
        if (context.mounted) {
          _showUpdateDownloadedBottomSheet(context);
        }
        return;
      }

      // Case C: An update is available on Google Play
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // High priority (>= 4) or immediate-only uses immediate update flow
        if (updateInfo.immediateUpdateAllowed &&
            (updateInfo.updatePriority >= 4 ||
                !updateInfo.flexibleUpdateAllowed)) {
          await InAppUpdate.performImmediateUpdate();
        } else if (updateInfo.flexibleUpdateAllowed) {
          // Triggers Google Play Store's official native bottom sheet
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result == AppUpdateResult.success) {
            _flexibleDownloaded = true;
            if (context.mounted) {
              _showUpdateDownloadedBottomSheet(context);
            }
          } else {
            await _prefs?.setInt(
                _keyLastDismiss, DateTime.now().millisecondsSinceEpoch);
          }
        }
      }
    } catch (_) {
      // Offline, non-Play install, or API unavailable - fails silently
    }
  }

  @override
  Future<void> completeFlexibleUpdateIfReady() async {
    if (!Platform.isAndroid || !_flexibleDownloaded) return;
    try {
      await InAppUpdate.completeFlexibleUpdate();
      _flexibleDownloaded = false;
    } catch (_) {}
  }

  /// Displays the native-styled Google Play update bottom sheet informing the
  /// user that an update has finished downloading and prompting them to restart.
  void _showUpdateDownloadedBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tokens = ctx.tokens;
        return Container(
          margin: const EdgeInsets.all(Primitives.space16),
          padding: const EdgeInsets.symmetric(
            horizontal: Primitives.space20,
            vertical: Primitives.space20,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: tokens.threadFaint,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.ink.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.0,
                    height: 44.0,
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      color: tokens.accent,
                      size: 24.0,
                    ),
                  ),
                  const SizedBox(width: Primitives.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Ready',
                          style: tokens.typography.heading.copyWith(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          'Restart to install the latest ArrowZ update.',
                          style: tokens.typography.caption.copyWith(
                            fontSize: 12.5,
                            color: tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Primitives.space20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.ink,
                        side: BorderSide(color: tokens.threadFaint),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(Primitives.radiusButton),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      child: Text(
                        'Later',
                        style: tokens.typography.label.copyWith(
                          color: tokens.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Primitives.space12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        completeFlexibleUpdateIfReady();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: tokens.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(Primitives.radiusButton),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      child: Text(
                        'Restart Now',
                        style: tokens.typography.label.copyWith(
                          color: tokens.onAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

final playUpdateServiceProvider = Provider<UpdateService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (Platform.isAndroid) {
    return PlayUpdateService(prefs);
  }
  return NoOpUpdateService();
});
