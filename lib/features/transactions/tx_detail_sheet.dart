import 'dart:async';

import '../../core/learning/learning_controller.dart';
import '../../data/learning_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/rules.dart';
import '../categories/category_picker.dart';
import '../household/ownership_widgets.dart';
import 'recategorise_sheet.dart';

/// Transaction detail. Re-categorising offers to turn the choice into a rule.
class TxDetailSheet extends ConsumerStatefulWidget {
  const TxDetailSheet({super.key, required this.tx});
  final Transaction tx;

  @override
  ConsumerState<TxDetailSheet> createState() => _TxDetailSheetState();
}

class _TxDetailSheetState extends ConsumerState<TxDetailSheet> {
  late SpendCategory _cat = widget.tx.category;

  /// "Always categorise X as Y?" once the user re-categorises.
  AutomationRule? _suggestion;
  bool _ruleSaved = false;
  bool _saving = false;

  Future<void> _pick() async {
    final picked = await pickCategory(context, selected: _cat);
    if (picked == null || picked == _cat || !mounted) return;
    final from = _cat;
    setState(() {
      _cat = picked;
      _suggestion = null;
      _ruleSaved = false;
    });
    // Repositories that can scope the change ask how far it should reach.
    if (await recategoriseWithScope(context, ref, tx: widget.tx, to: picked)) {
      return;
    }
    await ref.read(repositoryProvider).recategorise(widget.tx.id, picked);
    unawaited(recordConfirmedCategory(ref.read(learningControllerProvider), widget.tx, picked));
    ref
        .read(analyticsProvider)
        .track(
          AnalyticsEvent.transactionRecategorized(
            from: from.name,
            to: picked.name,
          ),
        );
    invalidateLedger(ref);
    final rules = await ref
        .read(rulesProvider.future)
        .catchError((_) => <AutomationRule>[]);
    if (!mounted) return;
    if (!hasMerchantRule(rules, widget.tx.merchant, picked)) {
      setState(() => _suggestion = suggestMerchantRule(widget.tx, picked));
    }
  }

  Future<void> _createRule() async {
    final rule = _suggestion;
    if (rule == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).saveRule(rule);
      ref.invalidate(rulesProvider);
      invalidateLedger(ref);
      Haptics.success();
      if (mounted) setState(() => _ruleSaved = true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final c = context.pc;
    return SheetScaffold(
      title: tx.merchant,
      subtitle: DateFormat('EEEE d MMMM, HH:mm').format(tx.date),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountText(
            tx.signed,
            size: 40,
            weight: FontWeight.w700,
            decimals: true,
            signed: tx.isIncome,
            color: tx.isIncome ? c.positive : null,
          ),
          const SizedBox(height: Space.xl),
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              ListRow(
                dense: true,
                leading: CategoryIcon(_cat, size: 22),
                title: 'Category',
                trailing: Text(_cat.label, style: context.tt.bodyLarge),
                chevron: true,
                onTap: _pick,
              ),
              ListRow(
                dense: true,
                title: 'Account',
                trailing: Text(tx.accountLabel, style: context.tt.bodyMedium),
              ),
              OwnerRow(table: 'transactions', id: tx.id, title: tx.merchant),
              ListRow(
                dense: true,
                title: 'Captured via',
                trailing: Text(
                  tx.source.automatic ? tx.source.label : 'Manual entry',
                  style: context.tt.bodyMedium,
                ),
              ),
              if (tx.description != tx.merchant)
                ListRow(
                  dense: true,
                  title: 'Original text',
                  trailing: Flexible(
                    child: Text(
                      tx.description,
                      style: context.tt.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
            ],
          ),
          if (tx.receiptNotes != null || tx.receiptRef != null) ...[
            const SizedBox(height: Space.xl),
            SurfaceCard(
              key: const Key('tx_receipt_card'),
              color: c.isDark ? c.surfaceElevated : c.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 18, color: c.textSecondary),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text('From your email receipt', style: context.tt.titleSmall)),
                    ],
                  ),
                  if (tx.receiptNotes != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(tx.receiptNotes!, key: const Key('tx_receipt_notes'), style: context.tt.bodyMedium),
                  ],
                  const SizedBox(height: Space.sm),
                  Text(
                    'Matched on this phone. The amount and date are still your bank\'s.',
                    style: context.tt.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: _suggestion == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.xl),
                    child: SurfaceCard(
                      color: c.isDark ? c.surfaceElevated : c.surface,
                      child: AnimatedSwitcher(
                        duration: Motion.base,
                        child: _ruleSaved
                            ? Row(
                                key: const ValueKey('done'),
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: c.positive,
                                    size: 20,
                                  ),
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: Text(
                                      'Rule created. Future ${tx.merchant} '
                                      'transactions go to ${_cat.label}.',
                                      style: context.tt.bodyMedium,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('ask'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Always categorise ${tx.merchant} as '
                                    '${_cat.label}?',
                                    style: context.tt.titleSmall,
                                  ),
                                  const SizedBox(height: Space.xs),
                                  Text(
                                    'Creates an automation for past and future '
                                    'transactions.',
                                    style: context.tt.bodySmall,
                                  ),
                                  const SizedBox(height: Space.md),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: PrimaryButton(
                                          label: 'Create rule',
                                          loading: _saving,
                                          onPressed: _createRule,
                                        ),
                                      ),
                                      const SizedBox(width: Space.md),
                                      TextAction(
                                        'Not now',
                                        color: c.textSecondary,
                                        onTap: () =>
                                            setState(() => _suggestion = null),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Done',
            secondary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
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
  bool _busy = false;

  /// One-tap categories for everyday cash spending; "More" opens the full list.
  static const _quick = [
    SpendCategory.dining,
    SpendCategory.groceries,
    SpendCategory.transport,
    SpendCategory.shopping,
    SpendCategory.health,
  ];

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _parsed {
    final a = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    return (a == null || a <= 0 || !a.isFinite) ? null : a;
  }

  Future<void> _save() async {
    final amt = _parsed;
    if (amt == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .addManualTransaction(
            // The note is optional: the category names the expense.
            merchant: _merchant.text.trim().isEmpty ? _cat.label : _merchant.text.trim(),
            amount: amt,
            category: _cat,
          );
      ref.read(analyticsProvider).track(AnalyticsEvent.manualTransactionAdded(category: _cat.name));
      invalidateLedger(ref);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Could not save that expense. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inQuick = _quick.any((q) => q.id == _cat.id);
    return SheetScaffold(
      title: 'Add a cash expense',
      subtitle: 'Most spending is captured automatically. Use this only for cash or things we could not see.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Amount', prefixText: 'AED  '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final q in [..._quick, if (!inQuick) _cat])
                ChoiceChip(label: Text(q.label), selected: _cat.id == q.id, onSelected: (_) => setState(() => _cat = q)),
              ActionChip(
                label: const Text('More'),
                onPressed: () async {
                  final c = await pickCategory(context, selected: _cat, includeIncome: false);
                  if (c != null) setState(() => _cat = c);
                },
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _merchant,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Note (optional)'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(label: 'Save', loading: _busy, onPressed: _parsed == null ? null : _save),
        ],
      ),
    );
  }
}
