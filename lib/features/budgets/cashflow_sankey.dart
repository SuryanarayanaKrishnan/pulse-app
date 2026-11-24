import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/flex_budget.dart' show monthKeyFor;
import '../../core/engine/sankey.dart';
import '../../core/icons/category_tint.dart';
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../goals/goal_widgets.dart' show aedMinor;
import 'month_switcher.dart';

/// One month of money in and out, as Sankey inputs plus the payments behind
/// each category (for tap-to-see).
class MonthFlows {
  const MonthFlows(this.incomes, this.spends, this.byCategory);
  final List<FlowItem> incomes;
  final List<FlowItem> spends;
  final Map<String, List<Transaction>> byCategory;

  static MonthFlows of(Iterable<Transaction> txs, DateTime month, List<SpendCategory> cats) {
    final key = monthKeyFor(month);
    final inc = <String, int>{}, out = <String, int>{};
    final by = <String, List<Transaction>>{};
    String label(String id) => cats.where((c) => c.id == id).firstOrNull?.label ?? id;
    for (final t in txs) {
      if (t.excluded || t.category.isTransfer || monthKeyFor(t.date) != key) continue;
      final minor = (t.amount * 100).round();
      final id = t.category.id;
      (t.isIncome ? inc : out)[id] = ((t.isIncome ? inc : out)[id] ?? 0) + minor;
      by.putIfAbsent('${t.isIncome ? 'in' : 'out'}:$id', () => []).add(t);
    }
    for (final l in by.values) {
      l.sort((a, b) => b.date.compareTo(a.date));
    }
    return MonthFlows(
      [for (final e in inc.entries) FlowItem(e.key, label(e.key), e.value)],
      [for (final e in out.entries) FlowItem(e.key, label(e.key), e.value)],
      by,
    );
  }
}

/// Budget > Cash flow: income to categories to what is left, month by month.
class CashflowSankeySection extends ConsumerStatefulWidget {
  const CashflowSankeySection({super.key});
  @override
  ConsumerState<CashflowSankeySection> createState() => _SankeySectionState();
}

class _SankeySectionState extends ConsumerState<CashflowSankeySection> {
  String? _selected; // a node id or a link id

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(budgetMonthProvider);
    final txs = ref.watch(transactionsProvider).value;
    final cats = ref.watch(categoriesProvider).value ?? SpendCategory.defaults;
    return Column(
      key: const Key('sankey_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Where the money flows'),
        MonthSwitcher(
          month: month,
          onChanged: (m) {
            setState(() => _selected = null);
            ref.read(budgetMonthProvider.notifier).set(m);
          },
        ),
        if (txs == null)
          const SizedBox(height: 120)
        else
          SankeyCard(
            flows: MonthFlows.of(txs, month, cats),
            month: month,
            selected: _selected,
            onSelect: (id) => setState(() => _selected = id == _selected ? null : id),
          ),
      ],
    );
  }
}

class SankeyCard extends StatelessWidget {
  const SankeyCard({super.key, required this.flows, required this.month, required this.selected, required this.onSelect});
  final MonthFlows flows;
  final DateTime month;
  final String? selected;
  final ValueChanged<String?> onSelect;

  static const _leftGutter = 78.0, _rightGutter = 104.0, _height = 320.0;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth - Space.gutter * 2;
        final layout = sankeyLayout(
          incomes: flows.incomes,
          spends: flows.spends,
          width: (w - _leftGutter - _rightGutter).clamp(40, 600).toDouble(),
          height: _height - 16,
          nodeWidth: 10,
        );
        if (layout.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
            child: Text(
              'No income or spending in ${DateFormat('MMMM').format(month)} yet.',
              key: const Key('sankey_empty'),
              style: context.tt.bodyMedium,
            ),
          );
        }
        final dark = c.isDark;
        Color tint(SankeyNode n) => switch (n.kind) {
          SankeyKind.saved => c.positive,
          SankeyKind.deficit => c.warning,
          SankeyKind.other => c.textTertiary,
          _ => categoryTint(categoryTokenFor(n.id), dark: dark),
        };
        final colors = {for (final n in layout.nodes) n.id: tint(n)};
        final spent = layout.nodes.where((n) => n.column == 1 && n.kind != SankeyKind.saved).fold(0, (a, n) => a + n.valueMinor);
        final saved = layout.nodes.where((n) => n.kind == SankeyKind.saved).fold(0, (a, n) => a + n.valueMinor);
        final painter = _SankeyPainter(
          layout: layout,
          colors: colors,
          selected: selected,
          dark: dark,
          textColor: c.textPrimary,
          mutedColor: c.textSecondary,
          leftGutter: _leftGutter,
          style: context.tt.bodySmall!,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
              child: Semantics(
                label:
                    'Cash flow for ${DateFormat('MMMM').format(month)}: ${aedMinor(layout.totalMinor)} in, ${aedMinor(spent)} spent, ${aedMinor(saved)} saved. Tap a flow to see its payments.',
                child: GestureDetector(
                  key: const Key('sankey_canvas'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => onSelect(painter.hit(d.localPosition)),
                  child: CustomPaint(size: Size(w, _height), painter: painter),
                ),
              ),
            ),
            if (selected != null) _FlowDetail(layout: layout, flows: flows, selected: selected!, colors: colors),
          ],
        );
      },
    );
  }
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter({
    required this.layout,
    required this.colors,
    required this.selected,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
    required this.leftGutter,
    required this.style,
  });
  final SankeyLayout layout;
  final Map<String, Color> colors;
  final String? selected;
  final bool dark;
  final Color textColor, mutedColor;
  final double leftGutter;
  final TextStyle style;

  static const _top = 8.0;

  Path _ribbon(SankeyLink k) {
    final s = layout.node(k.sourceId), t = layout.node(k.targetId);
    final x0 = s.x + s.width, x1 = t.x;
    final mx = (x0 + x1) / 2;
    return Path()
      ..moveTo(x0, k.sourceY)
      ..cubicTo(mx, k.sourceY, mx, k.targetY, x1, k.targetY)
      ..lineTo(x1, k.targetY + k.targetHeight)
      ..cubicTo(mx, k.targetY + k.targetHeight, mx, k.sourceY + k.sourceHeight, x0, k.sourceY + k.sourceHeight)
      ..close();
  }

  /// The node id or link id at [p], else null.
  String? hit(Offset p) {
    final q = p - Offset(leftGutter, _top);
    // The bar and a small margin; labels sit outside and do not count.
    for (final n in layout.nodes) {
      if (Rect.fromLTWH(n.x - 12, n.y - 3, n.width + 24, n.height + 6).contains(q)) return n.id;
    }
    for (final k in layout.links) {
      if (_ribbon(k).contains(q)) return k.id;
    }
    return null;
  }

  bool _on(String id, SankeyLink? k) {
    if (selected == null) return true;
    if (k != null) return selected == k.id || selected == k.sourceId || selected == k.targetId;
    return selected == id || layout.links.any((l) => l.id == selected && (l.sourceId == id || l.targetId == id));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(leftGutter, _top);
    for (final k in layout.links) {
      final active = _on('', k);
      final tint = colors[k.targetId] ?? mutedColor;
      final base = dark ? 0.34 : 0.26;
      canvas.drawPath(
        _ribbon(k),
        Paint()..color = tint.withValues(alpha: selected == null ? base : (active ? base + 0.26 : 0.07)),
      );
    }
    final bar = Paint();
    for (final n in layout.nodes) {
      bar.color = (colors[n.id] ?? mutedColor).withValues(alpha: _on(n.id, null) ? 1 : 0.3);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(n.x, n.y, n.width, n.height), const Radius.circular(3)), bar);
    }
    // Labels outside the bars; nudged apart so they never sit on each other.
    for (final col in [0, 1]) {
      final ns = layout.nodes.where((n) => n.column == col).toList()..sort((a, b) => a.y.compareTo(b.y));
      var minY = -_top;
      for (final n in ns) {
        var y = n.y + n.height / 2 - 14;
        if (y < minY) y = minY;
        minY = y + 30;
        final active = _on(n.id, null);
        final name = TextPainter(
          text: TextSpan(text: n.label, style: style.copyWith(color: textColor.withValues(alpha: active ? 1 : 0.45), fontWeight: FontWeight.w500, fontSize: 12)),
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: col == 0 ? leftGutter - 14 : 104 - 14);
        final amt = TextPainter(
          text: TextSpan(text: aedMinor(n.valueMinor), style: style.copyWith(color: mutedColor.withValues(alpha: active ? 1 : 0.45), fontSize: 11)),
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: col == 0 ? leftGutter - 14 : 104 - 14);
        final x = col == 0 ? n.x - 6 - name.width : n.x + n.width + 6;
        final xa = col == 0 ? n.x - 6 - amt.width : n.x + n.width + 6;
        name.paint(canvas, Offset(x, y));
        amt.paint(canvas, Offset(xa, y + 15));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SankeyPainter o) =>
      o.layout != layout || o.selected != selected || o.dark != dark || o.textColor != textColor;
}

/// What is behind a tapped flow: the payments of that category.
class _FlowDetail extends StatelessWidget {
  const _FlowDetail({required this.layout, required this.flows, required this.selected, required this.colors});
  final SankeyLayout layout;
  final MonthFlows flows;
  final String selected;
  final Map<String, Color> colors;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final link = layout.links.where((l) => l.id == selected).firstOrNull;
    final node = layout.nodes.where((n) => n.id == (link?.targetId ?? selected)).firstOrNull;
    final src = link == null ? null : layout.nodes.where((n) => n.id == link.sourceId).firstOrNull;
    if (node == null) return const SizedBox.shrink();
    final isIncomeNode = node.column == 0;
    final dir = isIncomeNode ? 'in' : 'out';
    final txs = [
      for (final id in node.members)
        ...?flows.byCategory['$dir:$id'],
    ]..sort((a, b) => b.date.compareTo(a.date));
    final virtual = node.kind == SankeyKind.saved || node.kind == SankeyKind.deficit;
    final title = link != null && src != null && !virtual
        ? '${src.label} to ${node.label}'
        : node.label;
    final amount = link?.valueMinor ?? node.valueMinor;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        key: const Key('flow_detail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(
              children: [
                Dot(colors[node.id] ?? c.textTertiary),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(title, style: context.tt.titleSmall)),
                Text(aedMinor(amount), style: PulseTheme.amount(c.textPrimary, size: 15)),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          if (virtual)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(
                node.kind == SankeyKind.saved
                    ? 'What was left of your income after everything you spent.'
                    : 'You spent more than came in, so the difference came out of savings.',
                style: context.tt.bodySmall,
              ),
            )
          else if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text('No payments to show.', style: context.tt.bodySmall),
            )
          else
            RowGroup(
              indent: Space.gutter,
              children: [
                for (final t in txs.take(6))
                  ListRow(
                    dense: true,
                    title: t.merchant,
                    subtitle: DateFormat('d MMM').format(t.date),
                    trailing: Text(aedMinor((t.amount * 100).round()), style: PulseTheme.amount(c.textPrimary, size: 15)),
                  ),
                if (txs.length > 6 && node.members.length == 1)
                  ListRow(
                    dense: true,
                    title: 'All ${txs.length} payments',
                    chevron: true,
                    onTap: () => context.push('${Routes.activity}?category=${node.members.first}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
