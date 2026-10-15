import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/app_tokens.dart';
import 'package:arrowtapout/design/primitives.dart';
import 'package:arrowtapout/design/themes.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:arrowtapout/features/levels/level_miniature_painter.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/haptics_service.dart';
import 'package:arrowtapout/router/nav_utils.dart';
import 'package:arrowtapout/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemePickerScreen extends ConsumerStatefulWidget {
  const ThemePickerScreen({super.key});

  @override
  ConsumerState<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends ConsumerState<ThemePickerScreen> {
  late final Level _showcaseLevel;

  @override
  void initState() {
    super.initState();
    // Bundled showcase level for live mini-boards across themes
    _showcaseLevel = Level(
      id: 999,
      rows: 6,
      cols: 6,
      threads: [
        Thread(1, [const Cell(0, 1), const Cell(0, 2), const Cell(0, 3), const Cell(0, 4)]),
        Thread(2, [const Cell(1, 5), const Cell(2, 5), const Cell(3, 5), const Cell(4, 5)]),
        Thread(3, [const Cell(5, 4), const Cell(5, 3), const Cell(5, 2), const Cell(5, 1)]),
        Thread(4, [const Cell(4, 0), const Cell(3, 0), const Cell(2, 0), const Cell(1, 0)]),
        Thread(5, [const Cell(2, 2), const Cell(2, 3), const Cell(3, 3)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentThemeId = ref.watch(settingsProvider.select((s) => s.themeId));
    final haptics = ref.read(hapticsServiceProvider);
    final sound = ref.read(soundServiceProvider);

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Themes', style: tokens.typography.title),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.ink),
          tooltip: 'Back',
          onPressed: () {
            haptics.selection();
            context.safeBack(fallbackRoute: Routes.settings);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Preview strip at the top: Home-card and Play-button in the chosen theme
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Primitives.space20,
                vertical: 12.0,
              ),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: tokens.surfaceRaised,
                  borderRadius: BorderRadius.circular(Primitives.radius24),
                  border: Border.all(color: tokens.line, width: 1.0),
                ),
                child: Row(
                  children: [
                    // Mini preview board
                    LevelMiniatureWidget(
                      level: _showcaseLevel,
                      isLocked: false,
                      size: 48.0,
                    ),
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tokens.displayName,
                            style: tokens.typography.heading,
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            tokens.mood,
                            style: tokens.typography.caption.copyWith(
                              color: tokens.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini Play preview button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius:
                            BorderRadius.circular(Primitives.radiusButton),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.accentGlow,
                            blurRadius: 16.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Play',
                        style: tokens.typography.label.copyWith(
                          color: tokens.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8.0),

            // 2-column grid of all six themes
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: Primitives.space20,
                  vertical: 8.0,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14.0,
                  mainAxisSpacing: 14.0,
                  childAspectRatio: 0.88,
                ),
                itemCount: AppThemes.allThemes.length,
                itemBuilder: (context, index) {
                  final themeOption = AppThemes.allThemes[index];
                  final isSelected = themeOption.id == currentThemeId;

                  return Semantics(
                    label:
                        '${themeOption.displayName} theme${isSelected ? ', selected' : ''}',
                    button: true,
                    child: InkWell(
                      onTap: () {
                        sound.play(SoundEvent.ui);
                        haptics.selection();
                        ref
                            .read(settingsProvider.notifier)
                            .setThemeId(themeOption.id);
                        // Mark theme good after frame
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ref
                              .read(settingsProvider.notifier)
                              .markThemeGood(themeOption.id);
                        });
                      },
                      borderRadius:
                          BorderRadius.circular(Primitives.radius16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: themeOption.surface,
                          borderRadius:
                              BorderRadius.circular(Primitives.radius16),
                          border: Border.all(
                            color: isSelected
                                ? themeOption.accent
                                : themeOption.line,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        themeOption.accent.withValues(alpha: 0.2),
                                    blurRadius: 12.0,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header of tile: theme name + check/tag
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    themeOption.displayName,
                                    style: TextStyle(
                                      fontFamily: Primitives.fontDisplay,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                      color: themeOption.ink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16.0,
                                    color: themeOption.accent,
                                  )
                                else if (themeOption.subtitle == 'Original')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 2.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeOption.surfaceRaised,
                                      borderRadius: BorderRadius.circular(4.0),
                                    ),
                                    child: Text(
                                      'Original',
                                      style: TextStyle(
                                        fontFamily: Primitives.fontUi,
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w600,
                                        color: themeOption.inkMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              themeOption.mood,
                              style: TextStyle(
                                fontFamily: Primitives.fontUi,
                                fontSize: 11.0,
                                color: themeOption.inkMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            // Live mini board in that theme
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(6.0),
                                decoration: BoxDecoration(
                                  color: themeOption.bg,
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(
                                    color: themeOption.line,
                                    width: 1.0,
                                  ),
                                ),
                                child: LevelMiniatureWidget(
                                  level: _showcaseLevel,
                                  isLocked: false,
                                  size: 54.0,
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
