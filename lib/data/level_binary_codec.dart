import 'dart:convert';
import 'dart:typed_data';

import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/deflector.dart';
import 'package:arrowtapout/engine/dir.dart';
import 'package:arrowtapout/engine/level.dart';
import 'package:arrowtapout/engine/thread.dart';

/// Binary format specification for ArrowZ levels:
///
/// Header:
/// - 4 bytes: Magic ASCII 'ARWZ' (0x41, 0x52, 0x57, 0x5A)
/// - 1 byte : Version (0x01)
/// - 2 bytes: Level Count (uint16, big-endian)
/// - N * 4 bytes: Offset Table (uint32 big-endian byte offset for each level)
///
/// Per-Level Block:
/// - 2 bytes: id (uint16)
/// - 1 byte : rows (uint8)
/// - 1 byte : cols (uint8)
/// - 1 byte : par (uint8)
/// - 1 byte : chapter (uint8)
/// - 1 byte : shape length (uint8)
/// - K bytes: shape UTF-8 string
/// - 2 bytes: thread count (uint16)
/// - For each thread:
///   - 2 bytes: thread id (uint16)
///   - 1 byte : hasColorGroup flag (0 = null, 1 = present)
///   - (if flag == 1) 1 byte: colorGroup (uint8)
///   - 2 bytes: cell count (uint16)
///   - For each cell:
///     - 1 byte: row (uint8)
///     - 1 byte: col (uint8)
/// - 2 bytes: deflector count (uint16)
/// - For each deflector:
///   - 1 byte: row (uint8)
///   - 1 byte: col (uint8)
///   - 1 byte: dir index (0=up, 1=right, 2=down, 3=left)
class LevelBinaryCodec {
  static const List<int> magic = [0x41, 0x52, 0x57, 0x5A]; // 'ARWZ'
  static const int version = 1;
}

/// Serializes a list of [Level] objects into a compact binary byte array.
Uint8List encodeLevels(List<Level> levels) {
  final count = levels.length;
  final encodedLevelBlocks = <Uint8List>[];

  for (final level in levels) {
    encodedLevelBlocks.add(_encodeLevelPayload(level));
  }

  // Header size: 4 (magic) + 1 (version) + 2 (count) + count * 4 (offset table)
  final headerSize = 4 + 1 + 2 + (count * 4);
  var currentOffset = headerSize;
  final offsets = Uint32List(count);

  for (var i = 0; i < count; i++) {
    offsets[i] = currentOffset;
    currentOffset += encodedLevelBlocks[i].length;
  }

  final totalSize = currentOffset;
  final buffer = Uint8List(totalSize);
  final byteData = ByteData.sublistView(buffer);

  // Magic
  buffer[0] = LevelBinaryCodec.magic[0];
  buffer[1] = LevelBinaryCodec.magic[1];
  buffer[2] = LevelBinaryCodec.magic[2];
  buffer[3] = LevelBinaryCodec.magic[3];

  // Version
  buffer[4] = LevelBinaryCodec.version;

  // Level Count
  byteData.setUint16(5, count, Endian.big);

  // Offset Table
  var offsetPos = 7;
  for (var i = 0; i < count; i++) {
    byteData.setUint32(offsetPos, offsets[i], Endian.big);
    offsetPos += 4;
  }

  // Append level blocks
  var writePos = headerSize;
  for (var i = 0; i < count; i++) {
    buffer.setRange(
      writePos,
      writePos + encodedLevelBlocks[i].length,
      encodedLevelBlocks[i],
    );
    writePos += encodedLevelBlocks[i].length;
  }

  return buffer;
}

/// Encodes a single level's payload (without global header).
Uint8List _encodeLevelPayload(Level level) {
  final shapeBytes = utf8.encode(level.shape);
  final bb = BytesBuilder(copy: false);

  final meta = ByteData(7 + shapeBytes.length + 2);
  meta.setUint16(0, level.id, Endian.big);
  meta.setUint8(2, level.rows);
  meta.setUint8(3, level.cols);
  meta.setUint8(4, level.par.clamp(0, 255));
  meta.setUint8(5, level.chapter.clamp(0, 255));
  meta.setUint8(6, shapeBytes.length.clamp(0, 255));

  for (var i = 0; i < shapeBytes.length; i++) {
    meta.setUint8(7 + i, shapeBytes[i]);
  }

  meta.setUint16(7 + shapeBytes.length, level.threads.length, Endian.big);
  bb.add(meta.buffer.asUint8List());

  // Threads
  for (final thread in level.threads) {
    final hasColor = thread.colorGroup != null;
    final threadHeaderLen = 2 + 1 + (hasColor ? 1 : 0) + 2;
    final tBuf = ByteData(threadHeaderLen);
    var p = 0;
    tBuf.setUint16(p, thread.id, Endian.big);
    p += 2;
    tBuf.setUint8(p, hasColor ? 1 : 0);
    p += 1;
    if (hasColor) {
      tBuf.setUint8(p, thread.colorGroup!.clamp(0, 255));
      p += 1;
    }
    tBuf.setUint16(p, thread.cells.length, Endian.big);
    bb.add(tBuf.buffer.asUint8List());

    // Cells
    final cellsBuf = Uint8List(thread.cells.length * 2);
    for (var i = 0; i < thread.cells.length; i++) {
      cellsBuf[i * 2] = thread.cells[i].r;
      cellsBuf[i * 2 + 1] = thread.cells[i].c;
    }
    bb.add(cellsBuf);
  }

  // Deflectors
  final defHeader = ByteData(2);
  defHeader.setUint16(0, level.deflectors.length, Endian.big);
  bb.add(defHeader.buffer.asUint8List());

  if (level.deflectors.isNotEmpty) {
    final defBuf = Uint8List(level.deflectors.length * 3);
    for (var i = 0; i < level.deflectors.length; i++) {
      final d = level.deflectors[i];
      defBuf[i * 3] = d.cell.r;
      defBuf[i * 3 + 1] = d.cell.c;
      defBuf[i * 3 + 2] = d.dir.index;
    }
    bb.add(defBuf);
  }

  return bb.toBytes();
}

/// High-performance random-access reader for binary level files.
class LevelBinaryDecoder {
  LevelBinaryDecoder._(this._bytes, this._byteData, this.levelCount);

  final Uint8List _bytes;
  final ByteData _byteData;

  /// Total number of pre-compiled levels in this binary archive.
  final int levelCount;

  /// Loads and parses the binary archive header and builds offset table.
  factory LevelBinaryDecoder.fromBytes(Uint8List bytes) {
    if (bytes.length < 7) {
      throw const FormatException('LevelBinaryDecoder: byte buffer too short');
    }

    if (bytes[0] != LevelBinaryCodec.magic[0] ||
        bytes[1] != LevelBinaryCodec.magic[1] ||
        bytes[2] != LevelBinaryCodec.magic[2] ||
        bytes[3] != LevelBinaryCodec.magic[3]) {
      throw const FormatException('LevelBinaryDecoder: invalid magic header');
    }

    final ver = bytes[4];
    if (ver != LevelBinaryCodec.version) {
      throw FormatException(
        'LevelBinaryDecoder: unsupported version $ver (expected ${LevelBinaryCodec.version})',
      );
    }

    final byteData = ByteData.sublistView(bytes);
    final count = byteData.getUint16(5, Endian.big);

    final expectedHeaderSize = 7 + (count * 4);
    if (bytes.length < expectedHeaderSize) {
      throw const FormatException(
        'LevelBinaryDecoder: buffer truncated in offset table',
      );
    }

    return LevelBinaryDecoder._(bytes, byteData, count);
  }

  /// Returns the offset for level at 0-indexed [index].
  int _offsetFor(int index) {
    if (index < 0 || index >= levelCount) {
      throw RangeError.index(index, levelCount, 'index');
    }
    return _byteData.getUint32(7 + (index * 4), Endian.big);
  }

  /// Decodes level at 0-indexed [index] in $O(1)$ time without parsing other levels.
  Level decodeLevelAt(int index) {
    final offset = _offsetFor(index);
    return _decodeLevelFromOffset(offset);
  }

  /// Decodes level by 1-indexed [levelNumber].
  Level? decodeLevelByNumber(int levelNumber) {
    if (levelNumber >= 1 && levelNumber <= levelCount) {
      final level = decodeLevelAt(levelNumber - 1);
      if (level.id == levelNumber) return level;
    }

    // Fallback scan if IDs are not strictly contiguous 1..N
    for (var i = 0; i < levelCount; i++) {
      final level = decodeLevelAt(i);
      if (level.id == levelNumber) return level;
    }
    return null;
  }

  /// Decodes all levels in the archive.
  List<Level> decodeAll() {
    final result = <Level>[];
    for (var i = 0; i < levelCount; i++) {
      result.add(decodeLevelAt(i));
    }
    return result;
  }

  Level _decodeLevelFromOffset(int offset) {
    var p = offset;
    final id = _byteData.getUint16(p, Endian.big);
    p += 2;
    final rows = _bytes[p++];
    final cols = _bytes[p++];
    final par = _bytes[p++];
    final chapter = _bytes[p++];
    final shapeLen = _bytes[p++];
    final shape = utf8.decode(_bytes.sublist(p, p + shapeLen));
    p += shapeLen;

    final threadCount = _byteData.getUint16(p, Endian.big);
    p += 2;

    final threads = <Thread>[];
    for (var i = 0; i < threadCount; i++) {
      final threadId = _byteData.getUint16(p, Endian.big);
      p += 2;
      final hasColor = _bytes[p++] == 1;
      int? colorGroup;
      if (hasColor) {
        colorGroup = _bytes[p++];
      }
      final cellCount = _byteData.getUint16(p, Endian.big);
      p += 2;

      final cells = <Cell>[];
      for (var c = 0; c < cellCount; c++) {
        final r = _bytes[p++];
        final col = _bytes[p++];
        cells.add(Cell(r, col));
      }
      threads.add(Thread(threadId, cells, colorGroup: colorGroup));
    }

    final deflectorCount = _byteData.getUint16(p, Endian.big);
    p += 2;

    final deflectors = <Deflector>[];
    for (var d = 0; d < deflectorCount; d++) {
      final r = _bytes[p++];
      final c = _bytes[p++];
      final dirIdx = _bytes[p++];
      final dir = Dir.values[dirIdx.clamp(0, Dir.values.length - 1)];
      deflectors.add(Deflector(cell: Cell(r, c), dir: dir));
    }

    return Level(
      id: id,
      rows: rows,
      cols: cols,
      par: par,
      chapter: chapter,
      shape: shape,
      threads: threads,
      deflectors: deflectors,
    );
  }
}
