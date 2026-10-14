import 'dart:async';

import 'package:arrowtapout/data/settings_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract executor interface for platform haptic invocations.
abstract class HapticPlatformExecutor {
  const HapticPlatformExecutor();
  Future<void> lightImpact();
  Future<void> mediumImpact();
  Future<void> heavyImpact() => mediumImpact();
  Future<void> selectionClick();
}

/// Default system platform executor invoking Flutter's [HapticFeedback].
class SystemHapticPlatformExecutor implements HapticPlatformExecutor {
  const SystemHapticPlatformExecutor();

  @override
  Future<void> lightImpact() => HapticFeedback.lightImpact();

  @override
  Future<void> mediumImpact() => HapticFeedback.mediumImpact();

  @override
  Future<void> heavyImpact() => HapticFeedback.heavyImpact();

  @override
  Future<void> selectionClick() => HapticFeedback.selectionClick();
}

/// Haptic feedback service for ArrowZ.
///
/// Dispatches tactile feedback immediately at user interaction boundaries,
/// decoupled from visual animation progression, audio playback, and snapshot persistence.
class HapticsService {
  HapticsService(
    this._ref, {
    HapticPlatformExecutor? executor,
  }) : _executor = executor ?? const SystemHapticPlatformExecutor();

  final Ref _ref;
  final HapticPlatformExecutor _executor;

  /// Whether haptic feedback is enabled in user settings.
  bool get isEnabled {
    try {
      return _ref.read(settingsProvider).haptics;
    } catch (_) {
      return false;
    }
  }

  /// Light haptic feedback triggered immediately on a valid arrow tap/pull.
  ///
  /// Dispatched without awaiting arrow exit animations or persistence saves.
  Future<void> light() async {
    if (!isEnabled) return;
    try {
      await _executor.lightImpact();
    } catch (e) {
      debugPrint('HapticsService.light failed: $e');
    }
  }

  /// Strong haptic feedback triggered immediately on a blocked/wrong arrow tap.
  Future<void> heavy() async {
    if (!isEnabled) return;
    try {
      await _executor.heavyImpact();
    } catch (e) {
      debugPrint('HapticsService.heavy failed: $e');
    }
  }

  /// Medium haptic feedback triggered on restrained interactions.
  Future<void> medium() async {
    if (!isEnabled) return;
    try {
      await _executor.mediumImpact();
    } catch (e) {
      debugPrint('HapticsService.medium failed: $e');
    }
  }

  /// Subtle click haptic triggered on UI navigation and button presses.
  Future<void> selection() async {
    if (!isEnabled) return;
    try {
      await _executor.selectionClick();
    } catch (e) {
      debugPrint('HapticsService.selection failed: $e');
    }
  }

  /// Cleans up any resources when the service is disposed.
  void dispose() {}
}

final hapticsServiceProvider = Provider<HapticsService>((ref) {
  final service = HapticsService(ref);
  ref.onDispose(service.dispose);
  return service;
});
