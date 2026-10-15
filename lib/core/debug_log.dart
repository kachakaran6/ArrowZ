import 'package:flutter/foundation.dart';

/// Centralized debug logging helper.
///
/// Output is compiled out in release builds.
void debugLog(String message) {
  if (!kReleaseMode) {
    debugPrint('[ArrowZ] $message');
  }
}
