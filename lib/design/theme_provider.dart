import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for current active [AppTokens], driven by [settingsProvider.themeId].
final currentTokensProvider = Provider<AppTokens>((ref) {
  final themeId = ref.watch(settingsProvider.select((s) => s.themeId));
  return AppThemes.themeForId(themeId);
});

/// Provider for current active [ThemeData].
final currentThemeProvider = Provider<ThemeData>((ref) {
  final tokens = ref.watch(currentTokensProvider);
  return AppThemes.buildThemeData(tokens, isDark: tokens.isDark);
});

/// Legacy compatibility provider for tests.
final themeModeProvider = Provider<AppThemeMode>((ref) {
  return AppThemeMode.obsidian;
});

