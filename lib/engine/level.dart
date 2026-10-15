import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/deflector.dart';
import 'package:arrowtapout/engine/thread.dart';

/// Immutable representation of a puzzle level.
class Level {
  Level({
    required this.id,
    required this.rows,
    required this.cols,
    required List<Thread> threads,
    this.shape = 'rect',
    this.par = 0,
    int? chapter,
    List<Deflector> deflectors = const [],
  })  : threads = List.unmodifiable(threads),
        deflectors = List.unmodifiable(deflectors),
        chapter = chapter ?? ((id - 1) ~/ 20 + 1);

  final int id;
  final int rows;
  final int cols;
  final String shape;
  final int par;
  final int chapter;
  final List<Thread> threads;
  final List<Deflector> deflectors;

  /// Number of threads in this level.
  int get threadCount => threads.length;

  /// Creates a [Level] from parsed JSON map (supports both standard and conveyor format).
  factory Level.fromJson(Map<String, dynamic> json, {int? chapter}) {
    if (json.containsKey('GridXSize') && json.containsKey('Arrows')) {
      final rows = json['GridYSize'] as int;
      final cols = json['GridXSize'] as int;
      final rawArrows = json['Arrows'] as List<dynamic>;

      final threads = <Thread>[];
      for (var i = 0; i < rawArrows.length; i++) {
        final arrowMap = rawArrows[i] as Map<String, dynamic>;
        final rawIndices = arrowMap['Indices'] as List<dynamic>;
        final cells = rawIndices.map((idx) {
          final cellIdx = idx as int;
          return Cell(cellIdx ~/ cols, cellIdx % cols);
        }).toList(growable: false);
        threads.add(Thread(i + 1, cells));
      }

      return Level(
        id: (json['id'] as int?) ?? 999,
        rows: rows,
        cols: cols,
        threads: threads,
        shape: 'conveyor',
        chapter: chapter ?? 1,
      );
    }

    final id = json['id'] as int;
    final rows = json['rows'] as int;
    final cols = json['cols'] as int;
    final shape = (json['shape'] as String?) ?? 'rect';
    final par = (json['par'] as int?) ?? 0;
    final rawThreads = json['threads'] as List<dynamic>;

    final threads = <Thread>[];
    for (var i = 0; i < rawThreads.length; i++) {
      final raw = rawThreads[i];
      if (raw is Map<String, dynamic>) {
        final rawCoords = raw['cells'] as List<dynamic>;
        final cells = rawCoords.map((coord) {
          final pair = coord as List<dynamic>;
          return Cell(pair[0] as int, pair[1] as int);
        }).toList(growable: false);
        final colorGroup = raw['colorGroup'] as int?;
        threads.add(Thread(i + 1, cells, colorGroup: colorGroup));
      } else {
        final rawCoords = raw as List<dynamic>;
        final cells = rawCoords.map((coord) {
          final pair = coord as List<dynamic>;
          return Cell(pair[0] as int, pair[1] as int);
        }).toList(growable: false);
        threads.add(Thread(i + 1, cells));
      }
    }

    final deflectors = <Deflector>[];
    if (json.containsKey('deflectors')) {
      final rawDeflectors = json['deflectors'] as List<dynamic>;
      for (final raw in rawDeflectors) {
        deflectors.add(Deflector.fromJson(raw as Map<String, dynamic>));
      }
    }

    return Level(
      id: id,
      rows: rows,
      cols: cols,
      threads: threads,
      shape: shape,
      par: par,
      chapter: chapter,
      deflectors: deflectors,
    );
  }

  /// Serializes level data to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rows': rows,
      'cols': cols,
      'shape': shape,
      'par': par,
      'threads': threads.map((t) {
        if (t.colorGroup != null) {
          return {
            'colorGroup': t.colorGroup,
            'cells': t.cells.map((c) => [c.r, c.c]).toList(growable: false),
          };
        }
        return t.cells.map((c) => [c.r, c.c]).toList(growable: false);
      }).toList(growable: false),
      if (deflectors.isNotEmpty)
        'deflectors': deflectors.map((d) => d.toJson()).toList(growable: false),
    };
  }

  @override
  String toString() =>
      'Level#$id (${rows}x$cols, shape: $shape, threads: ${threads.length})';
}
