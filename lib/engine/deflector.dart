import 'package:arrowtapout/engine/cell.dart';
import 'package:arrowtapout/engine/dir.dart';

/// An empty grid cell that acts as a direction deflector in the exit path.
class Deflector {
  const Deflector({
    required this.cell,
    required this.dir,
  });

  /// The location of the deflector on the grid.
  final Cell cell;

  /// The redirected direction forced upon any arrow passing through this cell.
  final Dir dir;

  Map<String, dynamic> toJson() => {
        'r': cell.r,
        'c': cell.c,
        'dir': dir.name,
      };

  factory Deflector.fromJson(Map<String, dynamic> json) {
    final r = json['r'] as int;
    final c = json['c'] as int;
    final dirStr = json['dir'] as String;
    final dir = Dir.values.firstWhere(
      (d) => d.name == dirStr,
      orElse: () => Dir.up,
    );
    return Deflector(cell: Cell(r, c), dir: dir);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Deflector &&
          runtimeType == other.runtimeType &&
          cell == other.cell &&
          dir == other.dir;

  @override
  int get hashCode => Object.hash(cell, dir);

  @override
  String toString() => 'Deflector(cell: $cell, dir: $dir)';
}
