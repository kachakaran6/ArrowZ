import 'dart:convert';

import 'package:arrowtapout/data/arrow_skin.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    this.themeChoice = AppThemeMode.followSystem,
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
    this.arrowSkin = ArrowSkin.chevron,
  });

  final AppThemeMode themeChoice;
  final bool sound;
  final bool haptics;
  final bool reduceMotion;
  final ArrowSkin arrowSkin;

  SettingsState copyWith({
    AppThemeMode? themeChoice,
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    ArrowSkin? arrowSkin,
  }) {
    return SettingsState(
      themeChoice: themeChoice ?? this.themeChoice,
      sound: sound ?? this.sound,
      haptics: haptics ?? this.haptics,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      arrowSkin: arrowSkin ?? this.arrowSkin,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeChoice': themeChoice.name,
        'sound': sound,
        'haptics': haptics,
        'reduceMotion': reduceMotion,
        'arrowSkin': arrowSkin.name,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    AppThemeMode mode = AppThemeMode.followSystem;
    final name = json['themeChoice'] as String?;
    if (name != null) {
      mode = AppThemeMode.values.firstWhere(
        (e) => e.name == name,
        orElse: () => AppThemeMode.followSystem,
      );
    }

    return SettingsState(
      themeChoice: mode,
      sound: json['sound'] as bool? ?? true,
      haptics: json['haptics'] as bool? ?? true,
      reduceMotion: json['reduceMotion'] as bool? ?? false,
      arrowSkin: ArrowSkin.fromId(json['arrowSkin'] as String?),
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
        state = SettingsState.fromJson(map);
      } catch (_) {
        // Fallback to defaults
      }
    }
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> setThemeChoice(AppThemeMode mode) async {
    state = state.copyWith(themeChoice: mode);
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

  Future<void> setArrowSkin(ArrowSkin skin) async {
    state = state.copyWith(arrowSkin: skin);
    await _save();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsRepository, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});
