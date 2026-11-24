import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_ranking.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../cards/card_value_widgets.dart';
import '../cards/card_widgets.dart';
import '../transactions/tx_detail_sheet.dart';
import '../transactions/tx_tile.dart';
import 'wallet_detail.dart';

/// Three small figures side by side.
class FigureRow extends StatelessWidget {
  const FigureRow(this.items, {super.key});
  final List<(String, String, Color?)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.lg,
        Space.gutter,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value, color) in items)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.tt.bodySmall),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: PulseTheme.amount(color ?? c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

bool _thisMonth(Transaction t) {
  final n = DateTime.now();
  return t.date.year == n.year && t.date.month == n.month;
}

bool _spend(Transaction t) =>
    !t.isIncome && !t.excluded && !t.category.isTransfer;

/// Category totals as rows with a share meter.
class SpendByCategory extends StatelessWidget {
  const SpendByCategory(this.txs, {super.key});
  final List<Transaction> txs;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final by = <SpendCategory, double>{};
    for (final t in txs) {
      by[t.category] = (by[t.category] ?? 0) + t.amount;
    }
    final total = by.values.fold<double>(0, (a, b) => a + b);
    final rows = by.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (rows.isEmpty) {
      return Padding(
        padding: screenPad,
        child: Text('No spending this month.', style: context.tt.bodyMedium),
      );
    }
    return RowGroup(
      indent: ListRow.leadingInset,
      children: [
        for (final e in rows.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm + 2),
            child: Row(
              children: [
                CategoryIcon.well(e.key),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key.label,
                              style: context.tt.bodyLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            Money.aed(e.value, decimals: false),
                            style: PulseTheme.amount(c.textPrimary, size: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Meter(value: total == 0 ? 0 : e.value / total),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent(this.txs);
  final List<Transaction> txs;
  @override
  Widget build(BuildContext context) {
    if (txs.isEmpty) {
      return Padding(
        padding: screenPad,
        child: Text('Nothing yet.', style: context.tt.bodyMedium),
      );
    }
    return RowGroup(
      indent: ListRow.leadingInset,
      children: [
        for (final t in txs.take(6))
          TxTile(
            t,
            onTap: () => showPulseSheet<void>(
              context,
              builder: (_) => TxDetailSheet(tx: t),
            ),
          ),
      ],
    );
  }
}

/// Everything about one card, below its face in the detail pager.
class CardDetailBody extends ConsumerWidget {
  const CardDetailBody(this.card, {super.key});
  final CreditCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final txs = (ref.watch(transactionsProvider).value ?? const [])
        .where((t) => t.cardId == card.id)
        .toList();
    final month = txs.where((t) => _thisMonth(t) && _spend(t)).toList();
    final earned = earnedOn(card, month);
    final u = card.utilisation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigureRow([
          ('Balance', Money.aed(card.balance, decimals: false), null),
          (
            'Utilisation',
            '${(u * 100).round()}%',
            u > 0.5 ? c.negative : (u > 0.3 ? c.warning : null),
          ),
          ('Earned this month', Money.aed(earned), c.positive),
        ]),
        CardValueSection(card.id),
        const SectionHeader('Payment'),
        PaymentDetails(card),
        const SectionHeader('Rewards'),
        RewardRules(card),
        const SectionHeader('Spend this month'),
        SpendByCategory(month),
        const SectionHeader('Recent'),
        _Recent(txs),
      ],
    );
  }
}

/// Everything about one account, below its face in the detail pager.
class AccountDetailBody extends ConsumerWidget {
  const AccountDetailBody(this.account, {super.key});
  final BankAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final txs = (ref.watch(transactionsProvider).value ?? const [])
        .where((t) => account.matchLabels.contains(t.accountLabel))
        .toList();
    final month = txs.where((t) => _thisMonth(t) && _spend(t)).toList();
    final net = account.monthNet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigureRow([
          ('In this month', Money.aed(account.monthIn, decimals: false), null),
          ('Out', Money.aed(account.monthOut, decimals: false), null),
          (
            'Net',
            '${net >= 0 ? '+' : '−'}${Money.aed(net.abs(), decimals: false)}',
            net >= 0 ? c.positive : c.negative,
          ),
        ]),
        const SectionHeader('Spend this month'),
        SpendByCategory(month),
        const SectionHeader('Recent'),
        _Recent(txs),
      ],
    );
  }
}

/// Opens the card pager at [index].
Future<void> openCardDetail(
  BuildContext context,
  List<CreditCard> cards,
  int index,
) => openWalletDetail(
  context,
  count: cards.length,
  initial: index,
  faceBuilder: (_, i) => CreditCardVisual(card: cards[i]),
  heroTag: (i) => 'card-${cards[i].id}',
  title: (i) => cardName(cards[i]),
  sections: (_, i) => [CardDetailBody(cards[i])],
);

/// Opens the account pager at [index].
Future<void> openAccountDetail(
  BuildContext context,
  List<BankAccount> accounts,
  int index,
) => openWalletDetail(
  context,
  count: accounts.length,
  initial: index,
  faceBuilder: (_, i) => AccountCardVisual(account: accounts[i]),
  heroTag: (i) => 'account-${accounts[i].id}',
  title: (i) => accounts[i].label,
  sections: (_, i) => [AccountDetailBody(accounts[i])],
);
