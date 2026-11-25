import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

double? _parseAmount(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  return v == null || v < 0 ? null : v;
}

int? _parseDay(String s) {
  final v = int.tryParse(s.trim());
  return v == null || v < 1 || v > 31 ? null : v;
}

void _fail(BuildContext context, Object e) {
  final msg = e is ApiException ? e.message : 'That did not work. Try again.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// What can be added to the wallet, in one place. Everything stays on this
/// phone.
Future<void> showAddMenu(BuildContext context) => showPulseSheet<void>(
  context,
  builder: (sheet) => SheetScaffold(
    title: 'Add to Pulse',
    subtitle: 'Saved on this phone only.',
    child: RowGroup(
      padding: EdgeInsets.zero,
      children: [
        ListRow(
          leading: IconWell(Icons.credit_card_outlined, color: context.pc.accent),
          title: 'Credit card',
          subtitle: 'Rewards and due dates, from the card catalog',
          chevron: true,
          onTap: () {
            Navigator.of(sheet).pop();
            showPulseSheet<void>(context, builder: (_) => const AddCardSheet(), full: true);
          },
        ),
        ListRow(
          leading: IconWell(Icons.account_balance_outlined, color: context.pc.accent),
          title: 'Bank account or wallet',
          subtitle: 'Balances move as alerts arrive',
          chevron: true,
          onTap: () {
            Navigator.of(sheet).pop();
            showPulseSheet<void>(context, builder: (_) => const AddAccountSheet());
          },
        ),
        ListRow(
          leading: IconWell(Icons.diamond_outlined, color: context.pc.accent),
          title: 'Asset or loan',
          subtitle: 'Property, gold, deposits, stocks, debts',
          chevron: true,
          onTap: () {
            Navigator.of(sheet).pop();
            showPulseSheet<void>(context, builder: (_) => const AddAssetSheet());
          },
        ),
      ],
    ),
  ),
);

/// Pick a card from the catalog, then say which one it is.
class AddCardSheet extends ConsumerStatefulWidget {
  const AddCardSheet({super.key, this.initial});

  /// A card already chosen (from the Discover list).
  final CreditCard? initial;
  @override
  ConsumerState<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<AddCardSheet> {
  late CreditCard? _picked = widget.initial;
  final _last4 = TextEditingController();
  final _limit = TextEditingController();
  final _owed = TextEditingController();
  final _statement = TextEditingController();
  final _due = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_last4, _limit, _owed, _statement, _due]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Cards ticked in the list; several can be added in one go.
  final _selected = <String>{};

  /// Last four digits are optional, but if typed they must be four digits.
  bool get _valid => _last4.text.trim().isEmpty || RegExp(r'^\d{4}$').hasMatch(_last4.text.trim());

  Future<void> _addSelected(List<CreditCard> all) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      for (final k in all) {
        if (_selected.contains(k.id)) await repo.addCard(catalogId: k.id, last4: '');
      }
      invalidateWallet(ref);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final card = _picked;
    if (card == null || !_valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).addCard(
        catalogId: card.id,
        last4: _last4.text.trim(),
        limit: _parseAmount(_limit.text),
        owed: _parseAmount(_owed.text) ?? 0,
        statementDay: _parseDay(_statement.text),
        dueDay: _parseDay(_due.text),
      );
      invalidateWallet(ref);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    if (picked == null) {
      final catalog = ref.watch(catalogProvider);
      return SheetScaffold(
        title: 'Which cards do you have?',
        subtitle: 'Tick every card you hold, then add them together. Rewards come from the built-in catalog.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Search by bank or card'),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: Space.md),
            AsyncView<List<CreditCard>>(
              value: catalog,
              loading: const SkeletonList(rows: 4, height: 56),
              onRetry: () => ref.invalidate(catalogProvider),
              builder: (list) {
                final shown = [
                  for (final k in list)
                    if (_query.isEmpty || '${k.issuer} ${k.name}'.toLowerCase().contains(_query)) k,
                ];
                if (shown.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No match',
                    message: 'Try the bank name, like "Mashreq".',
                  );
                }
                final n = _selected.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RowGroup(
                      padding: EdgeInsets.zero,
                      indent: 56 + Space.md,
                      children: [
                        for (final k in shown)
                          ListRow(
                            leading: SizedBox(width: 56, child: CreditCardVisual(card: k, compact: true)),
                            title: '${k.issuer} ${k.name}',
                            subtitle: k.highlight,
                            trailing: Icon(
                              _selected.contains(k.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                              color: _selected.contains(k.id) ? context.pc.accent : context.pc.textTertiary,
                            ),
                            onTap: () => setState(() {
                              if (!_selected.remove(k.id)) _selected.add(k.id);
                            }),
                          ),
                      ],
                    ),
                    if (n > 0) ...[
                      const SizedBox(height: Space.lg),
                      PrimaryButton(
                        label: n == 1 ? 'Add this card' : 'Add $n cards',
                        loading: _busy,
                        onPressed: () => _addSelected(list),
                      ),
                      if (n == 1) ...[
                        const SizedBox(height: Space.sm),
                        PrimaryButton(
                          label: 'Add with details',
                          secondary: true,
                          onPressed: () => setState(() => _picked = list.firstWhere((k) => _selected.contains(k.id))),
                        ),
                      ],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
    return SheetScaffold(
      title: '${picked.issuer} ${picked.name}',
      subtitle: 'Everything here is optional. Only the last four digits are kept.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _last4,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(hintText: 'Last 4 digits (optional)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _limit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Credit limit (optional)', prefixText: 'AED  '),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _owed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Owed today (optional)', prefixText: 'AED  '),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _statement,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Statement day'),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: TextField(
                  controller: _due,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Due day'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(label: 'Add card', loading: _busy, onPressed: _valid ? _save : null),
          const SizedBox(height: Space.sm),
          PrimaryButton(label: 'Choose another', secondary: true, onPressed: () => setState(() => _picked = null)),
        ],
      ),
    );
  }
}

class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key});
  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  BankAccountKind _kind = BankAccountKind.current;
  final _bank = TextEditingController();
  final _name = TextEditingController();
  final _last4 = TextEditingController();
  final _balance = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_bank, _name, _last4, _balance]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isCash => _kind == BankAccountKind.cash;

  Future<void> _save() async {
    final bank = _isCash ? 'Cash' : _bank.text.trim();
    if (bank.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).addBankAccount(
        bank: _isCash ? '' : bank,
        name: _name.text.trim().isEmpty ? _kind.label : _name.text.trim(),
        kind: _kind,
        last4: _last4.text.trim().isEmpty ? null : _last4.text.trim(),
        balance: double.tryParse(_balance.text.trim().replaceAll(',', '')) ?? 0,
      );
      invalidateWallet(ref);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Add an account',
    subtitle: 'Its balance moves as alerts arrive.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<BankAccountKind>(
          segments: const {
            BankAccountKind.current: 'Current',
            BankAccountKind.savings: 'Savings',
            BankAccountKind.wallet: 'Wallet',
            BankAccountKind.cash: 'Cash',
          },
          value: _kind,
          onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: Space.lg),
        if (!_isCash) ...[
          TextField(
            controller: _bank,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Bank or provider, like Emirates NBD'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _last4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(hintText: 'Last 4 digits (optional, matches alerts)'),
          ),
          const SizedBox(height: Space.md),
        ],
        TextField(
          controller: _balance,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(hintText: 'Balance today', prefixText: 'AED  '),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Add account',
          loading: _busy,
          onPressed: (_isCash || _bank.text.trim().isNotEmpty) ? _save : null,
        ),
      ],
    ),
  );
}

class AddAssetSheet extends ConsumerStatefulWidget {
  const AddAssetSheet({super.key});
  @override
  ConsumerState<AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends ConsumerState<AddAssetSheet> {
  AssetKind _kind = AssetKind.realEstate;
  final _name = TextEditingController();
  final _value = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _parseAmount(_value.text);
    if (_name.text.trim().isEmpty || v == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).addAsset(name: _name.text.trim(), kind: _kind, value: v);
      ref.invalidate(assetsProvider);
      ref.invalidate(netWorthProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Add to net worth',
    subtitle: 'You set the value; update it whenever it changes.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final k in AssetKind.values.where((k) => k != AssetKind.funds))
              ChoiceChip(
                label: Text(k == AssetKind.liability ? 'Loan or debt' : k.label),
                selected: _kind == k,
                onSelected: (_) => setState(() => _kind = k),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Name, like "Marina apartment"'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: _kind == AssetKind.liability ? 'Amount owed' : 'Value today', prefixText: 'AED  '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Add',
          loading: _busy,
          onPressed: (_name.text.trim().isNotEmpty && _parseAmount(_value.text) != null) ? _save : null,
        ),
        if (_parseAmount(_value.text) != null) ...[
          const SizedBox(height: Space.sm),
          Text(Money.aed(_parseAmount(_value.text)!, decimals: false), style: context.tt.bodySmall, textAlign: TextAlign.center),
        ],
      ],
    ),
  );
}
