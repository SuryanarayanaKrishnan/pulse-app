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
import '../splits/tx_split_row.dart';
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
  late final _note = TextEditingController(text: widget.tx.note ?? '');
  late final FocusNode _noteFocus = FocusNode()
    ..addListener(() {
      if (!_noteFocus.hasFocus) _saveNote();
    });
  late String _savedNote = widget.tx.note ?? '';

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final text = _note.text.trim();
    if (text == _savedNote.trim() || !mounted) return;
    _savedNote = text;
    try {
      await ref.read(repositoryProvider).setTransactionNote(widget.tx.id, text);
      if (mounted) invalidateLedger(ref);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not save the note.')),
        );
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this payment?'),
        content: const Text(
          'It is removed from your totals, budgets and cash flow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const Key('tx_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(repositoryProvider).deleteTransaction(widget.tx.id);
      invalidateLedger(ref);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not delete that payment.')),
        );
      }
    }
  }

  bool _forgot = false;

  /// Stops Pulse using this choice for future payments from the merchant.
  /// This payment keeps its category; change it above if that is wrong.
  Future<void> _forget() async {
    await ref.read(merchantMemoryProvider).forget(widget.tx.merchant);
    if (!mounted) return;
    setState(() => _forgot = true);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Forgotten. Future ${widget.tx.merchant} will be sorted by default.',
        ),
      ),
    );
  }

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
    unawaited(
      recordConfirmedCategory(
        ref.read(learningControllerProvider),
        widget.tx,
        picked,
      ),
    );
    unawaited(
      rememberCategoryChoice(
        ref.read(merchantMemoryProvider),
        widget.tx,
        picked,
        fix: true,
      ),
    );
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
              if (tx.learned && !_forgot && _cat == tx.category)
                ListRow(
                  key: const Key('tx_learned_row'),
                  dense: true,
                  leading: Icon(
                    Icons.auto_awesome_outlined,
                    size: 22,
                    color: c.accent,
                  ),
                  title: 'Learned from your choice',
                  subtitle:
                      'You put ${tx.merchant} here before. Only on this phone.',
                  trailing: TextButton(
                    key: const Key('tx_learned_forget'),
                    onPressed: _forget,
                    child: const Text('Forget'),
                  ),
                ),
              TxSplitRow(tx: tx),
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
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('tx_note'),
            controller: _note,
            focusNode: _noteFocus,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Add a note'),
            onSubmitted: (_) => _saveNote(),
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
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          'From your email receipt',
                          style: context.tt.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  if (tx.receiptNotes != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      tx.receiptNotes!,
                      key: const Key('tx_receipt_notes'),
                      style: context.tt.bodyMedium,
                    ),
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
            onPressed: () async {
              await _saveNote();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: Space.sm),
          Center(
            child: TextAction(
              'Delete payment',
              key: const Key('tx_delete'),
              color: c.negative,
              onTap: _delete,
            ),
          ),
        ],
      ),
    );
  }
}

/// Add a payment by hand: an expense or income, on any day, with a note.
class AddManualTxSheet extends ConsumerStatefulWidget {
  const AddManualTxSheet({super.key});

  @override
  ConsumerState<AddManualTxSheet> createState() => _AddManualTxSheetState();
}

class _AddManualTxSheetState extends ConsumerState<AddManualTxSheet> {
  final _merchant = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  SpendCategory _cat = SpendCategory.dining;
  bool _income = false;
  DateTime _date = DateTime.now();
  bool _busy = false;

  /// One-tap categories for everyday spending; "More" opens the full list.
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
    _note.dispose();
    super.dispose();
  }

  double? get _parsed {
    final a = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    return (a == null || a <= 0 || !a.isFinite) ? null : a;
  }

  void _setIncome(bool income) {
    if (income == _income) return;
    setState(() {
      _income = income;
      _cat = income ? SpendCategory.salary : SpendCategory.dining;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final amt = _parsed;
    if (amt == null || _busy) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final today =
          _date.year == now.year &&
          _date.month == now.month &&
          _date.day == now.day;
      await ref
          .read(repositoryProvider)
          .addManualTransaction(
            // The name is optional: the category names the payment.
            merchant: _merchant.text.trim().isEmpty
                ? _cat.label
                : _merchant.text.trim(),
            amount: amt,
            category: _cat,
            date: today
                ? null
                : DateTime(_date.year, _date.month, _date.day, 12),
            note: _note.text,
          );
      ref
          .read(analyticsProvider)
          .track(AnalyticsEvent.manualTransactionAdded(category: _cat.name));
      invalidateLedger(ref);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Could not save that payment. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inQuick = _quick.any((q) => q.id == _cat.id);
    return SheetScaffold(
      title: 'Add a payment',
      subtitle: 'Most spending is captured automatically. Add cash, or anything we could not see.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            children: [
              ChoiceChip(
                label: const Text('Expense'),
                selected: !_income,
                onSelected: (_) => _setIncome(false),
              ),
              ChoiceChip(
                label: const Text('Income'),
                selected: _income,
                onSelected: (_) => _setIncome(true),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Amount',
              prefixIcon: CurrencyPrefix('AED'),
              prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              if (_income)
                ChoiceChip(
                  label: Text(SpendCategory.salary.label),
                  selected: _cat.id == SpendCategory.salary.id,
                  onSelected: (_) =>
                      setState(() => _cat = SpendCategory.salary),
                )
              else
                for (final q in [..._quick, if (!inQuick) _cat])
                  ChoiceChip(
                    label: Text(q.label),
                    selected: _cat.id == q.id,
                    onSelected: (_) => setState(() => _cat = q),
                  ),
              if (_income && _cat.id != SpendCategory.salary.id)
                ChoiceChip(
                  label: Text(_cat.label),
                  selected: true,
                  onSelected: (_) {},
                ),
              ActionChip(
                label: const Text('More'),
                onPressed: () async {
                  final c = await pickCategory(
                    context,
                    selected: _cat,
                    includeIncome: _income,
                  );
                  if (c != null) setState(() => _cat = c);
                },
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _merchant,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: _income ? 'From (optional)' : 'Paid to (optional)',
            ),
          ),
          const SizedBox(height: Space.md),
          ListRow(
            key: const Key('manual_date'),
            dense: true,
            title: 'Date',
            trailing: Text(
              DateFormat('EEE d MMM yyyy').format(_date),
              style: context.tt.bodyMedium,
            ),
            chevron: true,
            onTap: _pickDate,
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('manual_note'),
            controller: _note,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Note (optional)'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Save',
            loading: _busy,
            onPressed: _parsed == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
