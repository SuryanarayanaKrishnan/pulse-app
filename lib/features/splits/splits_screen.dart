import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/splits_util.dart';

class SplitsScreen extends ConsumerWidget {
  const SplitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(splitGroupsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            ScreenHeader(
              'Splits',
              subtitle: 'Shared expenses',
              trailing: [
                RoundIconButton(
                  icon: Icons.add_rounded,
                  label: 'Add expense',
                  onTap: () {
                    final list = groups.value;
                    if (list != null && list.isNotEmpty) {
                      showPulseSheet<void>(
                        context,
                        full: true,
                        builder: (_) => AddSplitSheet(groups: list),
                      );
                    }
                  },
                ),
              ],
            ),
            AsyncView<List<SplitGroup>>(
              value: groups,
              onRetry: () => ref.invalidate(splitGroupsProvider),
              loading: const SkeletonList(rows: 3, height: 120),
              builder: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.group_add_rounded,
                    title: 'No groups yet',
                    message: 'Create a group to split bills with friends.',
                  );
                }
                var owed = 0.0, owe = 0.0;
                for (final g in list) {
                  final v = computeBalances(g.expenses, g.members)['me'] ?? 0;
                  if (v > 0) {
                    owed += v;
                  } else {
                    owe -= v;
                  }
                }
                return Column(
                  children: [
                    _Summary(owed: owed, owe: owe),
                    const SizedBox(height: Space.lg),
                    for (var i = 0; i < list.length; i++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.gutter,
                          0,
                          Space.gutter,
                          Space.md,
                        ),
                        child: _GroupCard(list[i])
                            .animate(delay: stagger(i))
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.08),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.owed, required this.owe});
  final double owed;
  final double owe;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: screenPad,
      child: GlassCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOU ARE OWED', style: context.tt.labelSmall),
                  const SizedBox(height: 6),
                  AmountText(owed, size: 24, color: c.positive),
                ],
              ),
            ),
            Container(width: 1, height: 44, color: c.border),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOU OWE', style: context.tt.labelSmall),
                  const SizedBox(height: 6),
                  AmountText(owe, size: 24, color: c.negative),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard(this.g);
  final SplitGroup g;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final bal = computeBalances(g.expenses, g.members);
    final mine = bal['me'] ?? 0;
    final plan = simplifyDebts(bal);
    String name(String id) => g.members.firstWhere((m) => m.id == id).name;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(g.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name, style: context.tt.titleMedium),
                    Text(
                      '${g.expenses.length} expenses · ${Money.aed(g.total, decimals: false)}',
                      style: context.tt.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    mine >= 0 ? 'you are owed' : 'you owe',
                    style: context.tt.bodySmall,
                  ),
                  Text(
                    Money.aed(mine.abs()),
                    style: PulseTheme.amount(
                      mine >= 0 ? c.positive : c.negative,
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            height: 32,
            child: Stack(
              children: [
                for (var i = 0; i < g.members.length; i++)
                  Positioned(
                    left: i * 22.0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: c.surface,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: g.members[i].color,
                        child: Text(
                          g.members[i].initial,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (plan.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            for (final s in plan)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${name(s.from)} pays ${name(s.to)}',
                        style: context.tt.bodyMedium,
                      ),
                    ),
                    Text(Money.aed(s.amount), style: context.tt.labelMedium),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class AddSplitSheet extends ConsumerStatefulWidget {
  const AddSplitSheet({super.key, required this.groups});
  final List<SplitGroup> groups;
  @override
  ConsumerState<AddSplitSheet> createState() => _AddSplitSheetState();
}

class _AddSplitSheetState extends ConsumerState<AddSplitSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  late SplitGroup _group = widget.groups.first;
  late Set<String> _with = _group.members.map((m) => m.id).toSet();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text);
    if (amt == null || amt <= 0 || _title.text.trim().isEmpty || _with.isEmpty)
      return;
    await ref
        .read(repositoryProvider)
        .addSplitExpense(
          _group.id,
          SplitExpense(
            id: 'new${DateTime.now().microsecondsSinceEpoch}',
            title: _title.text.trim(),
            paidBy: 'me',
            amount: amt,
            participants: _with.toList(),
            date: DateTime.now(),
          ),
        );
    ref.read(analyticsProvider).track(AnalyticsEvent.splitExpenseAdded);
    ref.invalidate(splitGroupsProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Add expense',
    subtitle: 'You paid. Split equally between:',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final g in widget.groups)
              Pill(
                '${g.emoji} ${g.name}',
                selected: g.id == _group.id,
                onTap: () => setState(() {
                  _group = g;
                  _with = g.members.map((m) => m.id).toSet();
                }),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _title,
          decoration: const InputDecoration(hintText: 'What was it for?'),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Amount',
            prefixText: 'AED  ',
          ),
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _group.members)
              Pill(
                m.name,
                selected: _with.contains(m.id),
                color: m.color,
                onTap: () => setState(
                  () => _with.contains(m.id)
                      ? _with.remove(m.id)
                      : _with.add(m.id),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Add expense', onPressed: _save),
      ],
    ),
  );
}
