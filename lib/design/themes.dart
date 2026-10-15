import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/themes/classic_sage.dart';
import 'package:arrowtapout/design/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Catalog of themes, contrast gates, and ThemeData builders for ArrowZ.
abstract final class AppThemes {
  static const String fallbackThemeId = ClassicSageTheme.id; // 'classic'
  static const String defaultThemeId = 'obsidian'; // Obsidian Lime

  // 1. Obsidian Lime (Default)
  static final AppTokens obsidianLimeTokens = AppTokens(
    id: 'obsidian',
    displayName: 'Obsidian Lime',
    subtitle: 'Sharp and focused',
    mood: 'Sharp and focused',
    isDark: true,
    bg: const Color(0xFF0C0E0D),
    surface: const Color(0xFF141816),
    surfaceRaised: const Color(0xFF1C211E),
    ink: const Color(0xFFECEFE6),
    inkMuted: const Color(0xFF8E978C),
    inkFaint: const Color(0xFF555D53),
    thread: const Color(0xFFDDE3D3),
    threadFaint: const Color(0xFF434C41),
    gridDot: const Color(0xFF2A312C),
    accent: const Color(0xFFB8F05A),
    onAccent: const Color(0xFF0C0E0D),
    accentGlow: const Color(0x40B8F05A), // 25% opacity
    danger: const Color(0xFFFF6B5E),
    success: const Color(0xFF7ED98B),
    scrim: const Color(0xB80C0E0D), // 72% opacity bg
    line: const Color(0xFF232A26),
    boardEdge: const Color(0xFF232A26),
    progressFill: const Color(0xFFB8F05A),
    progressTrack: const Color(0xFF1C211E),
    typography: AppTypography.standard(
      ink: const Color(0xFFECEFE6),
      inkMuted: const Color(0xFF8E978C),
    ),
  );

  // 2. Ember Night
  static final AppTokens emberNightTokens = AppTokens(
    id: 'ember',
    displayName: 'Ember Night',
    subtitle: 'Warm and intense',
    mood: 'Warm and intense',
    isDark: true,
    bg: const Color(0xFF110E0C),
    surface: const Color(0xFF1A1512),
    surfaceRaised: const Color(0xFF241D19),
    ink: const Color(0xFFF3ECE3),
    inkMuted: const Color(0xFFA4968A),
    inkFaint: const Color(0xFF655B52),
    thread: const Color(0xFFE8DDD0),
    threadFaint: const Color(0xFF4C423B),
    gridDot: const Color(0xFF352C26),
    accent: const Color(0xFFFF8A3D),
    onAccent: const Color(0xFF110E0C),
    accentGlow: const Color(0x40FF8A3D),
    danger: const Color(0xFFFF5C5C),
    success: const Color(0xFF9BD17A),
    scrim: const Color(0xB8110E0C),
    line: const Color(0xFF2E2520),
    boardEdge: const Color(0xFF2E2520),
    progressFill: const Color(0xFFFF8A3D),
    progressTrack: const Color(0xFF241D19),
    typography: AppTypography.standard(
      ink: const Color(0xFFF3ECE3),
      inkMuted: const Color(0xFFA4968A),
    ),
  );

  // 3. Abyss
  static final AppTokens abyssTokens = AppTokens(
    id: 'abyss',
    displayName: 'Abyss',
    subtitle: 'Deep oceanic calm',
    mood: 'Deep oceanic calm',
    isDark: true,
    bg: const Color(0xFF081115),
    surface: const Color(0xFF0E1B21),
    surfaceRaised: const Color(0xFF14272F),
    ink: const Color(0xFFE4F1F2),
    inkMuted: const Color(0xFF86A0A6),
    inkFaint: const Color(0xFF536970),
    thread: const Color(0xFFCFE4E6),
    threadFaint: const Color(0xFF3F545B),
    gridDot: const Color(0xFF1D3139),
    accent: const Color(0xFF35D1C0),
    onAccent: const Color(0xFF081115),
    accentGlow: const Color(0x4035D1C0),
    danger: const Color(0xFFFF7A6B),
    success: const Color(0xFF6FE0A0),
    scrim: const Color(0xB8081115),
    line: const Color(0xFF1A333E),
    boardEdge: const Color(0xFF1A333E),
    progressFill: const Color(0xFF35D1C0),
    progressTrack: const Color(0xFF14272F),
    typography: AppTypography.standard(
      ink: const Color(0xFFE4F1F2),
      inkMuted: const Color(0xFF86A0A6),
    ),
  );

  // 4. Gold Noir
  static final AppTokens goldNoirTokens = AppTokens(
    id: 'gold',
    displayName: 'Gold Noir',
    subtitle: 'Refined and luxurious',
    mood: 'Refined and luxurious',
    isDark: true,
    bg: const Color(0xFF0D0C0A),
    surface: const Color(0xFF161410),
    surfaceRaised: const Color(0xFF1F1C16),
    ink: const Color(0xFFF1EBDD),
    inkMuted: const Color(0xFF9D9684),
    inkFaint: const Color(0xFF635E52),
    thread: const Color(0xFFE6DFCC),
    threadFaint: const Color(0xFF4B463C),
    gridDot: const Color(0xFF2D2A22),
    accent: const Color(0xFFE3B85C),
    onAccent: const Color(0xFF0D0C0A),
    accentGlow: const Color(0x40E3B85C),
    danger: const Color(0xFFE8694F),
    success: const Color(0xFFA7C96B),
    scrim: const Color(0xB80D0C0A),
    line: const Color(0xFF2B261E),
    boardEdge: const Color(0xFF2B261E),
    progressFill: const Color(0xFFE3B85C),
    progressTrack: const Color(0xFF1F1C16),
    typography: AppTypography.standard(
      ink: const Color(0xFFF1EBDD),
      inkMuted: const Color(0xFF9D9684),
    ),
  );

  // 5. Crimson Steel
  static final AppTokens crimsonSteelTokens = AppTokens(
    id: 'crimson',
    displayName: 'Crimson Steel',
    subtitle: 'High contrast industrial',
    mood: 'High contrast industrial',
    isDark: true,
    bg: const Color(0xFF0F1012),
    surface: const Color(0xFF17181B),
    surfaceRaised: const Color(0xFF202226),
    ink: const Color(0xFFEDEDEF),
    inkMuted: const Color(0xFF93959C),
    inkFaint: const Color(0xFF5C5E66),
    thread: const Color(0xFFDADCE0),
    threadFaint: const Color(0xFF464850),
    gridDot: const Color(0xFF2B2D32),
    accent: const Color(0xFFF2495C),
    onAccent: const Color(0xFF0F1012),
    accentGlow: const Color(0x40F2495C),
    danger: const Color(0xFFFFB020), // Amber danger per spec so danger != accent
    success: const Color(0xFF7ED98B),
    scrim: const Color(0xB80F1012),
    line: const Color(0xFF292C32),
    boardEdge: const Color(0xFF292C32),
    progressFill: const Color(0xFFF2495C),
    progressTrack: const Color(0xFF202226),
    typography: AppTypography.standard(
      ink: const Color(0xFFEDEDEF),
      inkMuted: const Color(0xFF93959C),
    ),
  );

  // 6. Classic Sage (Retained fallback)
  static final AppTokens classicSageTokens = ClassicSageTheme.tokens();

  /// All 6 themes in order: 5 new dark console themes followed by Classic Sage.
  static final List<AppTokens> allThemes = [
    obsidianLimeTokens,
    emberNightTokens,
    abyssTokens,
    goldNoirTokens,
    crimsonSteelTokens,
    classicSageTokens,
  ];

  /// Resolves an [AppTokens] by its [themeId].
  ///
  /// If unknown or missing, silently falls back to [classicSageTokens].
  static AppTokens themeForId(String? themeId) {
    if (themeId == null) return obsidianLimeTokens;
    for (final theme in allThemes) {
      if (theme.id == themeId) return theme;
    }
    // Fallback: if saved theme id is unknown, return Classic Sage
    return classicSageTokens;
  }

  /// Builds a [ThemeData] from [AppTokens] with consistent Material 3 styling.
  static ThemeData buildThemeData(AppTokens tokens, {required bool isDark}) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      secondary: tokens.accent,
      onSecondary: tokens.onAccent,
      error: tokens.danger,
      onError: tokens.bg,
      surface: tokens.surface,
      onSurface: tokens.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.bg,
      canvasColor: tokens.bg,
      cardColor: tokens.surface,
      dividerColor: tokens.line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        iconTheme: IconThemeData(color: tokens.ink),
        titleTextStyle: tokens.typography.title,
      ),
      extensions: [tokens],
    );
  }

  /// Compatibility getters for legacy tests
  static AppTokens get sageLinenTokens => classicSageTokens;
  static AppTokens get inkAndBrassTokens => obsidianLimeTokens;
  static AppTokens get graphiteEmberTokens => emberNightTokens;
  static AppTokens get fogSlateTokens => abyssTokens;
  static AppTokens get rosewoodTokens => crimsonSteelTokens;

  static AppTokens tokensFor(dynamic mode, [Brightness? _]) {
    if (mode is AppTokens) return mode;
    if (mode == AppThemeMode.sageLinen || mode == AppThemeMode.classic) {
      return classicSageTokens;
    }
    if (mode == AppThemeMode.graphiteEmber || mode == AppThemeMode.ember) {
      return emberNightTokens;
    }
    if (mode == AppThemeMode.inkAndBrass || mode == AppThemeMode.obsidian) {
      return obsidianLimeTokens;
    }
    if (mode == AppThemeMode.fogSlate) {
      return abyssTokens;
    }
    if (mode == AppThemeMode.rosewood) {
      return crimsonSteelTokens;
    }
    return themeForId(mode?.toString().split('.').last);
  }
}

enum AppThemeMode {
  sageLinen,
  inkAndBrass,
  graphiteEmber,
  fogSlate,
  rosewood,
  classic,
  obsidian,
  ember;

  bool get isDark =>
      this != AppThemeMode.sageLinen && this != AppThemeMode.classic;
}


