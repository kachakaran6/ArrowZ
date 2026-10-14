import 'package:arrowtapout/design/theme_provider.dart';
import 'package:arrowtapout/design/typography.dart';
import 'package:arrowtapout/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UnwindApp extends ConsumerWidget {
  const UnwindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
