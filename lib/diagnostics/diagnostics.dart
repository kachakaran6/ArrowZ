import 'dart:ui';
import 'package:arrowtapout/core/debug_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum TapRejectedReason {
  noThreadInTolerance,
  slopExceeded,
  tooLong,
  threadAlreadyGone,
  levelNotPlayable,
  sheetOpen,
  other,
}

/// Singleton diagnostics engine capturing performance, input latency, animation health,
/// audio metrics, and widget rebuild frequencies.
class Diagnostics extends ChangeNotifier {
  Diagnostics._() {
    if (!kReleaseMode) {
      WidgetsBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  static final Diagnostics instance = Diagnostics._();

  // --- Frame Timing ---
  static const int _maxFrameHistory = 300;
  final List<double> _buildMsList = [];
  final List<double> _rasterMsList = [];
  final List<double> _totalMsList = [];
  int _totalFrameCount = 0;
  int _jankFrameCount = 0; // > 16.666 ms

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _totalFrameCount++;
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;

      if (totalMs > 16.666) {
        _jankFrameCount++;
      }

      _buildMsList.add(buildMs);
      _rasterMsList.add(rasterMs);
      _totalMsList.add(totalMs);

      if (_buildMsList.length > _maxFrameHistory) {
        _buildMsList.removeAt(0);
        _rasterMsList.removeAt(0);
        _totalMsList.removeAt(0);
      }
    }
    notifyListeners();
  }

  double _percentile(List<double> list, double p) {
    if (list.isEmpty) return 0.0;
    final sorted = List<double>.from(list)..sort();
    final index = (sorted.length * p).clamp(0, sorted.length - 1).toInt();
    return sorted[index];
  }

  double get frameBuildP50 => _percentile(_buildMsList, 0.50);
  double get frameBuildP95 => _percentile(_buildMsList, 0.95);
  double get frameBuildP99 => _percentile(_buildMsList, 0.99);

  double get frameRasterP50 => _percentile(_rasterMsList, 0.50);
  double get frameRasterP95 => _percentile(_rasterMsList, 0.95);
  double get frameRasterP99 => _percentile(_rasterMsList, 0.99);

  double get frameTotalP50 => _percentile(_totalMsList, 0.50);
  double get frameTotalP95 => _percentile(_totalMsList, 0.95);
  double get frameTotalP99 => _percentile(_totalMsList, 0.99);

  int get totalFrames => _totalFrameCount;
  int get jankFrames => _jankFrameCount;
  double get jankPercentage => _totalFrameCount == 0
      ? 0.0
      : (_jankFrameCount / _totalFrameCount) * 100.0;

  // --- Input Tracking ---
  int pointerUpCount = 0;
  int tapAcceptedCount = 0;
  int tapRejectedCount = 0;
  final Map<TapRejectedReason, int> rejectedReasons = {
    for (final reason in TapRejectedReason.values) reason: 0,
  };

  // Tap-to-first-motion tracking
  // Key: threadId, Value: pointerUp timestamp in milliseconds
  final Map<int, double> _pendingTapPointerUpMs = {};
  final List<double> _tapToMotionLatencies = [];

  void recordPointerUp() {
    pointerUpCount++;
    notifyListeners();
  }

  void recordTapAccepted(int threadId) {
    tapAcceptedCount++;
    final nowMs = DateTime.now().microsecondsSinceEpoch / 1000.0;
    _pendingTapPointerUpMs[threadId] = nowMs;
    _onTapRegistered();
    notifyListeners();
  }

  void recordTapRejected(TapRejectedReason reason) {
    tapRejectedCount++;
    rejectedReasons[reason] = (rejectedReasons[reason] ?? 0) + 1;
    _onTapRegistered();
    notifyListeners();
  }

  void recordFirstMotion(int threadId) {
    final pointerUpMs = _pendingTapPointerUpMs.remove(threadId);
    if (pointerUpMs != null) {
      final nowMs = DateTime.now().microsecondsSinceEpoch / 1000.0;
      final latency = nowMs - pointerUpMs;
      _tapToMotionLatencies.add(latency);
      if (_tapToMotionLatencies.length > 200) {
        _tapToMotionLatencies.removeAt(0);
      }
      notifyListeners();
    }
  }

  double get tapToMotionP50 => _percentile(_tapToMotionLatencies, 0.50);
  double get tapToMotionP95 => _percentile(_tapToMotionLatencies, 0.95);

  // --- Animation Health & Stuck Detection ---
  int exitingCount = 0;
  int bouncingCount = 0;
  double oldestRunningAnimationAgeMs = 0.0;
  final List<String> stuckErrors = [];
  int stuckCount = 0;

  void updateAnimationStats({
    required int exiting,
    required int bouncing,
    required double oldestAgeMs,
  }) {
    exitingCount = exiting;
    bouncingCount = bouncing;
    oldestRunningAnimationAgeMs = oldestAgeMs;
  }

  void reportStuckAnimation({
    required int threadId,
    required String state,
    required double ageMs,
    required double maxAllowedMs,
  }) {
    stuckCount++;
    final errorMsg =
        'STUCK ANIMATION: Thread $threadId in state $state exceeded age ($ageMs ms > $maxAllowedMs ms)';
    stuckErrors.add(errorMsg);
    if (stuckErrors.length > 50) stuckErrors.removeAt(0);
    debugLog(errorMsg);
    notifyListeners();
  }

  // --- Sound Tracking ---
  int soundRequested = 0;
  int soundStarted = 0;
  int soundFailed = 0;
  int soundInFlightVoices = 0;
  int soundPoolSize = 0;
  String? soundLastError;

  void updateSoundStats({
    required int requested,
    required int started,
    required int failed,
    required int inFlight,
    required int poolSize,
    String? lastError,
  }) {
    soundRequested = requested;
    soundStarted = started;
    soundFailed = failed;
    soundInFlightVoices = inFlight;
    soundPoolSize = poolSize;
    if (lastError != null) soundLastError = lastError;
    notifyListeners();
  }

  // --- Rebuild Tracking (Last 100 Taps) ---
  int totalScreenRebuilds = 0;
  int totalBoardRebuilds = 0;
  int totalHeaderRebuilds = 0;

  final List<_TapRebuildRecord> _rebuildHistory = [];
  _TapRebuildRecord? _currentTapRecord;

  void recordGameScreenRebuild() {
    totalScreenRebuilds++;
    if (_currentTapRecord != null) {
      _currentTapRecord!.screenRebuilds++;
    }
  }

  void recordBoardWidgetRebuild() {
    totalBoardRebuilds++;
    if (_currentTapRecord != null) {
      _currentTapRecord!.boardRebuilds++;
    }
  }

  void recordHeaderCounterRebuild() {
    totalHeaderRebuilds++;
    if (_currentTapRecord != null) {
      _currentTapRecord!.headerRebuilds++;
    }
  }

  void _onTapRegistered() {
    if (_currentTapRecord != null) {
      _rebuildHistory.add(_currentTapRecord!);
      if (_rebuildHistory.length > 100) {
        _rebuildHistory.removeAt(0);
      }
    }
    _currentTapRecord = _TapRebuildRecord();
  }

  int get screenRebuildsLast100 =>
      _rebuildHistory.fold(0, (acc, r) => acc + r.screenRebuilds);
  int get boardRebuildsLast100 =>
      _rebuildHistory.fold(0, (acc, r) => acc + r.boardRebuilds);
  int get headerRebuildsLast100 =>
      _rebuildHistory.fold(0, (acc, r) => acc + r.headerRebuilds);

  // --- Export Full Diagnostic Report ---
  String exportReport() {
    final sb = StringBuffer();
    sb.writeln('=== ArrowZ Diagnostic Report ===');
    sb.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    sb.writeln();
    sb.writeln('--- Frame Timing ---');
    sb.writeln('Total frames: $totalFrames');
    sb.writeln(
        'Jank frames (>16.7ms): $jankFrames (${jankPercentage.toStringAsFixed(1)}%)');
    sb.writeln(
        'Build ms: p50=${frameBuildP50.toStringAsFixed(2)}, p95=${frameBuildP95.toStringAsFixed(2)}, p99=${frameBuildP99.toStringAsFixed(2)}');
    sb.writeln(
        'Raster ms: p50=${frameRasterP50.toStringAsFixed(2)}, p95=${frameRasterP95.toStringAsFixed(2)}, p99=${frameRasterP99.toStringAsFixed(2)}');
    sb.writeln(
        'Total ms: p50=${frameTotalP50.toStringAsFixed(2)}, p95=${frameTotalP95.toStringAsFixed(2)}, p99=${frameTotalP99.toStringAsFixed(2)}');
    sb.writeln();
    sb.writeln('--- Input Tracking ---');
    sb.writeln('PointerUp count: $pointerUpCount');
    sb.writeln('Tap Accepted: $tapAcceptedCount');
    sb.writeln('Tap Rejected: $tapRejectedCount');
    final totalTaps = tapAcceptedCount + tapRejectedCount;
    final acceptRate =
        totalTaps == 0 ? 100.0 : (tapAcceptedCount / totalTaps) * 100.0;
    sb.writeln('Acceptance Rate: ${acceptRate.toStringAsFixed(1)}%');
    sb.writeln('Rejection Reasons:');
    for (final entry in rejectedReasons.entries) {
      sb.writeln('  - ${entry.key.name}: ${entry.value}');
    }
    sb.writeln(
        'Tap-to-First-Motion Latency: p50=${tapToMotionP50.toStringAsFixed(1)}ms, p95=${tapToMotionP95.toStringAsFixed(1)}ms (samples: ${_tapToMotionLatencies.length})');
    sb.writeln();
    sb.writeln('--- Animation Health ---');
    sb.writeln('Active Exiting: $exitingCount');
    sb.writeln('Active Bouncing: $bouncingCount');
    sb.writeln(
        'Oldest Animation Age: ${oldestRunningAnimationAgeMs.toStringAsFixed(1)} ms');
    sb.writeln('Stuck Detections: $stuckCount');
    if (stuckErrors.isNotEmpty) {
      sb.writeln('Recent Stuck Errors:');
      for (final err in stuckErrors.take(5)) {
        sb.writeln('  * $err');
      }
    }
    sb.writeln();
    sb.writeln('--- Audio Service ---');
    sb.writeln('Requested: $soundRequested');
    sb.writeln('Started: $soundStarted');
    sb.writeln('Failed: $soundFailed');
    sb.writeln('In-flight voices: $soundInFlightVoices');
    sb.writeln('Pool size: $soundPoolSize');
    if (soundLastError != null) {
      sb.writeln('Last Error: $soundLastError');
    }
    sb.writeln();
    sb.writeln('--- Rebuild Counters (last 100 taps) ---');
    sb.writeln('GameScreen rebuilds: $screenRebuildsLast100');
    sb.writeln('BoardWidget rebuilds: $boardRebuildsLast100');
    sb.writeln('HeaderCounter rebuilds: $headerRebuildsLast100');
    sb.writeln(
        'Lifetime totals: Screen=$totalScreenRebuilds, Board=$totalBoardRebuilds, Header=$totalHeaderRebuilds');
    sb.writeln('================================');
    return sb.toString();
  }

  void reset() {
    _buildMsList.clear();
    _rasterMsList.clear();
    _totalMsList.clear();
    _totalFrameCount = 0;
    _jankFrameCount = 0;
    pointerUpCount = 0;
    tapAcceptedCount = 0;
    tapRejectedCount = 0;
    for (final reason in TapRejectedReason.values) {
      rejectedReasons[reason] = 0;
    }
    _pendingTapPointerUpMs.clear();
    _tapToMotionLatencies.clear();
    exitingCount = 0;
    bouncingCount = 0;
    oldestRunningAnimationAgeMs = 0.0;
    stuckErrors.clear();
    stuckCount = 0;
    soundRequested = 0;
    soundStarted = 0;
    soundFailed = 0;
    soundInFlightVoices = 0;
    soundLastError = null;
    _rebuildHistory.clear();
    _currentTapRecord = null;
    notifyListeners();
  }
}

class _TapRebuildRecord {
  int screenRebuilds = 0;
  int boardRebuilds = 0;
  int headerRebuilds = 0;
}
