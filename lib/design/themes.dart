import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/design/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The 5 hand-tuned theme choices plus Follow system.
enum AppThemeMode {
  followSystem('Follow system', isDark: false),
  sageLinen('Sage Linen', isDark: false),
  inkAndBrass('Ink and Brass', isDark: true),
  fogSlate('Fog Slate', isDark: false),
  rosewood('Rosewood', isDark: false),
  graphiteEmber('Graphite Ember', isDark: true);

  const AppThemeMode(this.label, {required this.isDark});
  final String label;
  final bool isDark;
}

/// Catalog of themes and ThemeData builders.
abstract final class AppThemes {
  static const AppTokens sageLinenTokens = AppTokens(
    bg: Primitives.sageBg,
    surface: Primitives.sageSurface,
    surfaceRaised: Primitives.sageSurfaceRaised,
    ink: Primitives.sageInk,
    inkMuted: Primitives.sageInkMuted,
    inkFaint: Color(0xFF8C9686),
    thread: Primitives.sageInk,
    threadFaint: Primitives.sageThreadFaint,
    accent: Primitives.sageAccent,
    onAccent: Primitives.sageOnAccent,
    danger: Primitives.sageDanger,
    success: Primitives.sageSuccess,
    scrim: Color(0x6625302A),
    boardEdge: Color(0x2225302A),
    gridDot: Color(0xFFB9BFAF),
    progressFill: Color(0xFF8FA88F),
    progressTrack: Color(0xFFD7DDD1),
    typography: AppTypography(
      display: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 40.0,
        height: 44.0 / 40.0,
        fontWeight: FontWeight.w500,
        color: Primitives.sageInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      title: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 24.0,
        height: 30.0 / 24.0,
        fontWeight: FontWeight.w500,
        color: Primitives.sageInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      heading: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 18.0,
        height: 24.0 / 18.0,
        fontWeight: FontWeight.w700,
        color: Primitives.sageInk,
      ),
      body: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 15.0,
        height: 22.0 / 15.0,
        fontWeight: FontWeight.w500,
        color: Primitives.sageInk,
      ),
      label: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Primitives.sageInk,
      ),
      caption: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 12.0,
        height: 16.0 / 12.0,
        fontWeight: FontWeight.w500,
        color: Primitives.sageInkMuted,
      ),
    ),
  );

  static const AppTokens inkAndBrassTokens = AppTokens(
    bg: Primitives.brassBg,
    surface: Primitives.brassSurface,
    surfaceRaised: Primitives.brassSurfaceRaised,
    ink: Primitives.brassInk,
    inkMuted: Primitives.brassInkMuted,
    inkFaint: Color(0xFF5E584E),
    thread: Primitives.brassInk,
    threadFaint: Primitives.brassThreadFaint,
    accent: Primitives.brassAccent,
    onAccent: Primitives.brassOnAccent,
    danger: Primitives.brassDanger,
    success: Primitives.brassSuccess,
    scrim: Color(0x66000000),
    boardEdge: Color(0x22ECE6D8),
    gridDot: Color(0xFF3A3F47),
    progressFill: Color(0xFFCCA866),
    progressTrack: Color(0xFF343840),
    typography: AppTypography(
      display: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 40.0,
        height: 44.0 / 40.0,
        fontWeight: FontWeight.w500,
        color: Primitives.brassInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      title: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 24.0,
        height: 30.0 / 24.0,
        fontWeight: FontWeight.w500,
        color: Primitives.brassInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      heading: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 18.0,
        height: 24.0 / 18.0,
        fontWeight: FontWeight.w700,
        color: Primitives.brassInk,
      ),
      body: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 15.0,
        height: 22.0 / 15.0,
        fontWeight: FontWeight.w500,
        color: Primitives.brassInk,
      ),
      label: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Primitives.brassInk,
      ),
      caption: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 12.0,
        height: 16.0 / 12.0,
        fontWeight: FontWeight.w500,
        color: Primitives.brassInkMuted,
      ),
    ),
  );

  static const AppTokens fogSlateTokens = AppTokens(
    bg: Primitives.slateBg,
    surface: Primitives.slateSurface,
    surfaceRaised: Primitives.slateSurfaceRaised,
    ink: Primitives.slateInk,
    inkMuted: Primitives.slateInkMuted,
    inkFaint: Color(0xFF8A9CA8),
    thread: Primitives.slateInk,
    threadFaint: Primitives.slateThreadFaint,
    accent: Primitives.slateAccent,
    onAccent: Primitives.slateOnAccent,
    danger: Primitives.slateDanger,
    success: Primitives.slateSuccess,
    scrim: Color(0x6622303A),
    boardEdge: Color(0x2222303A),
    gridDot: Color(0xFFB4C0C8),
    progressFill: Color(0xFF7FA4B5),
    progressTrack: Color(0xFFC4CED4),
    typography: AppTypography(
      display: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 40.0,
        height: 44.0 / 40.0,
        fontWeight: FontWeight.w500,
        color: Primitives.slateInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      title: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 24.0,
        height: 30.0 / 24.0,
        fontWeight: FontWeight.w500,
        color: Primitives.slateInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      heading: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 18.0,
        height: 24.0 / 18.0,
        fontWeight: FontWeight.w700,
        color: Primitives.slateInk,
      ),
      body: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 15.0,
        height: 22.0 / 15.0,
        fontWeight: FontWeight.w500,
        color: Primitives.slateInk,
      ),
      label: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Primitives.slateInk,
      ),
      caption: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 12.0,
        height: 16.0 / 12.0,
        fontWeight: FontWeight.w500,
        color: Primitives.slateInkMuted,
      ),
    ),
  );

  static const AppTokens rosewoodTokens = AppTokens(
    bg: Primitives.roseBg,
    surface: Primitives.roseSurface,
    surfaceRaised: Primitives.roseSurfaceRaised,
    ink: Primitives.roseInk,
    inkMuted: Primitives.roseInkMuted,
    inkFaint: Color(0xFFA58E8A),
    thread: Primitives.roseInk,
    threadFaint: Primitives.roseThreadFaint,
    accent: Primitives.roseAccent,
    onAccent: Primitives.roseOnAccent,
    danger: Primitives.roseDanger,
    success: Primitives.roseSuccess,
    scrim: Color(0x663A2626),
    boardEdge: Color(0x223A2626),
    gridDot: Color(0xFFCDB5AC),
    progressFill: Color(0xFFB87888),
    progressTrack: Color(0xFFD9C5BD),
    typography: AppTypography(
      display: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 40.0,
        height: 44.0 / 40.0,
        fontWeight: FontWeight.w500,
        color: Primitives.roseInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      title: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 24.0,
        height: 30.0 / 24.0,
        fontWeight: FontWeight.w500,
        color: Primitives.roseInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      heading: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 18.0,
        height: 24.0 / 18.0,
        fontWeight: FontWeight.w700,
        color: Primitives.roseInk,
      ),
      body: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 15.0,
        height: 22.0 / 15.0,
        fontWeight: FontWeight.w500,
        color: Primitives.roseInk,
      ),
      label: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Primitives.roseInk,
      ),
      caption: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 12.0,
        height: 16.0 / 12.0,
        fontWeight: FontWeight.w500,
        color: Primitives.roseInkMuted,
      ),
    ),
  );

  static const AppTokens graphiteEmberTokens = AppTokens(
    bg: Primitives.emberBg,
    surface: Primitives.emberSurface,
    surfaceRaised: Primitives.emberSurfaceRaised,
    ink: Primitives.emberInk,
    inkMuted: Primitives.emberInkMuted,
    inkFaint: Color(0xFF645C51),
    thread: Primitives.emberInk,
    threadFaint: Primitives.emberThreadFaint,
    accent: Primitives.emberAccent,
    onAccent: Primitives.emberOnAccent,
    danger: Primitives.emberDanger,
    success: Primitives.emberSuccess,
    scrim: Color(0x66000000),
    boardEdge: Color(0x22E9E2D6),
    gridDot: Color(0xFF46403A),
    progressFill: Color(0xFFDC966E),
    progressTrack: Color(0xFF3A3530),
    typography: AppTypography(
      display: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 40.0,
        height: 44.0 / 40.0,
        fontWeight: FontWeight.w500,
        color: Primitives.emberInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      title: TextStyle(
        fontFamily: Primitives.fontDisplay,
        fontSize: 24.0,
        height: 30.0 / 24.0,
        fontWeight: FontWeight.w500,
        color: Primitives.emberInk,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      heading: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 18.0,
        height: 24.0 / 18.0,
        fontWeight: FontWeight.w700,
        color: Primitives.emberInk,
      ),
      body: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 15.0,
        height: 22.0 / 15.0,
        fontWeight: FontWeight.w500,
        color: Primitives.emberInk,
      ),
      label: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 13.0,
        height: 16.0 / 13.0,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: Primitives.emberInk,
      ),
      caption: TextStyle(
        fontFamily: Primitives.fontUi,
        fontSize: 12.0,
        height: 16.0 / 12.0,
        fontWeight: FontWeight.w500,
        color: Primitives.emberInkMuted,
      ),
    ),
  );

  /// Resolves [AppTokens] for a given [AppThemeMode] and platform [Brightness].
  static AppTokens tokensFor(AppThemeMode mode, Brightness platformBrightness) {
    return switch (mode) {
      AppThemeMode.followSystem => platformBrightness == Brightness.dark
          ? inkAndBrassTokens
          : sageLinenTokens,
      AppThemeMode.sageLinen => sageLinenTokens,
      AppThemeMode.inkAndBrass => inkAndBrassTokens,
      AppThemeMode.fogSlate => fogSlateTokens,
      AppThemeMode.rosewood => rosewoodTokens,
      AppThemeMode.graphiteEmber => graphiteEmberTokens,
    };
  }

  /// Builds a [ThemeData] from [AppTokens] with consistent Material 3 styling.
  static ThemeData buildThemeData(AppTokens tokens, {required bool isDark}) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: tokens.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: tokens.accent,
        onPrimary: tokens.onAccent,
        secondary: tokens.accent,
        onSecondary: tokens.onAccent,
        error: tokens.danger,
        onError: tokens.onAccent,
        surface: tokens.surface,
        onSurface: tokens.ink,
      ),
      canvasColor: tokens.bg,
      cardColor: tokens.surfaceRaised,
      dividerColor: tokens.threadFaint,
      splashColor: tokens.accent.withValues(alpha: 0.1),
      highlightColor: tokens.accent.withValues(alpha: 0.05),
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.bg,
        foregroundColor: tokens.ink,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: tokens.bg,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        modalBackgroundColor: tokens.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Primitives.radiusSheet),
          ),
        ),
        elevation: 0,
        modalBarrierColor: tokens.scrim,
      ),
    );
  }
}
