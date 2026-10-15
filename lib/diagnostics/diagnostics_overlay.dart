import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dev-only Diagnostics Overlay.
///
/// Fully compiled out / no-op in release builds.
class DiagnosticsOverlay extends StatefulWidget {
  const DiagnosticsOverlay({
    super.key,
    required this.child,
    this.isVisible = false,
    this.onClose,
  });

  final Widget child;
  final bool isVisible;
  final VoidCallback? onClose;

  @override
  State<DiagnosticsOverlay> createState() => _DiagnosticsOverlayState();
}

class _DiagnosticsOverlayState extends State<DiagnosticsOverlay> {
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        if (widget.isVisible)
          Positioned(
            left: 8.0,
            right: 8.0,
            top: MediaQuery.paddingOf(context).top + 8.0,
            child: Material(
              color: Colors.transparent,
              child: AnimatedBuilder(
                animation: Diagnostics.instance,
                builder: (context, _) => _buildOverlayContent(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverlayContent(BuildContext context) {
    final d = Diagnostics.instance;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE614181E),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF384353), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  color: Color(0xFF64D2FF), size: 16.0),
              const SizedBox(width: 6.0),
              const Text(
                'DIAGNOSTICS (DEV/PROFILE)',
                style: TextStyle(
                  color: Color(0xFF64D2FF),
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _minimized = !_minimized),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    _minimized ? Icons.expand_more : Icons.expand_less,
                    color: Colors.white70,
                    size: 18.0,
                  ),
                ),
              ),
              const SizedBox(width: 4.0),
              InkWell(
                onTap: () async {
                  final text = d.exportReport();
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostics report copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.copy, color: Colors.white70, size: 16.0),
                ),
              ),
              const SizedBox(width: 4.0),
              InkWell(
                onTap: () => d.reset(),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.refresh, color: Colors.white70, size: 16.0),
                ),
              ),
              const SizedBox(width: 4.0),
              InkWell(
                onTap: widget.onClose,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, color: Colors.white70, size: 16.0),
                ),
              ),
            ],
          ),

          if (!_minimized) ...[
            const SizedBox(height: 6.0),
            const Divider(color: Color(0xFF2C3542), height: 1.0),
            const SizedBox(height: 6.0),

            // Performance & Frame Timing
            _metricRow(
              'Frames (Total/Jank)',
              '${d.totalFrames} / ${d.jankFrames} (${d.jankPercentage.toStringAsFixed(1)}%)',
              isWarn: d.jankPercentage > 1.0,
            ),
            _metricRow(
              'Total ms (p50/p95/p99)',
              '${d.frameTotalP50.toStringAsFixed(1)} / ${d.frameTotalP95.toStringAsFixed(1)} / ${d.frameTotalP99.toStringAsFixed(1)}',
              isWarn: d.frameTotalP95 > 8.0,
            ),
            _metricRow(
              'Build/Raster p95',
              'B:${d.frameBuildP95.toStringAsFixed(1)}ms | R:${d.frameRasterP95.toStringAsFixed(1)}ms',
            ),

            const SizedBox(height: 4.0),
            const Divider(color: Color(0xFF2C3542), height: 1.0),
            const SizedBox(height: 4.0),

            // Input Stats
            _metricRow(
              'Taps (Up/Acc/Rej)',
              '${d.pointerUpCount} / ${d.tapAcceptedCount} / ${d.tapRejectedCount}',
              isWarn: d.tapRejectedCount > 0,
            ),
            _metricRow(
              'Tap->Motion (p50/p95)',
              '${d.tapToMotionP50.toStringAsFixed(1)}ms / ${d.tapToMotionP95.toStringAsFixed(1)}ms',
              isWarn: d.tapToMotionP95 > 25.0,
            ),
            if (d.tapRejectedCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                child: Text(
                  'Rejected: ${d.rejectedReasons.entries.where((e) => e.value > 0).map((e) => "${e.key.name}:${e.value}").join(", ")}',
                  style: const TextStyle(
                      color: Color(0xFFFF9500), fontSize: 9.5),
                ),
              ),

            const SizedBox(height: 4.0),
            const Divider(color: Color(0xFF2C3542), height: 1.0),
            const SizedBox(height: 4.0),

            // Animation Health
            _metricRow(
              'Animations (Exit/Bnc/Stuck)',
              'E:${d.exitingCount} | B:${d.bouncingCount} | S:${d.stuckCount}',
              isWarn: d.stuckCount > 0,
            ),
            _metricRow(
              'Oldest Anim Age',
              '${d.oldestRunningAnimationAgeMs.toStringAsFixed(0)} ms',
            ),

            const SizedBox(height: 4.0),
            const Divider(color: Color(0xFF2C3542), height: 1.0),
            const SizedBox(height: 4.0),

            // Sound Stats
            _metricRow(
              'Sound (Req/Start/Fail)',
              '${d.soundRequested} / ${d.soundStarted} / ${d.soundFailed}',
              isWarn: d.soundFailed > 0 || d.soundStarted < d.soundRequested,
            ),
            _metricRow(
              'Voices / Pool',
              'Active:${d.soundInFlightVoices} | Pool:${d.soundPoolSize}',
            ),
            if (d.soundLastError != null)
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                child: Text(
                  'Err: ${d.soundLastError}',
                  style: const TextStyle(
                      color: Color(0xFFFF453A), fontSize: 9.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 4.0),
            const Divider(color: Color(0xFF2C3542), height: 1.0),
            const SizedBox(height: 4.0),

            // Rebuilds (Last 100 Taps)
            _metricRow(
              'Rebuilds/100 taps (Scr/Brd/Hdr)',
              'S:${d.screenRebuildsLast100} | B:${d.boardRebuildsLast100} | H:${d.headerRebuildsLast100}',
              isWarn: d.screenRebuildsLast100 > 0 || d.boardRebuildsLast100 > 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, {bool isWarn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFA0AAB6),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isWarn ? const Color(0xFFFF453A) : const Color(0xFFE5E9F0),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
