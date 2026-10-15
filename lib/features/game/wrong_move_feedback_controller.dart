import 'dart:async';

import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Event emitted when an arrow move is blocked by another arrow.
@immutable
class WrongMoveEvent {
  const WrongMoveEvent({
    required this.threadId,
    required this.dir,
    required this.timestampMs,
    required this.reduceMotion,
  });

  final int threadId;
  final Dir dir;
  final double timestampMs;
  final bool reduceMotion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WrongMoveEvent &&
          runtimeType == other.runtimeType &&
          threadId == other.threadId &&
          dir == other.dir &&
          timestampMs == other.timestampMs &&
          reduceMotion == other.reduceMotion;

  @override
  int get hashCode => Object.hash(threadId, dir, timestampMs, reduceMotion);
}

/// Focused controller coordinating wrong-move feedback:
/// - Strong tactile haptic feedback
/// - Sound effect playback
/// - Controlled shake animation
/// - Temporary red highlight
/// - Accessible semantics announcements
///
/// Decoupled from collision rules, heart-life counts, and level progression.
class WrongMoveFeedbackController {
  WrongMoveFeedbackController({
    required this.haptics,
    required this.audio,
    required this.animator,
    this.announceBlocked,
    this.hapticRateLimitMs = 100.0,
    this.audioRateLimitMs = 100.0,
    this.semanticsRateLimitMs = 800.0,
  });

  final HapticsService haptics;
  final AudioService audio;
  final BoardAnimator animator;
  final void Function(String message)? announceBlocked;
  final double hapticRateLimitMs;
  final double audioRateLimitMs;
  final double semanticsRateLimitMs;

  final List<void Function(WrongMoveEvent)> _listeners = [];

  double _lastHapticTimeMs = 0.0;
  double _lastSemanticsTimeMs = 0.0;

  int _eventCount = 0;
  int get eventCount => _eventCount;

  void addListener(void Function(WrongMoveEvent) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(WrongMoveEvent) listener) {
    _listeners.remove(listener);
  }

  /// Handles a confirmed blocked arrow attempt, triggering coordinated feedback immediately.
  void handleWrongMove({
    required int threadId,
    required Dir dir,
    required bool reduceMotion,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
    final event = WrongMoveEvent(
      threadId: threadId,
      dir: dir,
      timestampMs: nowMs,
      reduceMotion: reduceMotion,
    );

    _eventCount++;

    // 1. Emit event to all registered listeners.
    for (final listener in List.of(_listeners)) {
      try {
        listener(event);
      } catch (e) {
        debugPrint('WrongMoveFeedbackController listener error: $e');
      }
    }

    // 2. Dispatch strong tactile haptic feedback immediately (non-blocking).
    if (nowMs - _lastHapticTimeMs >= hapticRateLimitMs) {
      _lastHapticTimeMs = nowMs;
      unawaited(haptics.heavy());
    }

    // 3. Dispatch audio error effect immediately on EVERY tap (non-blocking).
    audio.playBlock();

    // 4. Start visual shake and red highlight presentation on the selected arrow.
    animator.triggerWrongMove(
      threadId: threadId,
      dir: dir,
      reduceMotion: reduceMotion,
    );

    // 5. Accessible screen-reader announcement (rate-limited).
    if (nowMs - _lastSemanticsTimeMs >= semanticsRateLimitMs) {
      _lastSemanticsTimeMs = nowMs;
      try {
        if (announceBlocked != null) {
          announceBlocked!('Blocked arrow');
        } else {
          // ignore: deprecated_member_use
          SemanticsService.announce('Blocked arrow', TextDirection.ltr);
        }
      } catch (_) {}
    }
  }

  /// Cancels any active wrong-move presentation feedback (e.g. on restart or level exit).
  void cancel() {
    animator.cancelWrongMoves();
  }

  /// Disposes controller resources and cancels ongoing animations.
  void dispose() {
    _listeners.clear();
    cancel();
  }
}
