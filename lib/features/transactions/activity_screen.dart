import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  SpendCategory? _cat;
  bool _autoOnly = false;

  @override
  void initState() {
    super.initState();
    _cat = SpendCategory.values
        .where((c) => c.name == widget.initialCategory)
        .firstOrNull;
  }

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
    return DateFormat('EEEE, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final txs = ref.watch(transactionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Manual entry is intentionally a small overflow action, never a primary CTA.
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, color: c.textSecondary),
            color: c.surfaceElevated,
            onSelected: (v) {
              if (v == 'manual')
                showPulseSheet<void>(
                  context,
                  builder: (_) => const AddManualTxSheet(),
                );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'manual',
                child: Text('Add cash expense manually'),
              ),
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
                hintText: 'Search merchants',
                prefixIcon: Icon(Icons.search_rounded, color: c.textTertiary),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.gutter,
                vertical: 10,
              ),
              children: [
                Pill(
                  'Automatic',
                  icon: Icons.bolt_rounded,
                  selected: _autoOnly,
                  color: c.accentAlt,
                  onTap: () => setState(() => _autoOnly = !_autoOnly),
                ),
                for (final cat in SpendCategory.values) ...[
                  const SizedBox(width: 8),
                  Pill(
                    cat.label,
                    icon: cat.icon,
                    color: cat.color,
                    selected: _cat == cat,
                    onTap: () =>
                        setState(() => _cat = _cat == cat ? null : cat),
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
                  if (_cat != null && t.category != _cat) return false;
                  if (_autoOnly && !t.source.automatic) return false;
                  return q.isEmpty || t.merchant.toLowerCase().contains(q);
                }).toList();
                if (f.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No transactions',
                    message: 'Try a different search or filter.',
                  );
                }
                final groups = <String, List<Transaction>>{};
                for (final t in f) {
                  groups.putIfAbsent(_dayLabel(t.date), () => []).add(t);
                }
                var i = 0;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    40,
                  ),
                  children: [
                    for (final e in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Space.lg,
                          bottom: 4,
                        ),
                        child: Text(
                          e.key.toUpperCase(),
                          style: context.tt.labelSmall,
                        ),
                      ),
                      for (final t in e.value)
                        TxTile(
                              t,
                              onTap: () => showPulseSheet<void>(
                                context,
                                builder: (_) => TxDetailSheet(tx: t),
                              ),
                            )
                            .animate(delay: stagger((i++).clamp(0, 10)))
                            .fadeIn(duration: 350.ms)
                            .slideY(
                              begin: 0.15,
                              end: 0,
                              curve: Curves.easeOutCubic,
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
