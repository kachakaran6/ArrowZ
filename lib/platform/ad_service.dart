import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// States for the rewarded ad lifecycle.
enum RewardedAdState {
  idle,
  loading,
  ready,
  showing,
  rewardGranted,
  dismissedWithoutReward,
  failed,
}

/// Result types returned by rewarded ad presentation.
enum RewardedAdResultType {
  rewardGranted,
  dismissedWithoutReward,
  failed,
}

/// Result returned from presenting a rewarded advertisement.
@immutable
class RewardedAdResult {
  const RewardedAdResult({
    required this.type,
    required this.requestId,
    this.errorMessage,
    this.rewardAmount = 1,
  });

  final RewardedAdResultType type;
  final String requestId;
  final String? errorMessage;
  final num rewardAmount;

  bool get isSuccessful => type == RewardedAdResultType.rewardGranted;
}

/// Abstract contract for rewarded ad providers.
abstract class RewardedAdService {
  RewardedAdState get state;
  bool get isAdReady;

  Future<void> initialize();
  Future<void> loadAd();
  Future<RewardedAdResult> showRewardedAd({required String requestId});

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  void dispose();
}

/// Fake implementation of [RewardedAdService] for deterministic testing and headless execution.
class FakeRewardedAdService with ChangeNotifier implements RewardedAdService {
  FakeRewardedAdService({
    RewardedAdState initialState = RewardedAdState.ready,
    this.simulateResult = RewardedAdResultType.rewardGranted,
    this.loadDelay = Duration.zero,
    this.showDelay = Duration.zero,
    this.simulateDuplicateReward = false,
  }) : _state = initialState;

  RewardedAdState _state;
  final RewardedAdResultType simulateResult;
  final Duration loadDelay;
  final Duration showDelay;
  final bool simulateDuplicateReward;

  final List<String> requestedAdIds = [];
  int showAdCallCount = 0;
  int loadAdCallCount = 0;
  bool isInitialized = false;

  @override
  RewardedAdState get state => _state;

  @override
  bool get isAdReady => _state == RewardedAdState.ready;

  void setAdState(RewardedAdState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> loadAd() async {
    loadAdCallCount++;
    if (_state == RewardedAdState.loading) return;

    _state = RewardedAdState.loading;
    notifyListeners();

    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }

    if (simulateResult == RewardedAdResultType.failed) {
      _state = RewardedAdState.failed;
    } else {
      _state = RewardedAdState.ready;
    }
    notifyListeners();
  }

  @override
  Future<RewardedAdResult> showRewardedAd({required String requestId}) async {
    showAdCallCount++;
    requestedAdIds.add(requestId);

    if (_state != RewardedAdState.ready) {
      return RewardedAdResult(
        type: RewardedAdResultType.failed,
        requestId: requestId,
        errorMessage: 'Ad is not ready to display.',
      );
    }

    _state = RewardedAdState.showing;
    notifyListeners();

    if (showDelay > Duration.zero) {
      await Future<void>.delayed(showDelay);
    }

    switch (simulateResult) {
      case RewardedAdResultType.rewardGranted:
        _state = RewardedAdState.rewardGranted;
        notifyListeners();
        _state = RewardedAdState.ready;
        notifyListeners();
        return RewardedAdResult(
          type: RewardedAdResultType.rewardGranted,
          requestId: requestId,
        );

      case RewardedAdResultType.dismissedWithoutReward:
        _state = RewardedAdState.dismissedWithoutReward;
        notifyListeners();
        _state = RewardedAdState.ready;
        notifyListeners();
        return RewardedAdResult(
          type: RewardedAdResultType.dismissedWithoutReward,
          requestId: requestId,
          errorMessage: 'Ad closed before completion.',
        );

      case RewardedAdResultType.failed:
        _state = RewardedAdState.failed;
        notifyListeners();
        return RewardedAdResult(
          type: RewardedAdResultType.failed,
          requestId: requestId,
          errorMessage: 'Simulated ad playback failure.',
        );
    }
  }
}

/// Production implementation of [RewardedAdService] using Google Mobile Ads SDK.
class GoogleMobileAdsRewardedAdService
    with ChangeNotifier
    implements RewardedAdService {
  GoogleMobileAdsRewardedAdService({
    String? androidAdUnitId,
    String? iosAdUnitId,
  })  : _androidAdUnitId =
            androidAdUnitId ?? 'ca-app-pub-3940256099942544/5224354917',
        _iosAdUnitId = iosAdUnitId ?? 'ca-app-pub-3940256099942544/1712485313';

  final String _androidAdUnitId;
  final String _iosAdUnitId;

  RewardedAd? _rewardedAd;
  RewardedAdState _state = RewardedAdState.idle;
  Completer<void>? _loadCompleter;
  bool _initialized = false;

  String get _adUnitId {
    if (kIsWeb) return '';
    try {
      if (Platform.isAndroid) return _androidAdUnitId;
      if (Platform.isIOS) return _iosAdUnitId;
    } catch (_) {
      // Default to Android test unit for test/headless runs
      return _androidAdUnitId;
    }
    return _androidAdUnitId;
  }

  @override
  RewardedAdState get state => _state;

  @override
  bool get isAdReady => _rewardedAd != null && _state == RewardedAdState.ready;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      // Preload first ad asynchronously
      unawaited(loadAd());
    } catch (e) {
      debugPrint('Warning: MobileAds initialization failed: $e');
    }
  }

  @override
  Future<void> loadAd() async {
    if (isAdReady) return;
    if (_loadCompleter != null) return _loadCompleter!.future;

    _loadCompleter = Completer<void>();
    _state = RewardedAdState.loading;
    notifyListeners();

    try {
      await RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd?.dispose();
            _rewardedAd = ad;
            _state = RewardedAdState.ready;
            notifyListeners();
            if (!_loadCompleter!.isCompleted) {
              _loadCompleter!.complete();
            }
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _state = RewardedAdState.failed;
            notifyListeners();
            if (!_loadCompleter!.isCompleted) {
              _loadCompleter!.complete();
            }
          },
        ),
      );
    } catch (e) {
      _state = RewardedAdState.failed;
      notifyListeners();
      if (!_loadCompleter!.isCompleted) {
        _loadCompleter!.complete();
      }
    } finally {
      final future = _loadCompleter!.future;
      _loadCompleter = null;
      await future;
    }
  }

  @override
  Future<RewardedAdResult> showRewardedAd({required String requestId}) async {
    if (!isAdReady || _rewardedAd == null) {
      return RewardedAdResult(
        type: RewardedAdResultType.failed,
        requestId: requestId,
        errorMessage: 'Ad is not ready.',
      );
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    _state = RewardedAdState.showing;
    notifyListeners();

    final resultCompleter = Completer<RewardedAdResult>();
    var userEarnedReward = false;
    num rewardAmount = 1;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        // Ad displayed
      },
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (userEarnedReward) {
          _state = RewardedAdState.rewardGranted;
          notifyListeners();
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(RewardedAdResult(
              type: RewardedAdResultType.rewardGranted,
              requestId: requestId,
              rewardAmount: rewardAmount,
            ));
          }
        } else {
          _state = RewardedAdState.dismissedWithoutReward;
          notifyListeners();
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(RewardedAdResult(
              type: RewardedAdResultType.dismissedWithoutReward,
              requestId: requestId,
              errorMessage: 'Ad was dismissed before earning a reward.',
            ));
          }
        }
        // Preload next ad
        unawaited(loadAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        unawaited(ad.dispose());
        _state = RewardedAdState.failed;
        notifyListeners();
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(RewardedAdResult(
            type: RewardedAdResultType.failed,
            requestId: requestId,
            errorMessage: error.message,
          ));
        }
        // Preload next ad
        unawaited(loadAd());
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          userEarnedReward = true;
          rewardAmount = reward.amount;
        },
      );
    } catch (e) {
      unawaited(ad.dispose());
      _state = RewardedAdState.failed;
      notifyListeners();
      if (!resultCompleter.isCompleted) {
        resultCompleter.complete(RewardedAdResult(
          type: RewardedAdResultType.failed,
          requestId: requestId,
          errorMessage: e.toString(),
        ));
      }
      unawaited(loadAd());
    }

    return resultCompleter.future;
  }

  @override
  void dispose() {
    unawaited(_rewardedAd?.dispose());
    _rewardedAd = null;
    super.dispose();
  }
}

/// Global provider for the rewarded ad service.
final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  final service = GoogleMobileAdsRewardedAdService();
  ref.onDispose(service.dispose);
  return service;
});
