import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for current selected [AppThemeMode].
final themeModeProvider = Provider<AppThemeMode>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.themeChoice;
});

/// Provider for active platform brightness.
final platformBrightnessProvider = StateProvider<Brightness>((ref) {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
});

/// Provider for current active [AppTokens].
final currentTokensProvider = Provider<AppTokens>((ref) {
  final mode = ref.watch(themeModeProvider);
  final brightness = ref.watch(platformBrightnessProvider);
  return AppThemes.tokensFor(mode, brightness);
});

/// Provider for current active [ThemeData].
final currentThemeProvider = Provider<ThemeData>((ref) {
  final tokens = ref.watch(currentTokensProvider);
  final mode = ref.watch(themeModeProvider);
  final brightness = ref.watch(platformBrightnessProvider);
  final isDark = mode == AppThemeMode.followSystem
      ? brightness == Brightness.dark
      : mode.isDark;
  return AppThemes.buildThemeData(tokens, isDark: isDark);
});
