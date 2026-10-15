import 'dart:typed_data';

import 'package:arrowtapout/data/level_binary_codec.dart';
import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/deflector.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelBinaryCodec Tests', () {
    late List<Level> sampleLevels;

    setUp(() {
      sampleLevels = [
        Level(
          id: 1,
          rows: 10,
          cols: 10,
          shape: 'square',
          par: 3,
          chapter: 1,
          threads: [
            Thread(1, [const Cell(4, 4), const Cell(4, 5)]),
            Thread(2, [const Cell(6, 5), const Cell(5, 5)]),
          ],
        ),
        Level(
          id: 2,
          rows: 12,
          cols: 12,
          shape: 'cat',
          par: 4,
          chapter: 1,
          threads: [
            Thread(1, [const Cell(1, 1), const Cell(1, 2)], colorGroup: 0),
            Thread(2, [const Cell(8, 8), const Cell(8, 7)], colorGroup: 0),
            Thread(3, [const Cell(3, 4), const Cell(2, 4), const Cell(2, 5)]),
          ],
          deflectors: [
            const Deflector(cell: Cell(5, 5), dir: Dir.right),
            const Deflector(cell: Cell(7, 2), dir: Dir.up),
          ],
        ),
      ];
    });

    test('roundtrip serialization produces identical Level models', () {
      final bytes = encodeLevels(sampleLevels);
      expect(bytes.length, greaterThan(20));

      final decoder = LevelBinaryDecoder.fromBytes(bytes);
      expect(decoder.levelCount, equals(2));

      for (var i = 0; i < sampleLevels.length; i++) {
        final original = sampleLevels[i];
        final decoded = decoder.decodeLevelAt(i);

        expect(decoded.id, equals(original.id));
        expect(decoded.rows, equals(original.rows));
        expect(decoded.cols, equals(original.cols));
        expect(decoded.par, equals(original.par));
        expect(decoded.chapter, equals(original.chapter));
        expect(decoded.shape, equals(original.shape));
        expect(decoded.threads.length, equals(original.threads.length));

        for (var t = 0; t < original.threads.length; t++) {
          final origT = original.threads[t];
          final decT = decoded.threads[t];
          expect(decT.id, equals(origT.id));
          expect(decT.colorGroup, equals(origT.colorGroup));
          expect(decT.cells.length, equals(origT.cells.length));
          for (var c = 0; c < origT.cells.length; c++) {
            expect(decT.cells[c], equals(origT.cells[c]));
          }
          expect(decT.dir, equals(origT.dir));
        }

        expect(decoded.deflectors.length, equals(original.deflectors.length));
        for (var d = 0; d < original.deflectors.length; d++) {
          expect(decoded.deflectors[d], equals(original.deflectors[d]));
        }
      }
    });

    test('decodeLevelByNumber finds level by 1-indexed ID in O(1)', () {
      final bytes = encodeLevels(sampleLevels);
      final decoder = LevelBinaryDecoder.fromBytes(bytes);

      final level1 = decoder.decodeLevelByNumber(1);
      expect(level1, isNotNull);
      expect(level1!.id, equals(1));
      expect(level1.shape, equals('square'));

      final level2 = decoder.decodeLevelByNumber(2);
      expect(level2, isNotNull);
      expect(level2!.id, equals(2));
      expect(level2.shape, equals('cat'));
      expect(level2.deflectors.length, equals(2));

      final nonExistent = decoder.decodeLevelByNumber(99);
      expect(nonExistent, isNull);
    });

    test('decodeAll returns all levels', () {
      final bytes = encodeLevels(sampleLevels);
      final decoder = LevelBinaryDecoder.fromBytes(bytes);

      final all = decoder.decodeAll();
      expect(all.length, equals(2));
      expect(all[0].id, equals(1));
      expect(all[1].id, equals(2));
    });

    test('throws FormatException on corrupted header', () {
      final badBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x01, 0x00, 0x00]);
      expect(() => LevelBinaryDecoder.fromBytes(badBytes), throwsFormatException);
    });
  });
}
