/// Layout for the cash-flow Sankey: income on the left, categories and what
/// was saved on the right. Pure geometry plus exact integer flows; the
/// widget only paints what this returns.
///
/// Guarantees (covered by tests): flows are whole minor units and add up
/// exactly on both sides of every node; nodes in a column never overlap and
/// stay inside the box; every node is at least [minNodeHeight] tall; ribbons
/// never cross (flows are laid out in column order).
library;

enum SankeyKind { income, deficit, category, other, saved }

/// One source of income or one category of spending.
class FlowItem {
  const FlowItem(this.id, this.label, this.amountMinor);
  final String id;
  final String label;
  final int amountMinor;
}

class SankeyNode {
  const SankeyNode({
    required this.id,
    required this.label,
    required this.kind,
    required this.column,
    required this.valueMinor,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.members = const [],
  });
  final String id;
  final String label;
  final SankeyKind kind;

  /// 0 = left (income), 1 = right (spending and saved).
  final int column;
  final int valueMinor;
  final double x, y, width, height;

  /// The original ids behind a grouped "Other" node (else just [id]).
  final List<String> members;

  double get bottom => y + height;
}

class SankeyLink {
  const SankeyLink({
    required this.sourceId,
    required this.targetId,
    required this.valueMinor,
    required this.sourceY,
    required this.sourceHeight,
    required this.targetY,
    required this.targetHeight,
  });
  final String sourceId, targetId;
  final int valueMinor;
  final double sourceY, sourceHeight, targetY, targetHeight;
  String get id => '$sourceId>$targetId';
}

class SankeyLayout {
  const SankeyLayout(this.nodes, this.links, this.width, this.height);
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;
  final double width, height;
  bool get isEmpty => nodes.isEmpty;
  int get totalMinor => nodes.where((n) => n.column == 0).fold(0, (a, n) => a + n.valueMinor);

  SankeyNode node(String id) => nodes.firstWhere((n) => n.id == id);
}

const sankeyOtherId = '_other';
const sankeySavedId = '_saved';
const sankeyDeficitId = '_deficit';

/// Keeps the largest [max] - 1 items and folds the rest into one "Other".
List<(FlowItem, List<String>)> _fold(List<FlowItem> items, int max) {
  final sorted = [
    for (final i in items)
      if (i.amountMinor > 0) i,
  ]..sort((a, b) {
      final c = b.amountMinor.compareTo(a.amountMinor);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
  if (sorted.length <= max) return [for (final i in sorted) (i, [i.id])];
  final keep = sorted.take(max - 1).toList();
  final rest = sorted.skip(max - 1).toList();
  return [
    for (final i in keep) (i, [i.id]),
    (
      FlowItem(sankeyOtherId, 'Other', rest.fold(0, (a, i) => a + i.amountMinor)),
      [for (final i in rest) i.id],
    ),
  ];
}

/// Heights for [values] stacked in [avail] pixels, none under [minH].
List<double> _heights(List<int> values, double avail, double minH) {
  final n = values.length;
  if (n == 0) return [];
  final floor = avail / n < minH ? avail / n : minH;
  final fixed = List<bool>.filled(n, false);
  var s = 0.0;
  for (var round = 0; round <= n; round++) {
    var rest = avail, sum = 0;
    for (var i = 0; i < n; i++) {
      if (fixed[i]) {
        rest -= floor;
      } else {
        sum += values[i];
      }
    }
    s = sum == 0 ? 0 : rest / sum;
    var changed = false;
    for (var i = 0; i < n; i++) {
      if (!fixed[i] && values[i] * s < floor) {
        fixed[i] = true;
        changed = true;
      }
    }
    if (!changed) break;
  }
  return [for (var i = 0; i < n; i++) fixed[i] ? floor : values[i] * s];
}

SankeyLayout sankeyLayout({
  required List<FlowItem> incomes,
  required List<FlowItem> spends,
  required double width,
  required double height,
  double nodeWidth = 10,
  double gap = 8,
  double minNodeHeight = 6,
  int maxPerColumn = 7,
  String savedLabel = 'Saved',
  String deficitLabel = 'From savings',
}) {
  final left = _fold(incomes, maxPerColumn);
  final right = _fold(spends, maxPerColumn);
  final inTotal = left.fold(0, (a, e) => a + e.$1.amountMinor);
  final outTotal = right.fold(0, (a, e) => a + e.$1.amountMinor);
  if (inTotal == 0 && outTotal == 0) return SankeyLayout(const [], const [], width, height);

  final lItems = <(String, String, SankeyKind, int, List<String>)>[
    for (final e in left)
      (e.$1.id, e.$1.label, e.$1.id == sankeyOtherId ? SankeyKind.other : SankeyKind.income, e.$1.amountMinor, e.$2),
  ];
  final rItems = <(String, String, SankeyKind, int, List<String>)>[
    for (final e in right)
      (e.$1.id, e.$1.label, e.$1.id == sankeyOtherId ? SankeyKind.other : SankeyKind.category, e.$1.amountMinor, e.$2),
  ];
  if (outTotal > inTotal) {
    lItems.add((sankeyDeficitId, deficitLabel, SankeyKind.deficit, outTotal - inTotal, [sankeyDeficitId]));
  } else if (inTotal > outTotal) {
    rItems.add((sankeySavedId, savedLabel, SankeyKind.saved, inTotal - outTotal, [sankeySavedId]));
  }

  // The "Other" ids of the two columns must differ.
  String idOf(int col, String id) => id == sankeyOtherId ? '${sankeyOtherId}_$col' : id;

  List<SankeyNode> place(List<(String, String, SankeyKind, int, List<String>)> items, int col, double x) {
    final heights = _heights(
      [for (final i in items) i.$4],
      height - gap * (items.length - 1),
      minNodeHeight,
    );
    final used = heights.fold(0.0, (a, h) => a + h) + gap * (items.length - 1);
    var y = (height - used) / 2;
    final out = <SankeyNode>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      out.add(
        SankeyNode(
          id: idOf(col, it.$1),
          label: it.$2,
          kind: it.$3,
          column: col,
          valueMinor: it.$4,
          x: x,
          y: y,
          width: nodeWidth,
          height: heights[i],
          members: it.$5,
        ),
      );
      y += heights[i] + gap;
    }
    return out;
  }

  final ln = place(lItems, 0, 0);
  final rn = place(rItems, 1, width - nodeWidth);

  // Flows run in column order (north-west corner), so ribbons cannot cross
  // and every sum is exact.
  final links = <SankeyLink>[];
  final lRest = [for (final n in ln) n.valueMinor];
  final rRest = [for (final n in rn) n.valueMinor];
  final lCursor = [for (final n in ln) n.y];
  final rCursor = [for (final n in rn) n.y];
  var i = 0, j = 0;
  while (i < ln.length && j < rn.length) {
    final v = lRest[i] < rRest[j] ? lRest[i] : rRest[j];
    if (v > 0) {
      final sh = v * ln[i].height / ln[i].valueMinor;
      final th = v * rn[j].height / rn[j].valueMinor;
      links.add(
        SankeyLink(
          sourceId: ln[i].id,
          targetId: rn[j].id,
          valueMinor: v,
          sourceY: lCursor[i],
          sourceHeight: sh,
          targetY: rCursor[j],
          targetHeight: th,
        ),
      );
      lCursor[i] += sh;
      rCursor[j] += th;
      lRest[i] -= v;
      rRest[j] -= v;
    }
    if (lRest[i] == 0) i++;
    if (j < rn.length && rRest[j] == 0) j++;
  }
  return SankeyLayout([...ln, ...rn], links, width, height);
}
