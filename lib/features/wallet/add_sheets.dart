import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/vault_service.dart' show vaultTypeForAsset;
import '../vault/held_at.dart';

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

  bool get _valid => RegExp(r'^\d{4}$').hasMatch(_last4.text.trim());

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
        title: 'Which card?',
        subtitle: 'Rewards come from the built-in card catalog. Figures are not yet checked against the issuers.',
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
                return RowGroup(
                  padding: EdgeInsets.zero,
                  indent: 56 + Space.md,
                  children: [
                    for (final k in shown)
                      ListRow(
                        leading: SizedBox(width: 56, child: CreditCardVisual(card: k, compact: true)),
                        title: '${k.issuer} ${k.name}',
                        subtitle: k.highlight,
                        chevron: true,
                        onTap: () => setState(() => _picked = k),
                      ),
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
      subtitle: 'Only the last four digits are kept.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _last4,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: const InputDecoration(hintText: 'Last 4 digits'),
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

  /// One-tap banks; anything else is typed.
  static const _banks = ['Emirates NBD', 'Mashreq', 'ADCB', 'FAB', 'DIB', 'RAKBANK', 'Wio', 'Revolut'];

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
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final b in _banks)
                ChoiceChip(
                  label: Text(b),
                  selected: _bank.text == b,
                  onSelected: (_) => setState(() => _bank.text = b),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
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
  final _heldAt = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _heldAt.dispose();
    super.dispose();
  }

  /// The name is optional: "Gold" or "Loan or debt" is enough to start.
  String get _kindName => _kind == AssetKind.liability ? 'Loan or debt' : _kind.label;

  Future<void> _save() async {
    final v = _parseAmount(_value.text);
    if (v == null) return;
    setState(() => _busy = true);
    try {
      final a = await ref.read(repositoryProvider).addAsset(name: _name.text.trim().isEmpty ? _kindName : _name.text.trim(), kind: _kind, value: v);
      final problem = await saveHeldAt(
        ref,
        sourceRef: '${_kind == AssetKind.liability ? 'liability' : 'asset'}:${a.id}',
        type: vaultTypeForAsset(_kind),
        where: _heldAt.text,
        title: a.name,
      );
      if (problem != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      }
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
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'Name (optional), like "Marina apartment"'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: _kind == AssetKind.liability ? 'Amount owed' : 'Value today', prefixText: 'AED  '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.md),
        HeldAtField(
          controller: _heldAt,
          hint: switch (_kind) {
            AssetKind.realEstate => 'Papers at, e.g. title deed in locker, agent, DLD',
            AssetKind.liability => 'Owed to, e.g. bank or person',
            AssetKind.gold => 'Kept at, e.g. bank locker, home safe',
            _ => 'Held at, e.g. bank or platform',
          },
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Add',
          loading: _busy,
          onPressed: _parseAmount(_value.text) != null ? _save : null,
        ),
        if (_parseAmount(_value.text) != null) ...[
          const SizedBox(height: Space.sm),
          Text(Money.aed(_parseAmount(_value.text)!, decimals: false), style: context.tt.bodySmall, textAlign: TextAlign.center),
        ],
      ],
    ),
  );
}

/// Edits or deletes something the user typed in: a manual asset, a loan or an
/// account balance. [onOwnership] adds a "Who owns this" link for households.
Future<void> showEditAssetSheet(BuildContext context, Asset asset, {VoidCallback? onOwnership}) =>
    showPulseSheet<void>(context, builder: (_) => EditAssetSheet(asset, onOwnership: onOwnership));

/// Asks before deleting [asset]; returns true when it was deleted.
Future<bool> confirmDeleteAsset(BuildContext context, WidgetRef ref, Asset asset) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete ${asset.name}?'),
      content: Text(
        asset.id.startsWith('account:')
            ? 'It leaves your net worth. Its transactions stay in Activity.'
            : 'It leaves your net worth.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
        TextButton(key: const Key('confirm_delete_asset'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  if (sure != true) return false;
  try {
    await ref.read(repositoryProvider).deleteAsset(asset.id);
    ref.invalidate(assetsProvider);
    ref.invalidate(netWorthProvider);
    return true;
  } on Object catch (e) {
    if (context.mounted) _fail(context, e);
    return false;
  }
}

class EditAssetSheet extends ConsumerStatefulWidget {
  const EditAssetSheet(this.asset, {super.key, this.onOwnership});
  final Asset asset;
  final VoidCallback? onOwnership;
  @override
  ConsumerState<EditAssetSheet> createState() => _EditAssetSheetState();
}

class _EditAssetSheetState extends ConsumerState<EditAssetSheet> {
  late final _name = TextEditingController(text: widget.asset.name);
  late final _value = TextEditingController(text: _plain(widget.asset.value));
  bool _busy = false;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _parseAmount(_value.text) != null;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).updateAsset(widget.asset.id, name: _name.text.trim(), value: _parseAmount(_value.text)!);
      ref.invalidate(assetsProvider);
      ref.invalidate(netWorthProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) _fail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    if (await confirmDeleteAsset(context, ref, widget.asset)) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isAccount = widget.asset.id.startsWith('account:');
    final owed = widget.asset.isLiability;
    return SheetScaffold(
      title: 'Edit ${widget.asset.name}',
      subtitle: isAccount ? 'Set today\'s balance; it moves with your transactions from here.' : 'Update the value whenever it changes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('edit_asset_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('edit_asset_value'),
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: owed ? 'Amount owed' : (isAccount ? 'Balance today' : 'Value today'), prefixText: 'AED  '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(key: const Key('edit_asset_save'), label: 'Save', loading: _busy, onPressed: _valid ? _save : null),
          const SizedBox(height: Space.sm),
          if (widget.onOwnership != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOwnership!();
              },
              child: const Text('Who owns this'),
            ),
          TextButton(
            key: const Key('edit_asset_delete'),
            onPressed: _delete,
            child: Text('Delete', style: TextStyle(color: context.pc.negative)),
          ),
        ],
      ),
    );
  }
}
