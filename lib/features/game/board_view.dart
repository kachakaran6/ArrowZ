import 'dart:math' as math;

import 'package:arrowtapout/data/arrow_skin.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/component_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
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
  });

  final Level level;
  final Set<int> activeIds;
  final Set<int> Function()? getActiveIds;
  final BoardAnimator animator;
  final ValueChanged<int> onThreadTap;
  final bool reduceMotion;
  final bool interactive;
  final ArrowSkin arrowSkin;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late BoardHitTester _hitTester;
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;

  final Map<int, (Offset pos, DateTime time)> _activePointers = {};
  double _lastCellSize = 0.0;
  bool _isZoomed = false;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _hitTester = BoardHitTester(widget.level);
    _transformController.addListener(_onTransformChanged);
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if ((zoomed != _isZoomed || (_currentScale - scale).abs() > 0.04) &&
        mounted) {
      setState(() {
        _isZoomed = zoomed;
        _currentScale = scale;
      });
    }
  }

  void _animateToScale(double targetScale,
      {Offset? focalPoint, Size? viewportSize}) {
    final size = viewportSize ?? const Size(400, 600);
    final center = focalPoint ?? Offset(size.width / 2, size.height / 2);

    final Matrix4 endMatrix = Matrix4.identity();
    if (targetScale > 1.02) {
      endMatrix
        ..setEntry(0, 0, targetScale)
        ..setEntry(1, 1, targetScale)
        ..setEntry(0, 3, center.dx * (1.0 - targetScale))
        ..setEntry(1, 3, center.dy * (1.0 - targetScale));
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimController,
      curve: Curves.easeOutCubic,
    ));
    _zoomAnimController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _hitTester = BoardHitTester(widget.level);
      _transformController.value = Matrix4.identity();
      _lastCellSize = 0.0;
      _isZoomed = false;
      _currentScale = 1.0;
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _zoomAnimController.dispose();
    _transformController.dispose();
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

  Widget _buildZoomControls(
      AppTokens tokens, bool isBiggerLevel, Size viewportSize) {
    if (!isBiggerLevel) return const SizedBox.shrink();

    return Positioned(
      right: Primitives.space16,
      bottom: Primitives.space12,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: tokens.threadFaint.withValues(alpha: 0.9),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.ink.withValues(alpha: 0.08),
                blurRadius: 10.0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _isZoomed
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 20.0),
                      color: tokens.ink,
                      constraints: const BoxConstraints(
                          minWidth: 36.0, minHeight: 36.0),
                      padding: EdgeInsets.zero,
                      tooltip: 'Zoom out',
                      onPressed: () {
                        final newScale = math.max(1.0, _currentScale - 0.35);
                        _animateToScale(newScale, viewportSize: viewportSize);
                      },
                    ),
                    InkWell(
                      onTap: () =>
                          _animateToScale(1.0, viewportSize: viewportSize),
                      borderRadius: BorderRadius.circular(12.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(_currentScale * 100).round()}%',
                              style: tokens.typography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: tokens.accent,
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            Icon(Icons.fit_screen_rounded,
                                size: 16.0, color: tokens.accent),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 20.0),
                      color: tokens.ink,
                      constraints: const BoxConstraints(
                          minWidth: 36.0, minHeight: 36.0),
                      padding: EdgeInsets.zero,
                      tooltip: 'Zoom in',
                      onPressed: () {
                        final newScale = math.min(2.8, _currentScale + 0.35);
                        _animateToScale(newScale, viewportSize: viewportSize);
                      },
                    ),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.zoom_in_rounded, size: 22.0),
                  color: tokens.ink,
                  constraints: const BoxConstraints(
                      minWidth: 40.0, minHeight: 40.0),
                  padding: EdgeInsets.zero,
                  tooltip: 'Zoom & Resize Board',
                  onPressed: () {
                    _animateToScale(1.65, viewportSize: viewportSize);
                  },
                ),
        ),
      ),
    );
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
        final isBiggerLevel = widget.level.cols >= 9 ||
            widget.level.rows >= 9 ||
            cellSize < ComponentTokens.zoomThresholdCellSize;

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

        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        final interactiveBoard = GestureDetector(
          onDoubleTapDown: (details) {
            if (_isZoomed) {
              _animateToScale(1.0, viewportSize: viewportSize);
            } else {
              _animateToScale(1.75,
                  focalPoint: details.localPosition,
                  viewportSize: viewportSize);
            }
          },
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.95,
            maxScale: 2.8,
            panEnabled: _isZoomed,
            scaleEnabled: isBiggerLevel,
            boundaryMargin:
                _isZoomed ? const EdgeInsets.all(40.0) : EdgeInsets.zero,
            alignment: Alignment.center,
            onInteractionStart: (details) {
              if (details.pointerCount > 1) {
                _activePointers.clear();
              }
            },
            child: Center(
              child: boardWidget,
            ),
          ),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: interactiveBoard),
            _buildZoomControls(tokens, isBiggerLevel, viewportSize),
          ],
        );
      },
    );
  }
}
