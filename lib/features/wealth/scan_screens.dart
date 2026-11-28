import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/capture_parser.dart';
import '../../core/engine/dates.dart';
import '../../core/engine/valuation.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/attachments.dart';
import '../../data/providers.dart';
import 'wealth_widgets.dart';

/// "Scan a bill or portfolio": take or choose a photo, read it on the phone,
/// review what was found, save. The same sheet takes a typed description
/// ("about 20g 22k gold bought 2023"), which is always saved as approximate.
///
/// The photo is read by on-device OCR and never uploaded. The recognised text
/// is shown and editable, so a misread number is one tap to fix.
class ScanSheet extends ConsumerStatefulWidget {
  const ScanSheet({super.key, this.initialText});
  final String? initialText;

  @override
  ConsumerState<ScanSheet> createState() => _ScanSheetState();
}

class _HoldingForm {
  _HoldingForm(HoldingDraft d)
    : draft = d,
      symbol = TextEditingController(text: d.symbol),
      quantity = TextEditingController(
        text: d.units == null
            ? ''
            : fmtNum(d.units!, maxDecimals: 4).replaceAll(',', ''),
      ),
      avg = TextEditingController(
        text: d.avgCost == null ? '' : d.avgCost!.toString(),
      ),
      approximate = d.approximate;
  final HoldingDraft draft;
  final TextEditingController symbol, quantity, avg;
  bool approximate;

  void dispose() {
    symbol.dispose();
    quantity.dispose();
    avg.dispose();
  }

  HoldingDraft toDraft() => HoldingDraft(
    symbol: symbol.text.trim().toUpperCase(),
    name: draft.name,
    quantity: parseNumber(quantity.text),
    avgCost: parseNumber(avg.text),
    price: draft.price,
    value: draft.value,
    currency: draft.currency,
    approximate: approximate,
    note: draft.note,
  );
}

class _FundForm {
  _FundForm(FundDraft d)
    : draft = d,
      name = TextEditingController(text: d.name),
      units = TextEditingController(
        text: d.unitsHeld == null
            ? ''
            : fmtNum(d.unitsHeld!, maxDecimals: 4).replaceAll(',', ''),
      ),
      invested = TextEditingController(
        text: d.invested == null
            ? ''
            : fmtNum(d.invested!, maxDecimals: 2).replaceAll(',', ''),
      ),
      sip = TextEditingController(
        text: d.sipAmountMinor == null
            ? ''
            : (d.sipAmountMinor! / 100).toStringAsFixed(0),
      ),
      sipDay = TextEditingController(text: d.sipDay?.toString() ?? '');
  final FundDraft draft;
  final TextEditingController name, units, invested, sip, sipDay;

  void dispose() {
    for (final c in [name, units, invested, sip, sipDay]) {
      c.dispose();
    }
  }

  int? get sipMinor => parseMinor(sip.text);
  int? get day {
    final d = int.tryParse(sipDay.text.trim());
    return d != null && d >= 1 && d <= 31 ? d : null;
  }

  FundDraft toDraft() {
    final u = parseNumber(units.text);
    final money = parseNumber(invested.text);
    final withSip = (sipMinor ?? 0) > 0 && day != null;
    return FundDraft(
      name: name.text.trim(),
      units: u,
      nav: draft.nav,
      invested: money,
      current: draft.current,
      sipAmountMinor: withSip ? sipMinor : null,
      sipDay: withSip ? day : null,
      approximate: draft.approximate,
      note: draft.note,
    );
  }
}

class _ScanSheetState extends ConsumerState<ScanSheet> {
  late final _text = TextEditingController(text: widget.initialText);
  Timer? _debounce;
  bool _reading = false, _fromImage = false, _busy = false;
  String? _imagePath, _error;

  CaptureResult _result = const CaptureResult(CaptureKind.unknown);

  // Gold form.
  final _goldName = TextEditingController();
  final _weight = TextEditingController();
  final _paid = TextEditingController();
  int _karat = 22;
  bool _karatKnown = false;
  CalDate? _date;
  bool _goldApprox = false;
  String? _goldNote;
  bool _hasGold = false;

  final List<_HoldingForm> _holdings = [];
  final List<_FundForm> _funds = [];

  @override
  void initState() {
    super.initState();
    if (_text.text.trim().isNotEmpty) _parse();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    _goldName.dispose();
    _weight.dispose();
    _paid.dispose();
    for (final h in _holdings) {
      h.dispose();
    }
    for (final f in _funds) {
      f.dispose();
    }
    super.dispose();
  }

  void _parse() {
    final t = _text.text.trim();
    CaptureResult r;
    if (t.isEmpty) {
      r = const CaptureResult(CaptureKind.unknown);
    } else if (_fromImage) {
      r = parseCapture(t);
      if (r.isEmpty) r = parseApproximate(t);
    } else {
      r = parseApproximate(t);
      if (r.isEmpty) r = parseCapture(t);
    }
    for (final h in _holdings) {
      h.dispose();
    }
    _holdings
      ..clear()
      ..addAll(r.holdings.map(_HoldingForm.new));
    for (final f in _funds) {
      f.dispose();
    }
    _funds
      ..clear()
      ..addAll(r.funds.map(_FundForm.new));
    final g = r.gold;
    _hasGold = g != null;
    if (g != null) {
      _goldName.text = g.name;
      _weight.text = g.weightGrams == null
          ? ''
          : fmtNum(g.weightGrams!, maxDecimals: 3).replaceAll(',', '');
      _paid.text = g.amountMinor == null
          ? ''
          : (g.amountMinor! / 100).toStringAsFixed(
              g.amountMinor! % 100 == 0 ? 0 : 2,
            );
      _karat = g.karat ?? 22;
      _karatKnown = g.karat != null;
      _date = g.date;
      _goldApprox = g.approximate || g.karat == null;
      _goldNote = g.note;
    }
    setState(() {
      _result = r;
      _error = null;
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _parse);
  }

  Future<void> _scan(PhotoSource source) async {
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final path = await ref.read(photoPickerProvider).pick(source);
      if (path == null) {
        if (mounted) setState(() => _reading = false);
        return;
      }
      final text = await ref.read(ocrServiceProvider).read(path);
      if (!mounted) return;
      _imagePath = path;
      _fromImage = true;
      _text.text = text;
      _reading = false;
      _parse();
      if (_result.isEmpty) {
        setState(
          () => _error = text.trim().isEmpty
              ? 'No text found in that photo. Try a sharper one, or describe it below.'
              : 'Could not find a bill or holdings in that text. You can fix the text below.',
        );
      }
    } on Object {
      if (mounted) {
        setState(() {
          _reading = false;
          _error = 'Could not open the camera or photos. Check the permission in Settings.';
        });
      }
    }
  }

  double? get _weightV => parseNumber(_weight.text);

  CaptureResult _build() => CaptureResult(
    _result.kind,
    gold: !_hasGold
        ? null
        : GoldDraft(
            name: _goldName.text.trim().isEmpty
                ? 'Gold'
                : _goldName.text.trim(),
            weightGrams: _weightV,
            karat: _karat,
            amountMinor: parseMinor(_paid.text),
            date: _date,
            approximate: _goldApprox,
            note: _goldNote,
          ),
    holdings: [for (final h in _holdings) h.toDraft()],
    funds: [for (final f in _funds) f.toDraft()],
  );

  int get _saveable {
    var n = 0;
    if (_hasGold && (_weightV ?? 0) > 0) n++;
    for (final h in _holdings) {
      final q = parseNumber(h.quantity.text) ?? h.draft.units;
      if (h.symbol.text.trim().isNotEmpty && q != null && q > 0) n++;
    }
    for (final f in _funds) {
      final u = parseNumber(f.units.text) ?? f.draft.unitsHeld;
      final amount = f.draft.current ?? parseNumber(f.invested.text);
      if (f.name.text.trim().isNotEmpty &&
          ((u != null && u > 0) || (amount != null && amount > 0))) {
        n++;
      }
    }
    return n;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(investingServiceProvider)
          .applyCapture(
            _build(),
            source: _fromImage ? 'screenshot' : 'typed',
            photoSources: _hasGold && _imagePath != null
                ? [_imagePath!]
                : const [],
          );
      invalidateWealth(ref);
      if (!mounted) return;
      final parts = [
        if (r.goldAdded > 0) 'gold added',
        if (r.holdingsAdded > 0)
          '${r.holdingsAdded} ${r.holdingsAdded == 1 ? 'holding' : 'holdings'} added',
        if (r.holdingsUpdated > 0) '${r.holdingsUpdated} updated',
        if (r.fundsAdded > 0)
          '${r.fundsAdded} ${r.fundsAdded == 1 ? 'fund' : 'funds'} added',
        if (r.fundsUpdated > 0)
          '${r.fundsUpdated} ${r.fundsUpdated == 1 ? 'fund' : 'funds'} updated',
        if (r.sipsAdded > 0)
          '${r.sipsAdded} ${r.sipsAdded == 1 ? 'SIP' : 'SIPs'} tracked',
        if (r.fundsUnmatched > 0) '${r.fundsUnmatched} without a live NAV',
      ];
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty ? 'Nothing to save' : 'Saved: ${parts.join(', ')}',
          ),
        ),
      );
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final ocr = ref.watch(ocrServiceProvider);
    final n = _saveable;
    return SheetScaffold(
      title: 'Scan or describe',
      subtitle: 'Read on this phone. The photo is never uploaded.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ocr.available)
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Camera',
                    icon: Icons.photo_camera_outlined,
                    secondary: true,
                    loading: _reading,
                    onPressed: () => _scan(PhotoSource.camera),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: PrimaryButton(
                    label: 'Photos',
                    icon: Icons.photo_library_outlined,
                    secondary: true,
                    onPressed: _reading
                        ? null
                        : () => _scan(PhotoSource.gallery),
                  ),
                ),
              ],
            ),
          FieldLabel(
            _fromImage ? 'What was read (edit to fix)' : 'Or describe it',
          ),
          TextField(
            controller: _text,
            minLines: _fromImage ? 4 : 2,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'about 20g 22k gold bought 2023\n50 shares of VOO, bought 2022, avg \$400',
            ),
            onChanged: _onChanged,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Text(
                _error!,
                style: context.tt.bodySmall!.copyWith(color: c.negative),
              ),
            ),
          if (!_result.isEmpty) ...[
            const SizedBox(height: Space.lg),
            const Hairline(),
            FieldLabel(_banner()),
            if (_hasGold) _goldForm(context),
            for (var i = 0; i < _holdings.length; i++) _holdingForm(context, i),
            for (var i = 0; i < _funds.length; i++) _fundForm(context, i),
            const SizedBox(height: Space.xl),
            PrimaryButton(
              label: n == 0
                  ? 'Fill in a weight or quantity'
                  : 'Save $n ${n == 1 ? 'item' : 'items'}',
              loading: _busy,
              onPressed: n == 0 ? null : _save,
            ),
          ] else if (_text.text.trim().isNotEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Text(
                'Nothing recognised yet. Try a weight and karat for gold, or a ticker and quantity for stocks.',
                style: context.tt.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _banner() {
    final what = switch (_result.kind) {
      CaptureKind.goldBill => _fromImage ? 'Looks like a gold bill' : 'Gold',
      CaptureKind.portfolio =>
        _holdings.length == 1 ? 'One holding' : '${_holdings.length} holdings',
      CaptureKind.mutualFunds =>
        _funds.length == 1
            ? 'One mutual fund'
            : '${_funds.length} mutual funds',
      CaptureKind.unknown => 'Found',
    };
    return '$what · check before saving';
  }

  Widget _goldForm(BuildContext context) {
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _goldName,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What is it (chain, bar, bangles)',
          ),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Weight',
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
                selected: _karat == k,
                onTap: () => setState(() {
                  _karat = k;
                  _karatKnown = true;
                }),
              ),
          ],
        ),
        if (!_karatKnown)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              'Karat not found, so 22K is assumed. Pick the right one.',
              style: context.tt.bodySmall,
            ),
          ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _paid,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'What you paid (optional)',
            prefixIcon: CurrencyPrefix('AED'),
            prefixIconConstraints: kCurrencyPrefixConstraints,
          ),
        ),
        const SizedBox(height: Space.sm),
        ListRow(
          dense: true,
          title: _date == null
              ? 'Purchase date (optional)'
              : formatDate(_date!),
          subtitle:
              _date != null &&
                  _goldApprox &&
                  _date!.day == 1 &&
                  _date!.month == 7
              ? 'Only the year was known'
              : null,
          chevron: true,
          onTap: () async {
            final d = await pickDate(context, initial: _date);
            if (d != null) setState(() => _date = d);
          },
        ),
        _approxSwitch(
          context,
          _goldApprox,
          (v) => setState(() => _goldApprox = v),
          note: _goldNote,
        ),
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(
            'Valued live from the gold price once saved.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _holdingForm(BuildContext context, int i) {
    final h = _holdings[i];
    final c = context.pc;
    return Container(
      margin: const EdgeInsets.only(top: Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: h.symbol,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'Ticker'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: c.textSecondary,
                ),
                onPressed: () => setState(() {
                  _holdings.removeAt(i).dispose();
                  if (_holdings.isEmpty && _funds.isEmpty && !_hasGold)
                    _result = const CaptureResult(CaptureKind.unknown);
                }),
              ),
            ],
          ),
          if (h.draft.name != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(h.draft.name!, style: context.tt.bodySmall),
            ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: h.quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: 'Quantity'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: TextField(
                  controller: h.avg,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Avg cost',
                    prefixIcon: CurrencyPrefix(h.draft.currency),
                    prefixIconConstraints: kCurrencyPrefixConstraints,
                  ),
                ),
              ),
            ],
          ),
          _approxSwitch(
            context,
            h.approximate,
            (v) => setState(() => h.approximate = v),
            note: h.draft.note,
          ),
        ],
      ),
    );
  }

  Widget _fundForm(BuildContext context, int i) {
    final f = _funds[i];
    final c = context.pc;
    return Container(
      margin: const EdgeInsets.only(top: Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: f.name,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Fund name'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: c.textSecondary,
                ),
                onPressed: () => setState(() {
                  _funds.removeAt(i).dispose();
                  if (_holdings.isEmpty && _funds.isEmpty && !_hasGold) {
                    _result = const CaptureResult(CaptureKind.unknown);
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: f.units,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: 'Units'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: TextField(
                  controller: f.invested,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Invested',
                    prefixIcon: CurrencyPrefix('₹'),
                    prefixIconConstraints: kCurrencyPrefixConstraints,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: f.sip,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'SIP (optional)',
                    prefixIcon: CurrencyPrefix('₹'),
                    prefixIconConstraints: kCurrencyPrefixConstraints,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: f.sipDay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Day 1-31'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              f.draft.note ?? 'Matched to the official fund list for a live NAV. A SIP is tracked monthly and you confirm each instalment.',
              style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approxSwitch(
    BuildContext context,
    bool value,
    ValueChanged<bool> onChanged, {
    String? note,
  }) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Approximate', style: context.tt.titleSmall),
                Text(
                  value
                      ? (note ?? 'Marked with a ~ everywhere it is shown')
                      : 'These figures are exact',
                  style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
