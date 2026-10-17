import 'package:flutter/foundation.dart';

/// Centralized compile-time configuration and access control policy for QA tooling.
///
/// Security & Access Control Model:
/// - Debug builds: QA tools are available by default for local engineering convenience.
/// - Profile builds: QA tools are strictly DISABLED unless `--dart-define=ENABLE_QA_TOOLS=true`.
/// - Release builds: QA tools are strictly DISABLED by default. Authorized internal QA
///   release builds must be explicitly built with `--dart-define=ENABLE_QA_TOOLS=true`.
/// - Normal production releases NEVER expose QA tools, hidden gestures, or client-editable preferences.
class QaConfig {
  QaConfig._();

  /// Dedicated compile-time flag name.
  static const String flagName = 'ENABLE_QA_TOOLS';

  /// Compile-time constant injected via `--dart-define=ENABLE_QA_TOOLS=true`.
  static const bool _compileTimeFlag =
      bool.fromEnvironment(flagName, defaultValue: false);

  /// Test-only override hook for unit and widget testing.
  /// Strictly null in normal runtime.
  @visibleForTesting
  static bool? testOverride;

  /// Returns whether QA testing tools and navigation endpoints are accessible.
  static bool get isQaAvailable {
    if (testOverride != null) {
      return testOverride!;
    }

    const hasFlag = bool.hasEnvironment(flagName);
    if (hasFlag) {
      // Explicit compile-time decision takes precedence
      return _compileTimeFlag;
    }

    // Default policy when compile-time flag is not passed:
    // Debug builds enable QA tools locally.
    // Profile and Release builds disable QA tools completely.
    return kDebugMode;
  }

  /// Pure decision evaluator for matrix testing across build configurations.
  static bool evaluatePolicy({
    required bool isDebug,
    required bool isProfile,
    required bool isRelease,
    required bool hasCompileTimeFlag,
    required bool compileTimeFlagValue,
  }) {
    if (hasCompileTimeFlag) {
      return compileTimeFlagValue;
    }
    // Only debug builds default to enabled when flag is omitted
    return isDebug;
  }
}
