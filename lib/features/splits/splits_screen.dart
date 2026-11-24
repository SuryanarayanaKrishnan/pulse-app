import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/splits_util.dart';
import 'split_widgets.dart';
import '../tour/tab_tip.dart';
import '../tour/tour_progress.dart';

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
                TabTip(
                  tab: TipTab.splits,
                  child: RoundIconButton(
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
                ),
              ],
            ),
            AsyncView<List<SplitGroup>>(
              value: groups,
              onRetry: () => ref.invalidate(splitGroupsProvider),
              loading: const SkeletonList(rows: 3, height: 64),
              builder: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No groups yet',
                    message: 'Create a group to split bills with friends.',
                  );
                }
                return _Body(list);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.groups);
  final List<SplitGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final (owed, owe) = myTotals(groups);
    final net = owed - owe;
    // Payments others say they made to you, waiting on you.
    final toConfirm = [
      for (final g in groups)
        for (final s in g.settlements)
          if (s.to == 'me' && s.status == SettlementStatus.awaitingConfirmation)
            (g, s),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroNumber(
          label: net.abs() < 0.01
              ? 'All settled'
              : (net > 0 ? 'You are owed' : 'You owe'),
          value: net.abs(),
          color: net > 0.005 ? c.positive : null,
          caption:
              '${Money.aed(owed, decimals: false)} owed to you · ${Money.aed(owe, decimals: false)} you owe',
        ),
        if (toConfirm.isNotEmpty) ...[
          const SectionHeader('Needs you'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              for (final (g, s) in toConfirm)
                ListRow(
                  leading: MemberAvatar(g.member(s.from)),
                  title:
                      '${g.member(s.from)?.name ?? 'Someone'} paid you ${Money.aed(s.amount)}',
                  subtitle: 'Via Aani · ${g.name}',
                  trailing: TextAction(
                    'Confirm',
                    onTap: () => confirmReceived(context, ref, g, s),
                  ),
                ),
            ],
          ),
        ],
        const SectionHeader('Groups'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            for (final g in groups)
              Builder(
                builder: (context) {
                  final mine = groupBalances(g)['me'] ?? 0;
                  final settled = mine.abs() < 0.01;
                  return ListRow(
                    leading: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        g.emoji,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    title: g.name,
                    subtitle:
                        '${g.members.length} people · ${Money.aed(g.total, decimals: false)}',
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          settled ? 'Settled' : Money.aed(mine.abs()),
                          style: PulseTheme.amount(
                            settled
                                ? c.textSecondary
                                : (mine > 0 ? c.positive : c.textPrimary),
                          ),
                        ),
                        if (!settled)
                          Text(
                            mine > 0 ? 'owed to you' : 'you owe',
                            style: context.tt.bodySmall,
                          ),
                      ],
                    ),
                    chevron: true,
                    onTap: () => context.push('${Routes.group}/${g.id}'),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class AddSplitSheet extends ConsumerStatefulWidget {
  const AddSplitSheet({super.key, required this.groups, this.initial});
  final List<SplitGroup> groups;
  final SplitGroup? initial;
  @override
  ConsumerState<AddSplitSheet> createState() => _AddSplitSheetState();
}

class _AddSplitSheetState extends ConsumerState<AddSplitSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  late SplitGroup _group = widget.initial ?? widget.groups.first;
  late Set<String> _with = _group.members.map((m) => m.id).toSet();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', ''));
    if (amt == null ||
        amt <= 0 ||
        _title.text.trim().isEmpty ||
        _with.isEmpty) {
      return;
    }
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
    subtitle: 'You paid. Split equally.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.groups.length > 1) ...[
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final g in widget.groups)
                Pill(
                  g.name,
                  selected: g.id == _group.id,
                  onTap: () => setState(() {
                    _group = g;
                    _with = g.members.map((m) => m.id).toSet();
                  }),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
        ],
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
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
        const SizedBox(height: Space.xl),
        Text('Split between', style: context.tt.bodySmall),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final m in _group.members)
              Pill(
                m.name,
                selected: _with.contains(m.id),
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
