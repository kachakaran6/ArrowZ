import 'dart:convert';
import 'dart:io';
import 'package:arrowtapout/engine/level.dart';

void main() {
  final content = File('assets/levels/chapter_04.json').readAsStringSync();
  final data = jsonDecode(content);
  for (final lvlJson in data['levels']) {
    if (lvlJson['id'] == 64) {
      final lvl = Level.fromJson(lvlJson as Map<String, dynamic>);
      final allCells = lvl.threads.expand((t) => t.cells).toList();
      final minR = allCells.map((c) => c.r).reduce((a, b) => a < b ? a : b);
      final maxR = allCells.map((c) => c.r).reduce((a, b) => a > b ? a : b);
      final minC = allCells.map((c) => c.c).reduce((a, b) => a < b ? a : b);
      final maxC = allCells.map((c) => c.c).reduce((a, b) => a > b ? a : b);
      print('Level 64: rows=${lvl.rows}, cols=${lvl.cols}, shape=${lvl.shape}');
      print('Bounding box: R: $minR..$maxR, C: $minC..$maxC');
      print('Threads: ${lvl.threads.length}');
    }
  }
}
