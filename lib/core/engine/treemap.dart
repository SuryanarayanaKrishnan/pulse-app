/// Squarified treemap layout (Bruls, Huizing, van Wijk). Pure geometry: the
/// painter and the tests both use it. Tiles never overlap and their areas
/// are proportional to their values.
library;

import 'dart:math' as math;

class TreemapInput {
  const TreemapInput(this.id, this.value);
  final String id;
  final double value;
}

class TreemapTile {
  const TreemapTile(
    this.id,
    this.value,
    this.left,
    this.top,
    this.width,
    this.height,
  );
  final String id;
  final double value, left, top, width, height;
  double get right => left + width;
  double get bottom => top + height;
  double get area => width * height;
}

/// Lays [items] out in a [width] x [height] box, largest first. Items with a
/// value of zero or less are left out.
List<TreemapTile> layoutTreemap(
  List<TreemapInput> items,
  double width,
  double height,
) {
  final list = [
    for (final i in items)
      if (i.value > 0) i,
  ]..sort((a, b) => b.value.compareTo(a.value));
  if (list.isEmpty || width <= 0 || height <= 0) return const [];
  final total = list.fold(0.0, (a, i) => a + i.value);
  final scale = width * height / total;
  final out = <TreemapTile>[];
  var x = 0.0, y = 0.0, w = width, h = height;
  var row = <TreemapInput>[];

  double worst(List<TreemapInput> r, double side) {
    final s = r.fold(0.0, (a, i) => a + i.value * scale);
    final maxA = r.map((i) => i.value * scale).reduce(math.max);
    final minA = r.map((i) => i.value * scale).reduce(math.min);
    return math.max(side * side * maxA / (s * s), s * s / (side * side * minA));
  }

  void flush() {
    if (row.isEmpty) return;
    final s = row.fold(0.0, (a, i) => a + i.value * scale);
    if (w >= h) {
      // Column on the left, tiles stacked down it.
      final cw = s / h;
      var cy = y;
      for (final i in row) {
        final th = i.value * scale / cw;
        out.add(TreemapTile(i.id, i.value, x, cy, cw, th));
        cy += th;
      }
      x += cw;
      w -= cw;
    } else {
      final rh = s / w;
      var cx = x;
      for (final i in row) {
        final tw = i.value * scale / rh;
        out.add(TreemapTile(i.id, i.value, cx, y, tw, rh));
        cx += tw;
      }
      y += rh;
      h -= rh;
    }
    row = [];
  }

  for (final item in list) {
    final side = math.min(w, h);
    if (row.isEmpty || worst([...row, item], side) <= worst(row, side)) {
      row.add(item);
    } else {
      flush();
      row.add(item);
    }
  }
  flush();
  return out;
}
