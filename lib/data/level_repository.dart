import 'dart:convert';

import 'package:arrowtapout/data/level_binary_codec.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

List<Level> _parseChapterJson((String, int) args) {
  final (jsonStr, chapterNumber) = args;
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
  final levelsRaw = map['levels'] as List<dynamic>;
  return levelsRaw
      .map((r) =>
          Level.fromJson(r as Map<String, dynamic>, chapter: chapterNumber))
      .toList(growable: false);
}

class LevelRepository {
  final Map<int, List<Level>> _chapterCache = {};
  LevelBinaryDecoder? _binaryDecoder;
  bool _binaryLoadAttempted = false;

  Future<void> _ensureBinaryDecoder() async {
    if (_binaryLoadAttempted) return;
    _binaryLoadAttempted = true;
    try {
      ByteData byteData;
      try {
        byteData = await rootBundle.load('assets/levels/levels.bin');
      } catch (_) {
        byteData = await rootBundle.load('assets/levels.bin');
      }
      _binaryDecoder = LevelBinaryDecoder.fromBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    } catch (_) {
      // Fallback to chapter JSONs if binary is not bundled
    }
  }

  Future<void> init() async {
    await _ensureBinaryDecoder();
  }

  Level? getLevelSync(int id) {
    if (_binaryDecoder != null && id >= 1 && id <= _binaryDecoder!.levelCount) {
      return _binaryDecoder!.decodeLevelByNumber(id);
    }
    return null;
  }

  /// Loads all 20 levels for a given [chapterNumber] (1..N).
  Future<List<Level>> loadChapter(int chapterNumber) async {
    if (_chapterCache.containsKey(chapterNumber)) {
      return _chapterCache[chapterNumber]!;
    }

    await _ensureBinaryDecoder();
    if (_binaryDecoder != null) {
      final startId = (chapterNumber - 1) * 20 + 1;
      final endId = chapterNumber * 20;
      if (endId <= _binaryDecoder!.levelCount) {
        final levels = <Level>[];
        for (var id = startId; id <= endId; id++) {
          final level = _binaryDecoder!.decodeLevelByNumber(id);
          if (level != null) levels.add(level);
        }
        if (levels.length == 20) {
          _chapterCache[chapterNumber] = List.unmodifiable(levels);
          return _chapterCache[chapterNumber]!;
        }
      }
    }

    final numStr = chapterNumber.toString().padLeft(2, '0');
    final assetPath = 'assets/levels/chapter_$numStr.json';
    final jsonStr = await rootBundle.loadString(assetPath);
    final levels = await compute(_parseChapterJson, (jsonStr, chapterNumber));

    _chapterCache[chapterNumber] = levels;

    // Pre-cache next chapter if available
    if (chapterNumber < 25 && !_chapterCache.containsKey(chapterNumber + 1)) {
      unawaited(_preloadNextChapter(chapterNumber + 1));
    }

    return levels;
  }

  Future<void> _preloadNextChapter(int chapterNumber) async {
    try {
      final numStr = chapterNumber.toString().padLeft(2, '0');
      final assetPath = 'assets/levels/chapter_$numStr.json';
      final jsonStr = await rootBundle.loadString(assetPath);
      final levels = await compute(_parseChapterJson, (jsonStr, chapterNumber));
      _chapterCache[chapterNumber] = levels;
    } catch (_) {
      // Ignored in background preload
    }
  }

  /// Loads a specific level by its 1-indexed global ID (1..500).
  Future<Level> loadLevel(int id) async {
    await _ensureBinaryDecoder();
    if (_binaryDecoder != null && id >= 1 && id <= _binaryDecoder!.levelCount) {
      final level = _binaryDecoder!.decodeLevelByNumber(id);
      if (level != null) return level;
    }

    final chapter = ((id - 1) ~/ 20) + 1;
    final chapterLevels = await loadChapter(chapter);
    return chapterLevels.firstWhere(
      (l) => l.id == id,
      orElse: () => throw StateError('Level $id not found in chapter $chapter'),
    );
  }
}

void unawaited(Future<void> future) {}

final levelRepositoryProvider = Provider<LevelRepository>((ref) {
  return LevelRepository();
});
