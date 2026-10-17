import 'package:arrowtapout/data/arrow_skin.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/component_tokens.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/game/board_painter.dart';
import 'package:arrowtapout/features/game/hit_tester.dart';
import 'package:arrowtapout/features/game/thread_animator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Interactive board view widget rendering the thread puzzle with lattice model and unified painter.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.level,
    this.activeIds = const {},
    this.getActiveIds,
    required this.animator,
    required this.onThreadTap,
    this.reduceMotion = false,
    this.interactive = true,
    this.arrowSkin = ArrowSkin.chevron,
    this.transformationController,
  });

  final Level level;
  final Set<int> activeIds;
  final Set<int> Function()? getActiveIds;
  final BoardAnimator animator;
  final ValueChanged<int> onThreadTap;
  final bool reduceMotion;
  final bool interactive;
  final ArrowSkin arrowSkin;
  final TransformationController? transformationController;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  late BoardHitTester _hitTester;
  TransformationController? _internalTransformController;
  TransformationController get _transformController =>
      widget.transformationController ??
      (_internalTransformController ??= TransformationController());

  final Map<int, (Offset pos, DateTime time)> _activePointers = {};
  double _lastCellSize = 0.0;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _hitTester = BoardHitTester(widget.level);
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed && mounted) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  @override
  void didUpdateWidget(covariant BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      oldWidget.transformationController?.removeListener(_onTransformChanged);
      _internalTransformController?.removeListener(_onTransformChanged);
      _transformController.addListener(_onTransformChanged);
    }
    if (oldWidget.level != widget.level) {
      _hitTester = BoardHitTester(widget.level);
      _transformController.value = Matrix4.identity();
      _lastCellSize = 0.0;
      _isZoomed = false;
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _internalTransformController?.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = (event.localPosition, DateTime.now());
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  Set<int> get _effectiveActiveIds =>
      widget.getActiveIds?.call() ?? widget.activeIds;

  void _handlePointerUp(
      PointerUpEvent event, double cellSize, double hitPadding) {
    Diagnostics.instance.recordPointerUp();
    final record = _activePointers.remove(event.pointer);
    if (record == null) {
      Diagnostics.instance.recordTapRejected(TapRejectedReason.other);
      return;
    }
    if (!widget.interactive) {
      Diagnostics.instance
          .recordTapRejected(TapRejectedReason.levelNotPlayable);
      return;
    }

    final (downPos, downTime) = record;
    final elapsedMs = DateTime.now().difference(downTime).inMilliseconds;
    final dist = (event.localPosition - downPos).distance;

    // Fast tap: moved < kTouchSlop * 1.5 and duration < 500ms
    if (dist > kTouchSlop * 1.5) {
      Diagnostics.instance.recordTapRejected(TapRejectedReason.slopExceeded);
      return;
    }
    if (elapsedMs >= 500) {
      Diagnostics.instance.recordTapRejected(TapRejectedReason.tooLong);
      return;
    }

    final currentActive = _effectiveActiveIds;
    final boardLocalPos = event.localPosition - Offset(hitPadding, hitPadding);
    final hitId = _hitTester.hitTest(
      localPosition: boardLocalPos,
      cellSize: cellSize,
      activeThreadIds: currentActive,
    );

    if (hitId == null) {
      Diagnostics.instance
          .recordTapRejected(TapRejectedReason.noThreadInTolerance);
      return;
    }

    if (!currentActive.contains(hitId)) {
      Diagnostics.instance
          .recordTapRejected(TapRejectedReason.threadAlreadyGone);
      return;
    }

    Diagnostics.instance.recordTapAccepted(hitId);
    widget.onThreadTap(hitId);
  }

  @override
  Widget build(BuildContext context) {
    Diagnostics.instance.recordBoardWidgetRebuild();
    final tokens = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = ComponentTokens.computeLatticeCellSize(
          screenWidth: constraints.maxWidth,
          boardRegionHeight: constraints.maxHeight,
          rows: widget.level.rows,
          cols: widget.level.cols,
          devicePixelRatio: dpr,
          isInnerContainer: false,
        );

        if (_lastCellSize != cellSize) {
          final wasInitialized = _lastCellSize > 0;
          _lastCellSize = cellSize;
          if (wasInitialized) {
            widget.animator.updateCellSize(cellSize);
          } else {
            widget.animator.setLevel(widget.level, cellSize);
          }
        }

        final boardW = (widget.level.cols - 1) * cellSize;
        final boardH = (widget.level.rows - 1) * cellSize;
        final hitPadding = (cellSize * 0.7).clamp(16.0, 26.0);

        final boardWidget = Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerCancel: _handlePointerCancel,
          onPointerUp: (event) => _handlePointerUp(event, cellSize, hitPadding),
          child: Container(
            width: boardW + hitPadding * 2,
            height: boardH + hitPadding * 2,
            padding: EdgeInsets.all(hitPadding),
            child: SizedBox(
              width: boardW,
              height: boardH,
              child: Semantics(
                label: 'Puzzle board',
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(boardW, boardH),
                    isComplex: true,
                    willChange: true,
                    painter: BoardPainter(
                      level: widget.level,
                      activeIds: widget.activeIds,
                      getActiveIds: widget.getActiveIds,
                      cellSize: cellSize,
                      tokens: tokens,
                      animator: widget.animator,
                      reduceMotion: widget.reduceMotion,
                      arrowSkin: widget.arrowSkin,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        return InteractiveViewer(
          transformationController: _transformController,
          minScale: 1.0,
          maxScale: 2.5,
          panEnabled: _isZoomed,
          scaleEnabled: true,
          boundaryMargin:
              _isZoomed ? const EdgeInsets.all(32.0) : EdgeInsets.zero,
          alignment: Alignment.center,
          onInteractionStart: (details) {
            if (details.pointerCount > 1) {
              _activePointers.clear();
            }
          },
          onInteractionUpdate: (details) {
            if (details.pointerCount > 1) {
              _activePointers.clear();
            }
          },
          onInteractionEnd: (details) {
            _activePointers.clear();
          },
          child: Center(
            child: boardWidget,
          ),
        );
      },
    );
  }
}
