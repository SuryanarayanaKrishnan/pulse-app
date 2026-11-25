import 'package:material_ui/material_ui.dart';
import '../../core/router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'tx_detail_sheet.dart';
import 'tx_tile.dart';

/// Drill-down list of all transactions (reached from Home and Budget).
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.initialCategory});
  final String? initialCategory;
  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _search = TextEditingController();
  late String? _catId = widget.initialCategory;
  bool _manualOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE d MMMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final txs = ref.watch(transactionsProvider);
    final all = txs.value ?? const <Transaction>[];
    // Only categories that actually occur, in the default order.
    final cats = ref.watch(categoriesProvider).value ?? SpendCategory.defaults;
    final used = {for (final t in all) t.category};
    final chips = [
      for (final x in cats)
        if (used.contains(x)) x,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
        actions: [
          // Manual entry is intentionally a small overflow action.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (v) {
              if (v == 'manual') {
                showPulseSheet<void>(
                  context,
                  builder: (_) => const AddManualTxSheet(),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'manual', child: Text('Add cash expense')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search_rounded, color: c.textTertiary),
              ),
            ),
          ),
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.gutter,
                vertical: Space.md,
              ),
              children: [
                Pill(
                  'All',
                  selected: _catId == null && !_manualOnly,
                  onTap: () => setState(() {
                    _catId = null;
                    _manualOnly = false;
                  }),
                ),
                const SizedBox(width: Space.sm),
                Pill(
                  'Manual',
                  selected: _manualOnly,
                  onTap: () => setState(() => _manualOnly = !_manualOnly),
                ),
                for (final cat in chips) ...[
                  const SizedBox(width: Space.sm),
                  Pill(
                    cat.label,
                    selected: _catId == cat.id,
                    onTap: () => setState(
                      () => _catId = _catId == cat.id ? null : cat.id,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: AsyncView<List<Transaction>>(
              value: txs,
              onRetry: () => ref.invalidate(transactionsProvider),
              builder: (list) {
                final q = _search.text.trim().toLowerCase();
                final f = list.where((t) {
                  if (_catId != null && t.category.id != _catId) return false;
                  if (_manualOnly && t.source.automatic) return false;
                  return q.isEmpty || t.merchant.toLowerCase().contains(q);
                }).toList();
                if (f.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_rounded,
                    title: 'No transactions',
                    message: 'Try a different search or filter.',
                  );
                }
                final groups = <String, List<Transaction>>{};
                for (final t in f) {
                  groups.putIfAbsent(_dayLabel(t.date), () => []).add(t);
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: Space.xxxl),
                  children: [
                    for (final e in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.gutter,
                          Space.lg,
                          Space.gutter,
                          0,
                        ),
                        child: Text(e.key, style: context.tt.bodySmall),
                      ),
                      RowGroup(
                        indent: ListRow.leadingInset,
                        children: [
                          for (final t in e.value)
                            TxTile(
                              t,
                              onTap: () => showPulseSheet<void>(
                                context,
                                builder: (_) => TxDetailSheet(tx: t),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
