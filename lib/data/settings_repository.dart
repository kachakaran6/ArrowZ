import 'dart:convert';

import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    this.themeId = AppThemes.defaultThemeId,
    this.lastGoodThemeId = AppThemes.defaultThemeId,
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.showChainCounter = true,
    this.idleHintNudge = true,
  });

  final String themeId;
  final String lastGoodThemeId;
  final bool sound;
  final bool haptics;
  final bool reduceMotion;
  final bool showChainCounter;
  final bool idleHintNudge;

  SettingsState copyWith({
    String? themeId,
    String? lastGoodThemeId,
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    bool? showChainCounter,
    bool? idleHintNudge,
  }) {
    return SettingsState(
      themeId: themeId ?? this.themeId,
      lastGoodThemeId: lastGoodThemeId ?? this.lastGoodThemeId,
      sound: sound ?? this.sound,
      haptics: haptics ?? this.haptics,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      showChainCounter: showChainCounter ?? this.showChainCounter,
      idleHintNudge: idleHintNudge ?? this.idleHintNudge,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeId': themeId,
        'lastGoodThemeId': lastGoodThemeId,
        'sound': sound,
        'haptics': haptics,
        'reduceMotion': reduceMotion,
        'showChainCounter': showChainCounter,
        'idleHintNudge': idleHintNudge,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    String resolvedThemeId = AppThemes.defaultThemeId;

    if (json.containsKey('themeId')) {
      final rawId = json['themeId'] as String?;
      final isValid = AppThemes.allThemes.any((t) => t.id == rawId);
      resolvedThemeId = isValid ? rawId! : AppThemes.fallbackThemeId;
    } else if (json.containsKey('themeChoice')) {
      // Existing user migration: existing users keep their current theme (Classic Sage)
      resolvedThemeId = AppThemes.fallbackThemeId;
    } else {
      // Fresh install defaults to Obsidian Lime
      resolvedThemeId = AppThemes.defaultThemeId;
    }

    final rawLastGood = json['lastGoodThemeId'] as String?;
    final resolvedLastGood = AppThemes.allThemes.any((t) => t.id == rawLastGood)
        ? rawLastGood!
        : resolvedThemeId;

    return SettingsState(
      themeId: resolvedThemeId,
      lastGoodThemeId: resolvedLastGood,
      sound: json['sound'] as bool? ?? true,
      haptics: json['haptics'] as bool? ?? true,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      showChainCounter: json['showChainCounter'] as bool? ?? true,
      idleHintNudge: json['idleHintNudge'] as bool? ?? true,
    );
  }
}

class SettingsRepository extends StateNotifier<SettingsState> {
  SettingsRepository(this._prefs) : super(const SettingsState()) {
    _load();
  }

  final SharedPreferences? _prefs;
  static const String _key = 'unwind.settings';

  void _load() {
    if (_prefs == null) return;
    final str = _prefs.getString(_key);
    if (str != null) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final parsed = SettingsState.fromJson(map);
        state = parsed;

        // If the theme in saved json was invalid/unknown, rewrite setting to fallback
        final savedRawThemeId = map['themeId'] as String?;
        if (savedRawThemeId != null &&
            !AppThemes.allThemes.any((t) => t.id == savedRawThemeId)) {
          _save();
        }
      } catch (_) {
        // Fallback to defaults with classic fallback if corrupt
        state = const SettingsState(
          themeId: AppThemes.fallbackThemeId,
          lastGoodThemeId: AppThemes.fallbackThemeId,
        );
        _save();
      }
    }
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> setThemeId(String id) async {
    final isValid = AppThemes.allThemes.any((t) => t.id == id);
    final appliedId = isValid ? id : AppThemes.fallbackThemeId;
    state = state.copyWith(themeId: appliedId);
    await _save();
  }

  Future<void> markThemeGood(String id) async {
    if (state.lastGoodThemeId != id) {
      state = state.copyWith(lastGoodThemeId: id);
      await _save();
    }
  }

  Future<void> resetToClassicSage() async {
    state = state.copyWith(
      themeId: AppThemes.fallbackThemeId,
      lastGoodThemeId: AppThemes.fallbackThemeId,
    );
    await _save();
  }

  Future<void> setSound(bool enabled) async {
    state = state.copyWith(sound: enabled);
    await _save();
  }

  Future<void> setHaptics(bool enabled) async {
    state = state.copyWith(haptics: enabled);
    await _save();
  }

  Future<void> setReduceMotion(bool enabled) async {
    state = state.copyWith(reduceMotion: enabled);
    await _save();
  }

  Future<void> setShowChainCounter(bool enabled) async {
    state = state.copyWith(showChainCounter: enabled);
    await _save();
  }

  Future<void> setIdleHintNudge(bool enabled) async {
    state = state.copyWith(idleHintNudge: enabled);
    await _save();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsRepository, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});
