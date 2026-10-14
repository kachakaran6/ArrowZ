import 'package:arrowtapout/features/game/game_controller.dart';
import 'package:arrowtapout/features/game/game_state.dart';
import 'package:arrowtapout/platform/ad_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status outcomes of a hint request.
enum HintResultStatus {
  success,
  noValidMove,
  adDismissed,
  adFailed,
  alreadyInProgress,
  levelNotPlaying,
}

/// Result returned from a hint request.
@immutable
class HintResult {
  const HintResult({
    required this.status,
    this.hintedThreadId,
    this.message,
  });

  final HintResultStatus status;
  final int? hintedThreadId;
  final String? message;

  bool get isSuccess => status == HintResultStatus.success;
}

/// Service that coordinates rewarded-ad hint generation and presentation.
class HintService extends ChangeNotifier {
  HintService({required this.adService});

  final RewardedAdService adService;
  bool _isRequestInProgress = false;
  final Set<String> _processedRequestIds = {};

  bool get isRequestInProgress => _isRequestInProgress;

  /// Requests a rewarded hint for the active [controller].
  Future<HintResult> requestRewardedHint({
    required GameController controller,
  }) async {
    // 1. Verify level is currently active
    if (controller.currentState.status != GameStatus.playing) {
      return const HintResult(
        status: HintResultStatus.levelNotPlaying,
        message: 'Level is not currently active.',
      );
    }

    // 2. Prevent overlapping or concurrent requests
    if (_isRequestInProgress) {
      return const HintResult(
        status: HintResultStatus.alreadyInProgress,
        message: 'Hint request already in progress.',
      );
    }

    // 3. Pre-validate that a valid unobstructed arrow exists
    final hintId = controller.chooseHintThread();
    if (hintId == null) {
      return const HintResult(
        status: HintResultStatus.noValidMove,
        message: 'No unobstructed moves available right now.',
      );
    }

    _isRequestInProgress = true;
    notifyListeners();

    final requestId = 'hint_${DateTime.now().microsecondsSinceEpoch}';

    try {
      // 4. Ensure ad is ready, or attempt to load it
      if (!adService.isAdReady) {
        await adService.loadAd();
        if (!adService.isAdReady) {
          return const HintResult(
            status: HintResultStatus.adFailed,
            message:
                'Rewarded ad is unavailable. Check your connection and try again.',
          );
        }
      }

      // 5. Present official rewarded ad experience
      final adResult = await adService.showRewardedAd(requestId: requestId);

      // 6. Handle verified reward callback
      if (adResult.type == RewardedAdResultType.rewardGranted) {
        // Guard against duplicate callback executions for the same request
        if (_processedRequestIds.contains(requestId)) {
          return const HintResult(
            status: HintResultStatus.alreadyInProgress,
            message: 'Reward already processed for this request.',
          );
        }
        _processedRequestIds.add(requestId);

        // Calculate and grant hint on current board state
        final currentHintId = controller.chooseHintThread();
        if (currentHintId == null) {
          return const HintResult(
            status: HintResultStatus.noValidMove,
            message: 'No unobstructed moves remaining.',
          );
        }

        final granted = controller.grantRewardedHint(currentHintId);
        if (granted) {
          return HintResult(
            status: HintResultStatus.success,
            hintedThreadId: currentHintId,
            message: 'Hint applied! An unobstructed arrow is highlighted.',
          );
        } else {
          return const HintResult(
            status: HintResultStatus.levelNotPlaying,
            message: 'Could not apply hint.',
          );
        }
      } else if (adResult.type == RewardedAdResultType.dismissedWithoutReward) {
        return const HintResult(
          status: HintResultStatus.adDismissed,
          message: 'Ad was closed early. Complete the full ad to earn a hint.',
        );
      } else {
        return HintResult(
          status: HintResultStatus.adFailed,
          message: adResult.errorMessage ?? 'Rewarded ad failed to display.',
        );
      }
    } catch (e) {
      return const HintResult(
        status: HintResultStatus.adFailed,
        message: 'An error occurred while loading the ad.',
      );
    } finally {
      _isRequestInProgress = false;
      notifyListeners();
    }
  }
}

/// Global provider for [HintService].
final hintServiceProvider = ChangeNotifierProvider<HintService>((ref) {
  final adService = ref.watch(rewardedAdServiceProvider);
  return HintService(adService: adService);
});
