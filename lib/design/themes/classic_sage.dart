import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/design/typography.dart';
import 'package:flutter/material.dart';

/// The original untouched Sage Linen theme, preserved as the permanent fallback.
abstract final class ClassicSageTheme {
  static const String id = 'classic';
  static const String displayName = 'Classic Sage';
  static const String subtitle = 'Original';
  static const String mood = 'Soft organic parchment';

  static AppTokens tokens({AppTypography? typography}) {
    final typo = typography ??
        AppTypography.standard(
          ink: Primitives.sageInk,
          inkMuted: Primitives.sageInkMuted,
        );

    return AppTokens(
      id: id,
      displayName: displayName,
      subtitle: subtitle,
      isDark: false,
      bg: Primitives.sageBg,
      surface: Primitives.sageSurface,
      surfaceRaised: Primitives.sageSurfaceRaised,
      ink: Primitives.sageInk,
      inkMuted: Primitives.sageInkMuted,
      inkFaint: const Color(0xFF7D8F81),
      thread: Primitives.sageInk,
      threadFaint: Primitives.sageThreadFaint,
      line: const Color(0xFFD6DDD1),
      accent: Primitives.sageAccent,
      onAccent: Primitives.sageOnAccent,
      accentGlow: const Color(0x402D5A3C),
      danger: Primitives.sageDanger,
      success: Primitives.sageSuccess,
      scrim: const Color(0xB8F3F1EC), // 72% opacity bg
      boardEdge: const Color(0x2216261C),
      gridDot: const Color(0xFFB8C6B3),
      progressFill: const Color(0xFF7FA277),
      progressTrack: const Color(0xFFD7E1D2),
      typography: typo,
    );
  }
}
