import 'package:share_plus/share_plus.dart';

abstract final class ShareService {
  static const String appUrl =
      'https://play.google.com/store/apps/details?id=com.arrowz.app';

  /// Shares the app link with a friendly invite message.
  static Future<void> shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Can you untangle the threads? 🏹 Play ArrowZ — the calm, offline thread puzzle game! Download free on Google Play: $appUrl',
        subject: 'Play ArrowZ with me!',
      ),
    );
  }

  /// Shares a completed level milestone.
  static Future<void> shareLevelComplete({
    required int levelId,
    String? timeFormatted,
    int stars = 3,
  }) async {
    final timeStr = timeFormatted != null ? ' in $timeFormatted' : '';
    final starsStr = '⭐' * stars;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'I just cleared Level $levelId$timeStr with $starsStr in ArrowZ! Can you beat my time? 🎯 Play here: $appUrl',
        subject: 'ArrowZ Level $levelId Cleared!',
      ),
    );
  }
}
