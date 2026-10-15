import 'dart:convert';

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

  /// Loads all 20 levels for a given [chapterNumber] (1..10).
  Future<List<Level>> loadChapter(int chapterNumber) async {
    if (_chapterCache.containsKey(chapterNumber)) {
      return _chapterCache[chapterNumber]!;
    }

    final numStr = chapterNumber.toString().padLeft(2, '0');
    final assetPath = 'assets/levels/chapter_$numStr.json';
    final jsonStr = await rootBundle.loadString(assetPath);
    final levels = await compute(_parseChapterJson, (jsonStr, chapterNumber));

    _chapterCache[chapterNumber] = levels;

    // Pre-cache next chapter if available
    if (chapterNumber < 10 && !_chapterCache.containsKey(chapterNumber + 1)) {
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

  /// Loads a specific level by its 1-indexed global ID (1..200).
  Future<Level> loadLevel(int id) async {
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
