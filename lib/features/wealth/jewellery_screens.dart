import 'wealth_icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/prices.dart';
import '../../core/engine/valuation.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/wealth_store.dart' show newWealthId;
import '../../data/providers.dart';
import '../../data/wealth_models.dart';
import '../../data/wealth_service.dart';
import '../net_worth/wealth_screen.dart' show ago;
import '../../core/vault/vault_models.dart';
import '../household/ownership_widgets.dart';
import '../vault/held_at.dart';
import 'wealth_widgets.dart';

/// Add or edit a piece of jewellery. The value shown is worked out from the
/// weight, the karat and the live gold price, and updates as you adjust them,
/// so you can confirm the weight before saving.
class AddJewellerySheet extends ConsumerStatefulWidget {
  const AddJewellerySheet({super.key, this.initial});
  final JewelleryItem? initial;

  @override
  ConsumerState<AddJewellerySheet> createState() => _AddJewellerySheetState();
}

class _AddJewellerySheetState extends ConsumerState<AddJewellerySheet> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _weight = TextEditingController(
    text: widget.initial == null ? '' : _fmtG(widget.initial!.weightGrams),
  );
  late final _price = TextEditingController(
    text: widget.initial?.purchasePriceMinor == null
        ? ''
        : (widget.initial!.purchasePriceMinor! / 100).toStringAsFixed(0),
  );
  late final _making = TextEditingController(
    text: widget.initial?.makingChargesMinor == null
        ? ''
        : (widget.initial!.makingChargesMinor! / 100).toStringAsFixed(0),
  );
  late final _notes = TextEditingController(text: widget.initial?.notes);
  late final _fineness = TextEditingController(
    text: widget.initial?.purityOverride == null
        ? ''
        : (widget.initial!.purityOverride! * 1000).round().toString(),
  );
  late int _karat = widget.initial?.karat ?? 22;
  late bool _custom = widget.initial?.purityOverride != null;
  late CalDate? _date = widget.initial?.purchaseDate;
  late List<String> _existing = [...?widget.initial?.photoPaths];
  final _removed = <String>[];
  final _added = <String>[];
  bool _busy = false;
  final _heldAt = TextEditingController();
  VaultEntry? _heldEntry;

  @override
  void initState() {
    super.initState();
    final old = widget.initial;
    if (old == null) return;
    heldAtEntry(ref, 'asset:jewel:${old.id}').then((e) {
      if (e != null && mounted) {
        _heldEntry = e;
        setState(() => _heldAt.text = e.institution);
      }
    });
  }

  static String _fmtG(double g) =>
      g == g.roundToDouble() ? g.toStringAsFixed(0) : g.toString();

  @override
  void dispose() {
    for (final c in [
      _name,
      _weight,
      _price,
      _making,
      _notes,
      _fineness,
      _heldAt,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _w {
    final v = parseNumber(_weight.text);
    return v == null || v <= 0 ? null : v;
  }

  double? get _purity {
    if (!_custom) return null;
    final f = parseNumber(_fineness.text);
    return f == null || f <= 0 || f > 1000 ? null : f / 1000;
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _w != null &&
      (!_custom || _purity != null);

  void _nudge(double delta) {
    final w = ((_w ?? 0) + delta).clamp(0.0, 100000.0);
    setState(() => _weight.text = _fmtG(double.parse(w.toStringAsFixed(2))));
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _busy = true);
    try {
      final old = widget.initial;
      final svc = ref.read(wealthServiceProvider);
      final item = JewelleryItem(
        id: old?.id ?? newWealthId(),
        name: _name.text.trim(),
        weightGrams: _w!,
        karat: _custom ? (karatForPurity(_purity!) ?? 0) : _karat,
        purityOverride: _custom ? _purity : null,
        purchasePriceMinor: parseMinor(_price.text),
        purchaseDate: _date,
        makingChargesMinor: parseMinor(_making.text),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        photoPaths: _existing,
        createdAt: old?.createdAt ?? DateTime.now(),
      );
      await svc.saveJewellery(
        item,
        newPhotoSources: _added,
        removedPhotos: _removed,
      );
      final problem = await saveHeldAt(
        ref,
        sourceRef: 'asset:jewel:${item.id}',
        type: VaultType.investment,
        where: _heldAt.text,
        title: item.name,
        existing: _heldEntry,
      );
      invalidateWealth(ref);
      if (problem != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
      }
      if (mounted) Navigator.of(context).pop(item.id);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final book = ref.watch(priceBookProvider).value;
    final w = _w;
    final price24 = book?.gold24;
    final preview = (w != null && price24 != null)
        ? valueJewellery(
            weightGrams: w,
            aedPerGram24: price24,
            karat: _karat,
            purity: _purity,
            purchasePriceMinor: parseMinor(_price.text),
          )
        : null;
    final editing = widget.initial != null;
    return SheetScaffold(
      title: editing ? 'Edit piece' : 'Add gold or jewellery',
      subtitle: 'Valued on this phone from the live gold price.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhotoPickerRow(
            existing: _existing,
            added: _added,
            onAdd: (p) => setState(() => _added.add(p)),
            onRemoveExisting: (p) => setState(() {
              _existing = [..._existing]..remove(p);
              _removed.add(p);
            }),
            onRemoveAdded: (p) => setState(() => _added.remove(p)),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Name, like "Wedding necklace"',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Weight of the gold',
              suffixText: 'g',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('Karat'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final k in jewelleryKarats)
                Pill(
                  '${k}K',
                  selected: !_custom && _karat == k,
                  onTap: () => setState(() {
                    _custom = false;
                    _karat = k;
                  }),
                ),
              Pill(
                'Other',
                selected: _custom,
                onTap: () => setState(() => _custom = true),
              ),
            ],
          ),
          if (_custom) ...[
            const SizedBox(height: Space.md),
            TextField(
              controller: _fineness,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Fineness stamp, like 900',
                suffixText: 'parts per 1000',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'Purity ${finenessLabel(_karat)} · ${(purityForKarat(_karat) * 100).toStringAsFixed(2)}% pure gold',
                style: context.tt.bodySmall,
              ),
            ),
          const SizedBox(height: Space.lg),
          _ConfirmCard(
            valueMinor: preview?.valueMinor,
            gainMinor: preview?.gainMinor,
            gainPct: preview?.gainPct,
            pureGrams: preview?.pureGrams,
            note: book == null || price24 == null
                ? 'No gold price available yet.'
                : 'AED ${price24.toStringAsFixed(2)} per gram of 24K · ${_priceAge(book)}',
            onMinus: () => _nudge(-0.1),
            onPlus: () => _nudge(0.1),
          ),
          const FieldLabel('Purchase (optional)'),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Total paid',
              prefixIcon: CurrencyPrefix('AED'),
 prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _making,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Making charges (included above)',
              prefixIcon: CurrencyPrefix('AED'),
 prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: _date == null ? 'Purchase date' : formatDate(_date!),
                  icon: Icons.event_outlined,
                  secondary: true,
                  onPressed: () async {
                    final d = await pickDate(context, initial: _date);
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
              if (_date != null) ...[
                const SizedBox(width: Space.sm),
                IconButton(
                  tooltip: 'Clear date',
                  onPressed: () => setState(() => _date = null),
                  icon: Icon(Icons.close_rounded, color: c.textTertiary),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Notes (optional)'),
          ),
          const SizedBox(height: Space.md),
          HeldAtField(
            controller: _heldAt,
            hint: 'Kept at, e.g. bank locker, home safe, jeweller',
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: editing ? 'Save changes' : 'Add piece',
            loading: _busy,
            onPressed: _valid ? _save : null,
          ),
        ],
      ),
    );
  }

  static String _priceAge(PriceBook book) {
    final at = book.fetchedAt;
    final demo = book.origin == PriceOrigin.bundled;
    if (at == null) return 'saved price';
    return demo ? 'demo value, ${ago(at)}' : 'updated ${ago(at)}';
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.valueMinor,
    required this.gainMinor,
    required this.gainPct,
    required this.pureGrams,
    required this.note,
    required this.onMinus,
    required this.onPlus,
  });
  final int? valueMinor, gainMinor;
  final double? gainPct, pureGrams;
  final String note;
  final VoidCallback onMinus, onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final gain = gainMinor;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Worth today', style: context.tt.labelMedium),
          const SizedBox(height: Space.xs),
          Text(
            valueMinor == null
                ? '–'
                : Money.aed(valueMinor! / 100, decimals: false),
            key: const Key('jewellery-preview-value'),
            style: PulseTheme.amount(c.textPrimary, size: 28),
          ),
          if (gain != null && gainPct != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${Money.aed(gain / 100, decimals: false, sign: true)} (${pctText(gainPct!)}) vs paid',
                style: context.tt.bodySmall!.copyWith(
                  color: gain >= 0 ? c.positive : c.negative,
                ),
              ),
            ),
          const SizedBox(height: Space.xs),
          Text(
            pureGrams == null
                ? note
                : '${pureGrams!.toStringAsFixed(2)} g pure gold · $note',
            style: context.tt.bodySmall,
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Does the weight look right? Adjust it.',
                  style: context.tt.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Less 0.1 g',
                onPressed: onMinus,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                tooltip: 'More 0.1 g',
                onPressed: onPlus,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          Text(
            'Use the weight of the gold only. Stones and enamel are not gold and are not counted. '
            'This is the melt value, without making charges or a dealer margin.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// One piece: value, gain/loss, value over time, photos, details.
class JewelleryDetailScreen extends ConsumerWidget {
  const JewelleryDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(jewelleryProvider);
    final view = list.value?.where((v) => v.item.id == itemId).firstOrNull;
    final book = ref.watch(priceBookProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WealthIcon(WealthKind.jewellery, size: 28),
            const SizedBox(width: Space.sm),
            Flexible(
              child: Text(
                view?.item.name ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => leave(context),
        ),
        actions: [
          if (view != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showPulseSheet<void>(
                context,
                full: true,
                builder: (_) => AddJewellerySheet(initial: view.item),
              ),
            ),
        ],
      ),
      body: view == null
          ? (list.isLoading
                ? const SkeletonList(rows: 4)
                : const EmptyState(
                    icon: Icons.diamond_outlined,
                    title: 'Piece not found',
                    message: 'It may have been deleted.',
                  ))
          : _DetailBody(view, book),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody(this.view, this.book);
  final JewelleryView view;
  final PriceBook? book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final i = view.item, v = view.value;
    final history = ref.watch(jewelleryHistoryProvider(i.id)).value ?? const [];
    final gain = v.gainMinor, pct = v.gainPct;
    String g(double x) =>
        x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(2);
    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        PhotoStrip(i.photoPaths, size: 104),
        if (i.photoPaths.isNotEmpty) const SizedBox(height: Space.xl),
        HeroNumber(
          label: 'Worth today',
          value: v.valueMinor / 100,
          caption: gain == null || pct == null
              ? 'Add what you paid to see gain or loss'
              : '${Money.aed(gain / 100, decimals: false, sign: true)} (${pctText(pct)}) vs paid',
          captionColor: gain == null
              ? c.textTertiary
              : (gain >= 0 ? c.positive : c.negative),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xs,
            Space.gutter,
            0,
          ),
          child: Text(
            'Melt value: ${g(i.weightGrams)} g × ${i.purityLabel.split(' · ').first} × AED ${v.pricePerGram.toStringAsFixed(2)}/g (24K)'
            '${book?.origin == PriceOrigin.bundled ? ' · demo price' : ''}',
            style: context.tt.bodySmall,
          ),
        ),
        const SectionHeader('Value over time'),
        if (history.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: InspectLineChart(
              labels: [
                for (final (k, p) in history.indexed)
                  k == 0 || k == history.length - 1 || k == history.length ~/ 2
                      ? formatShort(p.date)
                      : '',
              ],
              title: (k) => formatDate(history[k].date),
              fill: true,
              height: 140,
              format: (x) => Money.aed(x, decimals: false),
              series: [
                ChartSeries('Value', [
                  for (final p in history) p.valueMinor / 100,
                ], c.accent),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'The chart fills in as the gold price moves: Pulse stores one value a day while the app is used.',
              style: context.tt.bodySmall,
            ),
          ),
        const SectionHeader('Details'),
        RowGroup(
          children: [
            OwnerRow(table: 'lines', id: 'jewel:${i.id}', title: i.name),
            _kv(context, 'Weight', '${g(i.weightGrams)} g'),
            _kv(context, 'Purity', i.purityLabel),
            _kv(context, 'Pure gold', '${g(v.pureGrams)} g'),
            if (i.purchasePriceMinor != null)
              _kv(
                context,
                'Paid',
                Money.aed(i.purchasePriceMinor! / 100, decimals: false),
              ),
            if (i.makingChargesMinor != null)
              _kv(
                context,
                'Making charges',
                Money.aed(i.makingChargesMinor! / 100, decimals: false),
              ),
            if (i.purchaseDate != null)
              _kv(context, 'Bought', formatDate(i.purchaseDate!)),
          ],
        ),
        if (i.notes != null) ...[
          const SectionHeader('Notes'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(i.notes!, style: context.tt.bodyMedium),
          ),
        ],
        const SizedBox(height: Space.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: PrimaryButton(
            label: 'Delete this piece',
            destructive: true,
            secondary: true,
            onPressed: () => _confirmDelete(context, ref, i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            0,
          ),
          child: Text(
            'Photos and details stay on this phone and are removed from it when you delete.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    JewelleryItem i,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${i.name}?'),
        content: const Text(
          'Its photos and value history are removed from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(wealthServiceProvider).deleteJewellery(i.id);
    invalidateWealth(ref);
    if (context.mounted) leave(context);
  }

  Widget _kv(BuildContext context, String k, String v) => ListRow(
    dense: true,
    title: k,
    trailing: Text(
      v,
      style: PulseTheme.amount(context.pc.textPrimary, size: 15),
    ),
  );
}

String formatShort(CalDate d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${m[d.month - 1]}';
}
