import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/splits_util.dart';
import 'split_widgets.dart';
import 'splits_screen.dart';

/// One group: your balance, who owes whom (with Aani status), expenses.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(splitGroupsProvider);
    final g = groups.value?.where((x) => x.id == groupId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(g?.name ?? ''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (g != null)
            IconButton(
              tooltip: 'Add expense',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => showPulseSheet<void>(
                context,
                full: true,
                builder: (_) =>
                    AddSplitSheet(groups: groups.value!, initial: g),
              ),
            ),
        ],
      ),
      body: g == null
          ? (groups.isLoading
                ? const SkeletonList(rows: 4)
                : const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'Group not found',
                    message: 'It may have been deleted.',
                  ))
          : _Body(g),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.g);
  final SplitGroup g;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final bal = groupBalances(g);
    final mine = bal['me'] ?? 0;
    final plan = simplifyDebts(bal);
    final others = g.members.where((m) => m.id != 'me').toList();

    Widget memberRow(Member m) {
      final iOwe = plan
          .where((s) => s.from == 'me' && s.to == m.id)
          .firstOrNull;
      final owesMe = plan
          .where((s) => s.from == m.id && s.to == 'me')
          .firstOrNull;
      String subtitle;
      Color? subColor;
      Widget? trailing;
      if (iOwe != null) {
        final pending = pendingSettlement(g, 'me', m.id);
        if (pending != null) {
          subtitle =
              'You paid ${Money.aed(pending.amount)} via Aani · waiting for ${m.name}';
          subColor = c.textSecondary;
        } else {
          subtitle = 'You owe ${Money.aed(iOwe.amount)}';
          trailing = TextAction(
            'Settle',
            onTap: () =>
                showAaniSheet(context, group: g, payee: m, amount: iOwe.amount),
          );
        }
      } else if (owesMe != null) {
        final pending = pendingSettlement(g, m.id, 'me');
        if (pending != null) {
          subtitle = 'Says they paid ${Money.aed(pending.amount)} via Aani';
          subColor = c.warning;
          trailing = TextAction(
            'Confirm',
            onTap: () => confirmReceived(context, ref, g, pending),
          );
        } else {
          subtitle = 'Owes you ${Money.aed(owesMe.amount)}';
          subColor = c.positive;
          trailing = TextAction(
            'Remind',
            color: c.textSecondary,
            onTap: () => SharePlus.instance.share(
              ShareParams(
                text:
                    'Hi ${m.name}, ${Money.aed(owesMe.amount)} for ${g.name}. '
                    'Aani works best. Thanks!',
              ),
            ),
          );
        }
      } else {
        subtitle = 'Settled with you';
      }
      return ListRow(
        leading: MemberAvatar(m),
        title: m.name,
        subtitle: subtitle,
        subtitleColor: subColor,
        trailing: trailing,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      children: [
        const SizedBox(height: Space.lg),
        HeroNumber(
          label: mine.abs() < 0.01
              ? 'You are settled'
              : (mine > 0 ? 'You are owed' : 'You owe'),
          value: mine.abs(),
          color: mine > 0.005 ? c.positive : null,
          caption:
              '${g.expenses.length} ${g.expenses.length == 1 ? 'expense' : 'expenses'} · ${Money.aed(g.total, decimals: false)} in total',
        ),
        const SectionHeader('People'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            for (final m in others) memberRow(m),
            ListRow(
              leading: IconWell(Icons.person_add_alt_outlined, color: c.accent),
              title: 'Add people',
              titleStyle: context.tt.bodyLarge!.copyWith(color: c.accent),
              onTap: () => showPulseSheet<void>(
                context,
                full: true,
                builder: (_) => ContactPickerSheet(group: g),
              ),
            ),
          ],
        ),
        if (others.any((m) => m.onPulse))
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: Row(
              children: [
                Dot(c.accent),
                const SizedBox(width: Space.sm),
                Text(
                  'On Pulse: sees this group and confirms payments',
                  style: context.tt.bodySmall,
                ),
              ],
            ),
          ),
        const SectionHeader('Expenses'),
        RowGroup(
          children: [
            for (final e in g.expenses)
              ListRow(
                title: e.title,
                subtitle:
                    '${g.member(e.paidBy)?.name ?? 'Someone'} paid · ${DateFormat('d MMM').format(e.date)}',
                trailing: Text(
                  Money.aed(e.amount),
                  style: PulseTheme.amount(c.textPrimary),
                ),
              ),
            for (final s in g.settlements)
              ListRow(
                title:
                    '${g.member(s.from)?.name ?? '?'} paid ${g.member(s.to)?.name ?? '?'}',
                subtitle:
                    'Aani · ${s.status == SettlementStatus.confirmed ? 'confirmed' : 'awaiting confirmation'} · ${DateFormat('d MMM').format(s.date)}',
                trailing: Text(
                  Money.aed(s.amount),
                  style: PulseTheme.amount(c.textSecondary),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
