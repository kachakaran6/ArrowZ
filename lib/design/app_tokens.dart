import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/design/typography.dart';
import 'package:flutter/material.dart';

/// Semantic design tokens for Unwind.
///
/// Available on any [BuildContext] via `context.tokens`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.id = 'classic',
    this.displayName = 'Classic Sage',
    this.subtitle = 'Original',
    this.mood = 'Soft organic parchment',
    this.isDark = false,
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.thread,
    required this.threadFaint,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentGlow,
    required this.danger,
    required this.success,
    required this.scrim,
    required this.boardEdge,
    required this.gridDot,
    required this.progressFill,
    required this.progressTrack,
    required this.typography,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final String mood;
  final bool isDark;

  // Color roles
  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color thread;
  final Color threadFaint;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color accentGlow;
  final Color danger;
  final Color success;
  final Color scrim;
  final Color boardEdge;
  final Color gridDot;
  final Color progressFill;
  final Color progressTrack;

  // Typography
  final AppTypography typography;

  // Static non-colour tokens
  static const double space4 = Primitives.space4;
  static const double space8 = Primitives.space8;
  static const double space12 = Primitives.space12;
  static const double space16 = Primitives.space16;
  static const double space20 = Primitives.space20;
  static const double space24 = Primitives.space24;
  static const double space32 = Primitives.space32;
  static const double space40 = Primitives.space40;
  static const double space56 = Primitives.space56;

  static const double radius10 = Primitives.radius10;
  static const double radius16 = Primitives.radius16;
  static const double radius24 = Primitives.radius24;
  static const double radius28 = Primitives.radius28;

  static const double radiusChip = Primitives.radiusChip;
  static const double radiusButton = Primitives.radiusButton;
  static const double radiusCard = Primitives.radiusCard;
  static const double radiusSheet = Primitives.radiusSheet;

  static const Duration durationInstant = Primitives.durationInstant;
  static const Duration durationFast = Primitives.durationFast;
  static const Duration durationBase = Primitives.durationBase;
  static const Duration durationPage = Primitives.durationPage;
  static const Duration durationSlow = Primitives.durationSlow;
  static const Duration durationExitMin = Primitives.durationExitMin;
  static const Duration durationExitMax = Primitives.durationExitMax;

  static const Curve curveStandard = Primitives.curveStandard;
  static const Curve curveEnter = Primitives.curveEnter;
  static const Curve curveExitIn = Primitives.curveExitIn;

  @override
  AppTokens copyWith({
    String? id,
    String? displayName,
    String? subtitle,
    String? mood,
    bool? isDark,
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? thread,
    Color? threadFaint,
    Color? line,
    Color? accent,
    Color? onAccent,
    Color? accentGlow,
    Color? danger,
    Color? success,
    Color? scrim,
    Color? boardEdge,
    Color? gridDot,
    Color? progressFill,
    Color? progressTrack,
    AppTypography? typography,
  }) {
    return AppTokens(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      subtitle: subtitle ?? this.subtitle,
      mood: mood ?? this.mood,
      isDark: isDark ?? this.isDark,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      thread: thread ?? this.thread,
      threadFaint: threadFaint ?? this.threadFaint,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentGlow: accentGlow ?? this.accentGlow,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      scrim: scrim ?? this.scrim,
      boardEdge: boardEdge ?? this.boardEdge,
      gridDot: gridDot ?? this.gridDot,
      progressFill: progressFill ?? this.progressFill,
      progressTrack: progressTrack ?? this.progressTrack,
      typography: typography ?? this.typography,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      id: t < 0.5 ? id : other.id,
      displayName: t < 0.5 ? displayName : other.displayName,
      subtitle: t < 0.5 ? subtitle : other.subtitle,
      mood: t < 0.5 ? mood : other.mood,
      isDark: t < 0.5 ? isDark : other.isDark,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      thread: Color.lerp(thread, other.thread, t)!,
      threadFaint: Color.lerp(threadFaint, other.threadFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      boardEdge: Color.lerp(boardEdge, other.boardEdge, t)!,
      gridDot: Color.lerp(gridDot, other.gridDot, t)!,
      progressFill: Color.lerp(progressFill, other.progressFill, t)!,
      progressTrack: Color.lerp(progressTrack, other.progressTrack, t)!,
      typography: AppTypography.lerp(typography, other.typography, t),
    );
  }
}

/// Extension for convenient token access.
extension TokensContextExtension on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
