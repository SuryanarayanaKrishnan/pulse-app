import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Transaction detail with category re-assign.
class TxDetailSheet extends ConsumerStatefulWidget {
  const TxDetailSheet({super.key, required this.tx});
  final Transaction tx;

  @override
  ConsumerState<TxDetailSheet> createState() => _TxDetailSheetState();
}

class _TxDetailSheetState extends ConsumerState<TxDetailSheet> {
  late SpendCategory _cat = widget.tx.category;

  Future<void> _pick(SpendCategory c) async {
    if (c == _cat) return;
    Haptics.light();
    final from = _cat;
    setState(() => _cat = c);
    await ref.read(repositoryProvider).recategorise(widget.tx.id, c);
    ref
        .read(analyticsProvider)
        .track(
          AnalyticsEvent.transactionRecategorized(from: from.name, to: c.name),
        );
    ref.invalidate(transactionsProvider);
    ref.invalidate(budgetProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final c = context.pc;
    return SheetScaffold(
      title: tx.merchant,
      subtitle: DateFormat('EEE d MMM, HH:mm').format(tx.date),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: AmountText(
              tx.signed,
              size: 40,
              decimals: true,
              signed: tx.isIncome,
              color: tx.isIncome ? c.positive : null,
            ),
          ),
          const SizedBox(height: Space.lg),
          GlassCard(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              children: [
                _Row('Account', tx.accountLabel),
                _Row(
                  'Captured via',
                  tx.source.automatic
                      ? '${tx.source.label} (automatic)'
                      : 'Manual entry',
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Text('Category', style: context.tt.titleMedium),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cat in SpendCategory.values)
                Pill(
                  cat.label,
                  icon: cat.icon,
                  color: cat.color,
                  selected: cat == _cat,
                  onTap: () => _pick(cat),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k;
  final String v;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(k, style: context.tt.bodyMedium),
        const Spacer(),
        Text(v, style: context.tt.titleSmall),
      ],
    ),
  );
}

/// Secondary, deliberately low-key manual entry.
class AddManualTxSheet extends ConsumerStatefulWidget {
  const AddManualTxSheet({super.key});
  @override
  ConsumerState<AddManualTxSheet> createState() => _AddManualTxSheetState();
}

class _AddManualTxSheetState extends ConsumerState<AddManualTxSheet> {
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  SpendCategory _cat = SpendCategory.dining;

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', ''));
    if (amt == null || amt <= 0 || _merchant.text.trim().isEmpty) return;
    await ref
        .read(repositoryProvider)
        .addManualTransaction(
          merchant: _merchant.text.trim(),
          amount: amt,
          category: _cat,
        );
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.manualTransactionAdded(category: _cat.name));
    ref.invalidate(transactionsProvider);
    ref.invalidate(budgetProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Add a cash expense',
    subtitle: 'Most spending is captured automatically. Use this only for cash or things we could not see.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _merchant,
          decoration: const InputDecoration(hintText: 'Merchant or note'),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Amount in AED',
            prefixText: 'AED  ',
          ),
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in SpendCategory.values.where(
              (c) => c != SpendCategory.income,
            ))
              Pill(
                c.label,
                icon: c.icon,
                color: c.color,
                selected: c == _cat,
                onTap: () => setState(() => _cat = c),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Save', onPressed: _save),
      ],
    ),
  );
}
