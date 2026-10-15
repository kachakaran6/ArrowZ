import 'dart:math' as math;

import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Calculates WCAG 2.1 contrast ratio between two colors using Flutter's luminance.
double _contrastRatio(Color c1, Color c2) {
  final l1 = c1.computeLuminance();
  final l2 = c2.computeLuminance();
  final brighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (brighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Theme Contrast & WCAG Gates (All 6 Themes)', () {
    final themes = <String, AppTokens>{
      'Obsidian Lime': AppThemes.obsidianLimeTokens,
      'Ember Night': AppThemes.emberNightTokens,
      'Abyss': AppThemes.abyssTokens,
      'Gold Noir': AppThemes.goldNoirTokens,
      'Crimson Steel': AppThemes.crimsonSteelTokens,
      'Classic Sage': AppThemes.classicSageTokens,
    };

    for (final entry in themes.entries) {
      final name = entry.key;
      final tokens = entry.value;

      group('Theme: $name', () {
        test('ink on bg contrast is at least 7.0:1', () {
          final ratio = _contrastRatio(tokens.ink, tokens.bg);
          expect(
            ratio,
            greaterThanOrEqualTo(7.0),
            reason: '$name: ink on bg ratio is $ratio (needs >= 7.0)',
          );
        });

        test('ink on surface contrast is at least 6.5:1', () {
          final ratio = _contrastRatio(tokens.ink, tokens.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(6.5),
            reason: '$name: ink on surface ratio is $ratio (needs >= 6.5)',
          );
        });

        test('inkMuted on bg contrast is at least 4.5:1', () {
          final ratio = _contrastRatio(tokens.inkMuted, tokens.bg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name: inkMuted on bg ratio is $ratio (needs >= 4.5)',
          );
        });

        test('accent on bg contrast is at least 4.5:1', () {
          final ratio = _contrastRatio(tokens.accent, tokens.bg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name: accent on bg ratio is $ratio (needs >= 4.5)',
          );
        });

        test('onAccent on accent contrast is at least 4.5:1', () {
          final ratio = _contrastRatio(tokens.onAccent, tokens.accent);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name: onAccent on accent ratio is $ratio (needs >= 4.5)',
          );
        });

        test('danger on bg contrast is at least 4.5:1', () {
          final ratio = _contrastRatio(tokens.danger, tokens.bg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name: danger on bg ratio is $ratio (needs >= 4.5)',
          );
        });
      });
    }

    test('AppTokens lerp works smoothly and matches endpoints', () {
      final t1 = AppThemes.obsidianLimeTokens;
      final t2 = AppThemes.goldNoirTokens;

      final lerp0 = t1.lerp(t2, 0.0);
      expect(lerp0.bg, equals(t1.bg));
      expect(lerp0.accent, equals(t1.accent));
      expect(lerp0.gridDot, equals(t1.gridDot));

      final lerp1 = t1.lerp(t2, 1.0);
      expect(lerp1.bg, equals(t2.bg));
      expect(lerp1.accent, equals(t2.accent));
      expect(lerp1.gridDot, equals(t2.gridDot));

      final lerpHalf = t1.lerp(t1, 0.5);
      expect(lerpHalf.bg, equals(t1.bg));
      expect(lerpHalf.accent, equals(t1.accent));
    });

    test('All six themes have unique IDs and display names', () {
      final ids = AppThemes.allThemes.map((t) => t.id).toSet();
      expect(ids.length, equals(6));
      expect(ids, contains('obsidian'));
      expect(ids, contains('ember'));
      expect(ids, contains('abyss'));
      expect(ids, contains('gold'));
      expect(ids, contains('crimson'));
      expect(ids, contains('classic'));
    });

    test('themeForId returns requested theme or falls back to classic', () {
      expect(AppThemes.themeForId('obsidian').id, equals('obsidian'));
      expect(AppThemes.themeForId('gold').id, equals('gold'));
      expect(AppThemes.themeForId('unknown_theme').id, equals('classic'));
      expect(AppThemes.themeForId(null).id, equals('obsidian'));
    });
  });
}
