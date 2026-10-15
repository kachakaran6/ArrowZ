import 'dart:async';

import 'package:arrowtapout/app.dart';
import 'package:arrowtapout/data/progress_repository.dart';
import 'package:arrowtapout/platform/ad_service.dart';
import 'package:arrowtapout/platform/audio_service.dart';
import 'package:arrowtapout/platform/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent edge-to-edge system bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final notificationService = LocalNotificationService();
  await notificationService.initialize();

  final soundService = AudioService();
  await soundService.init();

  final adService = GoogleMobileAdsRewardedAdService();
  unawaited(adService.initialize());

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        soundServiceProvider.overrideWithValue(soundService),
        audioServiceProvider.overrideWithValue(soundService),
        notificationServiceProvider.overrideWithValue(notificationService),
        rewardedAdServiceProvider.overrideWithValue(adService),
      ],
      child: const UnwindApp(),
    ),
  );
}
