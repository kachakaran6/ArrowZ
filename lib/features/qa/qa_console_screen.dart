import 'dart:async';

import 'package:arrowtapout/core/qa_config.dart';
import 'package:arrowtapout/data/chapter_data.dart';
import 'package:arrowtapout/data/level_repository.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/data/snapshot_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/features/qa/qa_session.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Production-grade hidden QA Testing Console for ArrowZ.
///
/// Enables authorized game testers and developers to:
/// - Jump directly to any valid puzzle level (1..500)
/// - Validate puzzle configurations and game engine loading
/// - Isolate testing progression from legitimate player saves
/// - Inspect level definitions, geometry, and chapter groupings
/// - Suppress animation delays for high-throughput testing
/// - Reset test overrides and return cleanly to regular gameplay
class QaConsoleScreen extends ConsumerStatefulWidget {
  const QaConsoleScreen({super.key});

  @override
  ConsumerState<QaConsoleScreen> createState() => _QaConsoleScreenState();
}

class _QaConsoleScreenState extends ConsumerState<QaConsoleScreen> {
  final TextEditingController _levelInputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _levelInputFocus = FocusNode();

  String _appVersion = '1.0.0';
  int _totalLevels = 500;
  int _selectedChapter = 0; // 0 = All Chapters
  String _searchQuery = '';
  String? _validationError;
  bool _isLaunching = false;
  Level? _inspectedLevel;
  bool _isLoadingInspectedLevel = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _levelInputController.addListener(_onInputChanged);
    _searchController.addListener(_onSearchChanged);
  }

  void _onInputChanged() {
    if (_validationError != null) {
      setState(() {
        _validationError = null;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadMetadata() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {
      // Fallback to default
    }

    try {
      final total =
          await ref.read(levelRepositoryProvider).getTotalLevelCount();
      if (mounted) {
        setState(() {
          _totalLevels = total;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _totalLevels = ref.read(levelRepositoryProvider).cachedTotalLevels;
        });
      }
    }

    final qaState = ref.read(qaSessionProvider);
    final targetId =
        qaState.activeLevelId ?? ref.read(progressProvider).highestUnlocked;
    _levelInputController.text = targetId.toString();
    unawaited(_inspectLevel(targetId));
  }

  Future<void> _inspectLevel(int levelId) async {
    if (levelId < 1 || levelId > _totalLevels) return;
    setState(() {
      _isLoadingInspectedLevel = true;
    });

    final level = await ref.read(levelRepositoryProvider).tryLoadLevel(levelId);
    if (mounted) {
      setState(() {
        _inspectedLevel = level;
        _isLoadingInspectedLevel = false;
      });
    }
  }

  @override
  void dispose() {
    _levelInputController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _levelInputFocus.dispose();
    super.dispose();
  }

  Future<void> _launchLevel(int levelId) async {
    if (_isLaunching) return;

    unawaited(ref.read(hapticsServiceProvider).selection());
    final total = _totalLevels;

    if (levelId < 1 || levelId > total) {
      setState(() {
        _validationError =
            'Level $levelId is out of bounds (valid range: 1..$total).';
      });
      return;
    }

    setState(() {
      _isLaunching = true;
      _validationError = null;
    });

    try {
      // Validate that the level definition actually exists and loads cleanly
      final level =
          await ref.read(levelRepositoryProvider).tryLoadLevel(levelId);
      if (level == null) {
        if (mounted) {
          setState(() {
            _validationError =
                'Level $levelId definition could not be decoded or loaded.';
            _isLaunching = false;
          });
        }
        return;
      }

      // Initialize QA testing session for this level
      final currentProgress = ref.read(progressProvider);
      ref.read(qaSessionProvider.notifier).startSession(
            levelId: levelId,
            currentProgress: currentProgress,
          );

      if (mounted) {
        // Navigate to the validated level in test mode
        unawaited(context.push(Routes.play(levelId)).then((_) {
          if (mounted) {
            setState(() {
              _isLaunching = false;
            });
            _loadMetadata();
          }
        }));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Failed to launch level $levelId: $e';
          _isLaunching = false;
        });
      }
    }
  }

  void _onLaunchFromInput() {
    final rawText = _levelInputController.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _validationError = 'Please enter a level number.';
      });
      return;
    }

    final parsed = int.tryParse(rawText);
    if (parsed == null) {
      setState(() {
        _validationError = 'Invalid numeric input.';
      });
      return;
    }

    if (parsed < 1) {
      setState(() {
        _validationError = 'Level number must be at least 1.';
      });
      return;
    }

    if (parsed > _totalLevels) {
      setState(() {
        _validationError =
            'Level $parsed exceeds maximum available levels ($_totalLevels).';
      });
      return;
    }

    _launchLevel(parsed);
  }

  void _clearQaOverrides() {
    unawaited(ref.read(hapticsServiceProvider).medium());
    ref.read(qaSessionProvider.notifier).clearOverrides();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'QA testing session overrides cleared. Regular progression restored.',
          style: TextStyle(fontFamily: Primitives.fontUi),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {});
  }

  void _restartCurrentPuzzleState() {
    unawaited(ref.read(hapticsServiceProvider).selection());
    ref.read(snapshotRepositoryProvider).clearSnapshot();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Temporary in-memory puzzle state reset to clean initial state.',
          style: TextStyle(fontFamily: Primitives.fontUi),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyDiagnosticsToClipboard() {
    if (_inspectedLevel == null) return;
    unawaited(ref.read(hapticsServiceProvider).selection());
    final l = _inspectedLevel!;
    final diag = StringBuffer()
      ..writeln('ArrowZ Diagnostic Info')
      ..writeln('App Version: $_appVersion')
      ..writeln(
          'Build Mode: ${kDebugMode ? "Debug" : (kProfileMode ? "Profile" : "Release")}')
      ..writeln('Level: ${l.id}')
      ..writeln('Chapter: ${l.chapter}')
      ..writeln('Grid: ${l.rows} rows x ${l.cols} cols')
      ..writeln('Threads: ${l.threads.length}')
      ..writeln('Deflectors: ${l.deflectors.length}')
      ..writeln('Par: ${l.par}')
      ..writeln('Shape: ${l.shape}');

    Clipboard.setData(ClipboardData(text: diag.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Level diagnostic information copied to clipboard.',
          style: TextStyle(fontFamily: Primitives.fontUi),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = ref.watch(progressProvider);
    final qaSession = ref.watch(qaSessionProvider);

    const buildModeStr =
        kDebugMode ? 'Debug' : (kProfileMode ? 'Profile' : 'Release');

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              children: [
                Text(
                  'ArrowZ QA Console',
                  style: tokens.typography.title,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.0),
                    border: Border.all(color: tokens.accent, width: 1.0),
                  ),
                  child: Text(
                    kDebugMode ? 'DEBUG' : 'INTERNAL TEST',
                    style: TextStyle(
                      fontFamily: Primitives.fontUi,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                      color: tokens.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Internal Game Testing Tools',
              style: tokens.typography.caption.copyWith(
                color: tokens.inkMuted,
                fontSize: 11.0,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.ink),
          tooltip: 'Back to Lobby',
          onPressed: () {
            unawaited(ref.read(hapticsServiceProvider).selection());
            context.go(Routes.home);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: tokens.ink),
            tooltip: 'Refresh Metadata',
            onPressed: _loadMetadata,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: Primitives.space20,
            vertical: Primitives.space16,
          ),
          children: [
            // A. ENVIRONMENT OVERVIEW
            _buildSectionHeader('A. Environment Overview', tokens),
            _buildEnvironmentCard(
              tokens: tokens,
              buildMode: buildModeStr,
              progress: progress,
              qaSession: qaSession,
            ),

            const SizedBox(height: Primitives.space24),

            // B. QUICK ACTIONS
            _buildSectionHeader('B. Quick Actions', tokens),
            _buildQuickActionsCard(tokens, qaSession),

            const SizedBox(height: Primitives.space24),

            // C. LEVEL NAVIGATION & DIRECT ENTRY
            _buildSectionHeader('C. Level Navigation', tokens),
            _buildLevelNavigationCard(tokens, progress, qaSession),

            const SizedBox(height: Primitives.space24),

            // D. PUZZLE DEBUG & METADATA
            _buildSectionHeader('D. Level Diagnostics & Engine State', tokens),
            _buildDiagnosticsCard(tokens, qaSession),

            const SizedBox(height: Primitives.space24),

            // E. LEVEL BROWSER
            _buildSectionHeader('E. Level Browser (1..$_totalLevels)', tokens),
            _buildLevelBrowser(tokens, progress, qaSession),

            const SizedBox(height: Primitives.space32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: tokens.typography.label.copyWith(
          color: tokens.inkMuted,
          fontSize: 13.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEnvironmentCard({
    required AppTokens tokens,
    required String buildMode,
    required ProgressState progress,
    required QaSessionState qaSession,
  }) {
    final playerChapter = ((progress.highestUnlocked - 1) ~/ 20) + 1;
    final chName = (playerChapter >= 1 && playerChapter <= allChapters.length)
        ? allChapters[playerChapter - 1].name
        : 'Chapter $playerChapter';

    return Card(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Primitives.radiusCard),
        side: BorderSide(color: tokens.threadFaint, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Primitives.space16),
        child: Column(
          children: [
            _buildKeyValueRow('App Version', _appVersion, tokens),
            Divider(color: tokens.threadFaint, height: 16.0),
            _buildKeyValueRow('Build Mode', buildMode, tokens),
            Divider(color: tokens.threadFaint, height: 16.0),
            _buildKeyValueRow(
              'QA Tooling Access',
              QaConfig.isQaAvailable ? 'Authorized & Active' : 'Disabled',
              tokens,
              valueColor: tokens.accent,
            ),
            Divider(color: tokens.threadFaint, height: 16.0),
            _buildKeyValueRow(
              'Total Available Levels',
              '$_totalLevels (25 Chapters)',
              tokens,
            ),
            Divider(color: tokens.threadFaint, height: 16.0),
            _buildKeyValueRow(
              'Normal Player Unlocked',
              'Level ${progress.highestUnlocked} ($chName)',
              tokens,
            ),
            Divider(color: tokens.threadFaint, height: 16.0),
            _buildKeyValueRow(
              'Testing Session Status',
              qaSession.isActive
                  ? 'Active: Testing Level ${qaSession.activeLevelId} (${qaSession.completedQaLevels.length} cleared)'
                  : 'Inactive (Normal Progression)',
              tokens,
              valueColor: qaSession.isActive ? tokens.accent : tokens.inkMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValueRow(
    String key,
    String value,
    AppTokens tokens, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            key,
            style: tokens.typography.caption.copyWith(color: tokens.inkMuted),
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: tokens.typography.body.copyWith(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: valueColor ?? tokens.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard(AppTokens tokens, QaSessionState qaSession) {
    return Card(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Primitives.radiusCard),
        side: BorderSide(color: tokens.threadFaint, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Primitives.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Primitives.space8,
              runSpacing: Primitives.space8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.rocket_launch_rounded, size: 16.0),
                  label: const Text('Jump to Level'),
                  backgroundColor: tokens.surfaceRaised,
                  side: BorderSide(color: tokens.threadFaint),
                  labelStyle: tokens.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                  onPressed: () {
                    _levelInputFocus.requestFocus();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.grid_view_rounded, size: 16.0),
                  label: const Text('Browse All Levels'),
                  backgroundColor: tokens.surfaceRaised,
                  side: BorderSide(color: tokens.threadFaint),
                  labelStyle: tokens.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                  onPressed: () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent * 0.7,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.restart_alt_rounded, size: 16.0),
                  label: const Text('Reset Puzzle State'),
                  backgroundColor: tokens.surfaceRaised,
                  side: BorderSide(color: tokens.threadFaint),
                  labelStyle: tokens.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                  onPressed: _restartCurrentPuzzleState,
                ),
                ActionChip(
                  avatar: const Icon(Icons.home_rounded, size: 16.0),
                  label: const Text('Return to Lobby'),
                  backgroundColor: tokens.surfaceRaised,
                  side: BorderSide(color: tokens.threadFaint),
                  labelStyle: tokens.typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                  onPressed: () {
                    context.go(Routes.home);
                  },
                ),
              ],
            ),
            if (qaSession.isActive) ...[
              const SizedBox(height: Primitives.space12),
              Divider(color: tokens.threadFaint, height: 1.0),
              const SizedBox(height: Primitives.space12),
              OutlinedButton.icon(
                icon: Icon(Icons.cancel_outlined,
                    color: tokens.danger, size: 18.0),
                label: Text(
                  'Clear QA Session Overrides (Restore Normal Progress)',
                  style: tokens.typography.label.copyWith(color: tokens.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tokens.danger.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(Primitives.radiusButton),
                  ),
                ),
                onPressed: _clearQaOverrides,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLevelNavigationCard(
    AppTokens tokens,
    ProgressState progress,
    QaSessionState qaSession,
  ) {
    return Card(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Primitives.radiusCard),
        side: BorderSide(color: tokens.threadFaint, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Primitives.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Direct Level Launch',
              style:
                  tokens.typography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Primitives.space4),
            Text(
              'Enter any valid level ID (1..$_totalLevels). Progression locking will be bypassed safely in test mode.',
              style: tokens.typography.caption.copyWith(color: tokens.inkMuted),
            ),
            const SizedBox(height: Primitives.space16),

            // Input Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _levelInputController,
                    focusNode: _levelInputFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Level Number',
                      hintText: 'e.g. 45',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      suffixIcon: _levelInputController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18.0),
                              onPressed: () {
                                _levelInputController.clear();
                                setState(() {
                                  _validationError = null;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                        borderSide: BorderSide(color: tokens.threadFaint),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                        borderSide:
                            BorderSide(color: tokens.accent, width: 2.0),
                      ),
                      errorText: _validationError,
                    ),
                    onSubmitted: (_) => _onLaunchFromInput(),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null &&
                          parsed >= 1 &&
                          parsed <= _totalLevels) {
                        _inspectLevel(parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: Primitives.space12),
                SizedBox(
                  height: 48.0,
                  child: FilledButton.icon(
                    icon: _isLaunching
                        ? const SizedBox(
                            width: 16.0,
                            height: 16.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Launch'),
                    style: FilledButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: tokens.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                      ),
                    ),
                    onPressed: _isLaunching ? null : _onLaunchFromInput,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Primitives.space16),
            Divider(color: tokens.threadFaint, height: 1.0),
            const SizedBox(height: Primitives.space12),

            // Quick Jump Presets
            Text(
              'Quick Jump Presets:',
              style: tokens.typography.caption
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Primitives.space8),
            Wrap(
              spacing: Primitives.space8,
              runSpacing: Primitives.space8,
              children: [
                _buildQuickJumpButton('First (1)', 1, tokens),
                _buildQuickJumpButton(
                  'Prev (${(progress.highestUnlocked - 1).clamp(1, _totalLevels)})',
                  (progress.highestUnlocked - 1).clamp(1, _totalLevels),
                  tokens,
                ),
                _buildQuickJumpButton(
                  'Player Highest (${progress.highestUnlocked})',
                  progress.highestUnlocked,
                  tokens,
                ),
                _buildQuickJumpButton(
                  'Next (${(progress.highestUnlocked + 1).clamp(1, _totalLevels)})',
                  (progress.highestUnlocked + 1).clamp(1, _totalLevels),
                  tokens,
                ),
                _buildQuickJumpButton(
                    'Last ($_totalLevels)', _totalLevels, tokens),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickJumpButton(String label, int targetId, AppTokens tokens) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.ink,
        side: BorderSide(color: tokens.threadFaint),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Primitives.radiusButton),
        ),
      ),
      onPressed: () {
        _levelInputController.text = targetId.toString();
        _inspectLevel(targetId);
        _launchLevel(targetId);
      },
      child: Text(label, style: const TextStyle(fontSize: 12.0)),
    );
  }

  Widget _buildDiagnosticsCard(AppTokens tokens, QaSessionState qaSession) {
    return Card(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Primitives.radiusCard),
        side: BorderSide(color: tokens.threadFaint, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Primitives.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                Text(
                  'Inspection: Level ${_inspectedLevel?.id ?? _levelInputController.text}',
                  style: tokens.typography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_inspectedLevel != null)
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16.0),
                    label: const Text('Copy Diagnostics'),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.accent,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _copyDiagnosticsToClipboard,
                  ),
              ],
            ),
            const SizedBox(height: Primitives.space8),

            if (_isLoadingInspectedLevel)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              )
            else if (_inspectedLevel != null) ...[
              _buildKeyValueRow(
                  'Chapter',
                  '${_inspectedLevel!.chapter} (${_getChapterName(_inspectedLevel!.chapter)})',
                  tokens),
              Divider(color: tokens.threadFaint, height: 12.0),
              _buildKeyValueRow(
                  'Grid Dimensions',
                  '${_inspectedLevel!.rows} Rows × ${_inspectedLevel!.cols} Columns',
                  tokens),
              Divider(color: tokens.threadFaint, height: 12.0),
              _buildKeyValueRow('Total Threads (Arrows)',
                  '${_inspectedLevel!.threads.length}', tokens),
              Divider(color: tokens.threadFaint, height: 12.0),
              _buildKeyValueRow('Deflectors',
                  '${_inspectedLevel!.deflectors.length}', tokens),
              Divider(color: tokens.threadFaint, height: 12.0),
              _buildKeyValueRow('Par', '${_inspectedLevel!.par}', tokens),
              Divider(color: tokens.threadFaint, height: 12.0),
              _buildKeyValueRow(
                  'Shape Identifier', _inspectedLevel!.shape, tokens),
            ] else
              Text(
                'Enter a valid level number above to inspect geometry.',
                style:
                    tokens.typography.caption.copyWith(color: tokens.inkMuted),
              ),

            const SizedBox(height: Primitives.space16),
            Divider(color: tokens.threadFaint, height: 1.0),
            const SizedBox(height: Primitives.space12),

            // Animation suppression utility
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Suppress animations during QA',
                  style: tokens.typography.body),
              subtitle: Text(
                'Enables immediate puzzle transitions for fast regression runs',
                style: tokens.typography.caption,
              ),
              value: qaSession.suppressAnimations,
              activeTrackColor: tokens.accent,
              onChanged: (val) {
                ref.read(qaSessionProvider.notifier).setSuppressAnimations(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getChapterName(int chapterNumber) {
    if (chapterNumber >= 1 && chapterNumber <= allChapters.length) {
      return allChapters[chapterNumber - 1].name;
    }
    return 'Chapter $chapterNumber';
  }

  Widget _buildLevelBrowser(
    AppTokens tokens,
    ProgressState progress,
    QaSessionState qaSession,
  ) {
    return Card(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Primitives.radiusCard),
        side: BorderSide(color: tokens.threadFaint, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Primitives.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search & Chapter Filter
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                final searchField = TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search level or chapter...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20.0),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16.0),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(Primitives.radiusButton),
                      borderSide: BorderSide(color: tokens.threadFaint),
                    ),
                  ),
                );

                final chapterDropdown = DropdownButton<int>(
                  value: _selectedChapter,
                  dropdownColor: tokens.surface,
                  underline: const SizedBox.shrink(),
                  isExpanded: isNarrow,
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('All Chapters'),
                    ),
                    for (final ch in allChapters)
                      DropdownMenuItem(
                        value: ch.number,
                        child: Text('Ch ${ch.number}: ${ch.name}'),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedChapter = val;
                      });
                    }
                  },
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: Primitives.space8),
                      chapterDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: Primitives.space12),
                    chapterDropdown,
                  ],
                );
              },
            ),

            const SizedBox(height: Primitives.space16),

            // Filtered level list / grid
            _buildFilteredLevelList(tokens, progress, qaSession),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredLevelList(
    AppTokens tokens,
    ProgressState progress,
    QaSessionState qaSession,
  ) {
    // Generate filtered list
    final filteredLevels = <int>[];
    for (var id = 1; id <= _totalLevels; id++) {
      final ch = ((id - 1) ~/ 20) + 1;
      if (_selectedChapter > 0 && ch != _selectedChapter) {
        continue;
      }
      if (_searchQuery.isNotEmpty) {
        final matchesId = id.toString().contains(_searchQuery);
        final chName = _getChapterName(ch).toLowerCase();
        final matchesChapter = chName.contains(_searchQuery);
        if (!matchesId && !matchesChapter) {
          continue;
        }
      }
      filteredLevels.add(id);
    }

    if (filteredLevels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            'No matching levels found.',
            style: tokens.typography.caption.copyWith(color: tokens.inkMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Showing ${filteredLevels.length} levels (tap to test)',
          style: tokens.typography.caption.copyWith(
            color: tokens.inkMuted,
            fontSize: 12.0,
          ),
        ),
        const SizedBox(height: Primitives.space12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: Primitives.space8,
            mainAxisSpacing: Primitives.space8,
            childAspectRatio: 1.1,
          ),
          itemCount: filteredLevels.length,
          itemBuilder: (context, idx) {
            final levelId = filteredLevels[idx];
            final isPlayerUnlocked = levelId <= progress.highestUnlocked;
            final isPlayerCompleted = (progress.stars[levelId] ?? 0) > 0;
            final stars = progress.stars[levelId] ?? 0;
            final isCurrentActiveQa =
                qaSession.isActive && qaSession.activeLevelId == levelId;
            final isQaCompleted = qaSession.completedQaLevels.contains(levelId);

            return InkWell(
              borderRadius: BorderRadius.circular(Primitives.radiusButton),
              onTap: () {
                _levelInputController.text = levelId.toString();
                _inspectLevel(levelId);
                _launchLevel(levelId);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isCurrentActiveQa
                      ? tokens.accent.withValues(alpha: 0.15)
                      : tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(Primitives.radiusButton),
                  border: Border.all(
                    color: isCurrentActiveQa
                        ? tokens.accent
                        : isPlayerCompleted
                            ? tokens.accent.withValues(alpha: 0.5)
                            : tokens.threadFaint,
                    width: isCurrentActiveQa ? 2.0 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$levelId',
                      style: TextStyle(
                        fontFamily: Primitives.fontDisplay,
                        fontSize: 14.0,
                        fontWeight: isCurrentActiveQa
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isCurrentActiveQa
                            ? tokens.accent
                            : isPlayerUnlocked
                                ? tokens.ink
                                : tokens.inkMuted,
                      ),
                    ),
                    if (isPlayerCompleted)
                      Text(
                        '★' * stars,
                        style: TextStyle(
                          fontSize: 8.0,
                          color: tokens.accent,
                        ),
                      )
                    else if (isQaCompleted)
                      Container(
                        margin: const EdgeInsets.only(top: 2.0),
                        width: 4.0,
                        height: 4.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tokens.accent,
                        ),
                      )
                    else if (!isPlayerUnlocked)
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 10.0,
                        color: tokens.inkFaint,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
