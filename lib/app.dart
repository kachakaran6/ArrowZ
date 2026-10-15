import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/design/theme_provider.dart';
import 'package:arrowtapout/design/typography.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnwindApp extends ConsumerStatefulWidget {
  const UnwindApp({super.key});

  @override
  ConsumerState<UnwindApp> createState() => _UnwindAppState();
}

class _UnwindAppState extends ConsumerState<UnwindApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(soundServiceProvider).onResume();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep sound service enabled flag cached and synchronized
    final soundEnabled = ref.watch(settingsProvider.select((s) => s.sound));
    ref.read(audioServiceProvider).updateSoundEnabled(soundEnabled);

    final router = ref.watch(appRouterProvider);
    final themeData = ref.watch(currentThemeProvider);

    return MaterialApp.router(
      title: 'ArrowZ',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: themeData,
      builder: (context, child) {
        // Clamp system text scale to 1.3 max per accessibility spec
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = AppTypography.clampScaler(mediaQuery.textScaler);

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
