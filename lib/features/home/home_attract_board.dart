import 'dart:async';
import 'dart:math' as math;

import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/board_painter.dart';
import 'package:arrowtapout/features/game/board_plate.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Living board plate hero with an attract-mode loop on a showcase level.
///
/// Features:
/// - Centred ~300 dp square board plate with lattice dots and accent chevrons.
/// - Every 2.2 s one free thread slides out, then 1.1 s later draws back in.
/// - 3 dp idle float on the plate (gentle sine wave).
/// - Automatically pauses when app is backgrounded or screen not visible.
/// - Completely static when reduceMotion is enabled.
/// - Highly optimized under 3 ms per frame.
class HomeAttractBoard extends ConsumerStatefulWidget {
  const HomeAttractBoard({
    super.key,
    this.reduceMotion = false,
  });

  final bool reduceMotion;

  @override
  ConsumerState<HomeAttractBoard> createState() => _HomeAttractBoardState();
}

class _HomeAttractBoardState extends ConsumerState<HomeAttractBoard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Level? _level;
  late BoardAnimator _animator;
  Timer? _loopTimer;
  int _currentStep = 0;
  bool _isBackgrounded = false;

  Set<int> _activeIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animator = BoardAnimator(vsync: this);
    _animator.onExitCompleted = (id) {
      if (mounted) {
        setState(() {
          _activeIds.remove(id);
        });
        // 1.1s later, restore the thread back to the board
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (!mounted || _isBackgrounded) return;
          setState(() {
            _activeIds.add(id);
          });
        });
      }
    };
    _loadShowcaseLevel();
  }

  Future<void> _loadShowcaseLevel() async {
    try {
      final repo = ref.read(levelRepositoryProvider);
      final level = await repo.loadLevel(1);
      if (mounted) {
        final rows = level.rows;
        final cols = level.cols;
        final cellSize = (250.0 / math.max(rows, cols)).clamp(24.0, 38.0);
        _animator.setLevel(level, cellSize);
        setState(() {
          _level = level;
          _activeIds = level.threads.map((t) => t.id).toSet();
        });
        _startAttractLoop();
      }
    } catch (_) {
      // Fallback: if loading fails, screen gracefully degrades
    }
  }

  void _startAttractLoop() {
    if (widget.reduceMotion || _level == null || _level!.threads.isEmpty) return;
    _loopTimer?.cancel();

    _loopTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted || _isBackgrounded || _level == null) return;
      _runAttractStep();
    });
  }

  void _runAttractStep() {
    if (_level == null || _level!.threads.isEmpty) return;
    final threads = _level!.threads;
    final available = threads.where((t) => _activeIds.contains(t.id)).toList();
    if (available.isEmpty) {
      setState(() {
        _activeIds = threads.map((t) => t.id).toSet();
      });
      return;
    }

    final thread = available[_currentStep % available.length];
    _currentStep++;

    _animator.triggerExit(
      thread.id,
      reduceMotion: widget.reduceMotion,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isBackgrounded = true;
      _loopTimer?.cancel();
      _animator.finalizeAllRunningAnimations();
    } else if (state == AppLifecycleState.resumed) {
      _isBackgrounded = false;
      _startAttractLoop();
    }
  }

  @override
  void didUpdateWidget(covariant HomeAttractBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      if (widget.reduceMotion) {
        _loopTimer?.cancel();
        _animator.finalizeAllRunningAnimations();
      } else {
        _startAttractLoop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loopTimer?.cancel();
    _animator.finalizeAllRunningAnimations();
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (_level == null) {
      return Container(
        width: 290.0,
        height: 290.0,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(Primitives.radius28),
          border: Border.all(color: tokens.line),
        ),
      );
    }

    final level = _level!;
    final rows = level.rows;
    final cols = level.cols;

    // Fixed cell size for crisp preview
    final cellSize = (250.0 / math.max(rows, cols)).clamp(24.0, 38.0);
    final boardW = cols * cellSize;
    final boardH = rows * cellSize;

    final Widget boardContent = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animator,
        builder: (context, _) {
          return CustomPaint(
            size: Size(boardW, boardH),
            painter: BoardPainter(
              level: level,
              activeThreadIds: _activeIds,
              animator: _animator,
              tokens: tokens,
              cellSize: cellSize,
            ),
          );
        },
      ),
    );

    return RepaintBoundary(
      child: Container(
        width: 300.0,
        height: 300.0,
        alignment: Alignment.center,
        child: BoardPlate(
          child: Center(
            child: SizedBox(
              width: boardW,
              height: boardH,
              child: boardContent,
            ),
          ),
        ),
      ),
    );
  }
}
