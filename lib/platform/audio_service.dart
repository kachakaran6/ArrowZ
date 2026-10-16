import 'dart:async';
import 'package:arrowtapout/core/debug_log.dart';
import 'package:arrowtapout/data/settings_repository.dart';
import 'package:arrowtapout/diagnostics/diagnostics.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SoundEvent {
  pull,
  block,
  complete,
  ui,
}

abstract class SoundService {
  Future<void> init(); // called in main() before runApp
  void play(SoundEvent e); // synchronous, never awaits, never throws
  void onResume(); // re-prepare after background or audio-focus loss
  Diagnostics get stats; // requested, started, failed, inFlight
}

class _SoundVoice {
  _SoundVoice({
    required this.player,
    required this.source,
  });

  final AudioPlayer player;
  final Source source;
  double startTimeMs = 0.0;
  bool isPlaying = false;
  StreamSubscription<void>? completeSub;
  Timer? safetyTimer;

  void dispose() {
    completeSub?.cancel();
    safetyTimer?.cancel();
    player.dispose();
  }
}

class AudioService implements SoundService {
  AudioService([this._ref]) {
    // If a Ref is supplied, listen to settings synchronously
    if (_ref != null) {
      try {
        _soundEnabled = _ref.read(settingsProvider).sound;
        _ref.listen<SettingsState>(settingsProvider, (_, next) {
          _soundEnabled = next.sound;
        });
      } catch (_) {}
    }
  }

  final Ref? _ref;

  static const int _pullVoiceCount = 4;
  final List<_SoundVoice> _pullVoices = [];
  final List<_SoundVoice> _blockVoices = [];
  _SoundVoice? _completeVoice;
  _SoundVoice? _uiVoice;

  bool _initialized = false;
  bool _soundEnabled = true;

  void updateSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  @override
  Diagnostics get stats => Diagnostics.instance;

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {},
          ),
        ),
      );

      _pullVoices.clear();
      for (var i = 0; i < _pullVoiceCount; i++) {
        _pullVoices.add(_createVoice(AssetSource('audio/pull.ogg')));
      }

      _blockVoices.clear();
      for (var i = 0; i < 2; i++) {
        _blockVoices.add(_createVoice(AssetSource('audio/block.ogg')));
      }

      _completeVoice = _createVoice(AssetSource('audio/complete.ogg'));
      _uiVoice = _createVoice(AssetSource('audio/ui.ogg'));

      _initialized = true;
      _updateDiagnosticsPool();
      debugLog('AudioService initialized with ${_pullVoices.length} pull voices');
    } catch (e) {
      Diagnostics.instance.soundLastError = e.toString();
      debugLog('AudioService init failed: $e');
    }
  }

  _SoundVoice _createVoice(Source source) {
    final player = AudioPlayer();
    player.setPlayerMode(PlayerMode.lowLatency);

    final voice = _SoundVoice(player: player, source: source);
    voice.completeSub = player.onPlayerComplete.listen((_) {
      voice.isPlaying = false;
      voice.safetyTimer?.cancel();
      _updateInFlightCount();
    });

    return voice;
  }

  void _updateInFlightCount() {
    final inFlight = _pullVoices.where((v) => v.isPlaying).length +
        _blockVoices.where((v) => v.isPlaying).length +
        ((_completeVoice?.isPlaying ?? false) ? 1 : 0) +
        ((_uiVoice?.isPlaying ?? false) ? 1 : 0);
    Diagnostics.instance.soundInFlightVoices = inFlight;
  }

  void _updateDiagnosticsPool() {
    Diagnostics.instance.soundPoolSize = _pullVoices.length;
    _updateInFlightCount();
  }

  @override
  void play(SoundEvent e) {
    Diagnostics.instance.soundRequested++;
    if (!_soundEnabled) return;

    if (!_initialized) {
      // Lazy init fallback if not awaited in main
      unawaited(init().then((_) {
        if (_initialized) _dispatchPlay(e);
      }));
      return;
    }

    _dispatchPlay(e);
  }

  void _dispatchPlay(SoundEvent e) {
    switch (e) {
      case SoundEvent.pull:
        _playVoiceWithStealing(_pullVoices, volume: 0.85, safetyDurationMs: 450);
      case SoundEvent.block:
        _playVoiceWithStealing(_blockVoices, volume: 0.90, safetyDurationMs: 400);
      case SoundEvent.complete:
        if (_completeVoice != null) {
          _playSingleVoice(_completeVoice!, volume: 0.95, safetyDurationMs: 900);
        }
      case SoundEvent.ui:
        if (_uiVoice != null) {
          _playSingleVoice(_uiVoice!, volume: 0.70, safetyDurationMs: 300);
        }
    }
  }

  void _playVoiceWithStealing(
    List<_SoundVoice> voices, {
    required double volume,
    required int safetyDurationMs,
  }) {
    if (voices.isEmpty) return;

    // 1. Look for an idle voice
    _SoundVoice? target;
    for (final v in voices) {
      if (!v.isPlaying) {
        target = v;
        break;
      }
    }

    // 2. If all voices are busy, steal the oldest voice (smallest startTimeMs)
    if (target == null && voices.isNotEmpty) {
      try {
        target = voices.reduce((a, b) => a.startTimeMs < b.startTimeMs ? a : b);
      } catch (_) {
        target = voices.firstOrNull;
      }
    }

    if (target != null) {
      _playSingleVoice(target, volume: volume, safetyDurationMs: safetyDurationMs);
    }
  }

  void _playSingleVoice(
    _SoundVoice voice, {
    required double volume,
    required int safetyDurationMs,
  }) {
    final nowMs = DateTime.now().microsecondsSinceEpoch / 1000.0;
    voice.isPlaying = true;
    voice.startTimeMs = nowMs;

    voice.safetyTimer?.cancel();
    voice.safetyTimer = Timer(Duration(milliseconds: safetyDurationMs), () {
      voice.isPlaying = false;
      _updateInFlightCount();
    });

    _updateInFlightCount();

    unawaited(() async {
      try {
        await voice.player.play(voice.source, volume: volume);
        Diagnostics.instance.soundStarted++;
      } catch (e) {
        Diagnostics.instance.soundFailed++;
        Diagnostics.instance.soundLastError = e.toString();
        debugLog('Sound playback error: $e');
        voice.isPlaying = false;
        voice.safetyTimer?.cancel();
        _updateInFlightCount();
      }
    }());
  }

  @override
  void onResume() {
    if (!_initialized) {
      unawaited(init());
    }
  }

  // Backward-compatible API helpers
  void playPull() => play(SoundEvent.pull);
  void playBlock() => play(SoundEvent.block);
  void playComplete() => play(SoundEvent.complete);
  void playUi() => play(SoundEvent.ui);

  void dispose() {
    for (final v in _pullVoices) {
      v.dispose();
    }
    _pullVoices.clear();
    for (final v in _blockVoices) {
      v.dispose();
    }
    _blockVoices.clear();
    _completeVoice?.dispose();
    _completeVoice = null;
    _uiVoice?.dispose();
    _uiVoice = null;
    _initialized = false;
  }
}

/// Global shared non-autoDispose sound service provider.
final soundServiceProvider = Provider<SoundService>((ref) {
  final service = AudioService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Legacy compatibility provider alias for existing code.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = ref.watch(soundServiceProvider);
  if (service is AudioService) return service;
  final fallback = AudioService(ref);
  ref.onDispose(fallback.dispose);
  return fallback;
});
