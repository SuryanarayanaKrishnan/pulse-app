import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
import 'wealth_widgets.dart';

const fundCurrencies = ['INR', 'AED', 'USD', 'EUR', 'GBP'];

/// Add a fund: search Indian schemes (through the Pulse price service) or
/// enter any fund by hand. Units and cost are yours and stay on the phone;
/// search sends only the words you type.
class AddFundSheet extends ConsumerStatefulWidget {
  const AddFundSheet({super.key, this.initial});
  final FundHolding? initial;

  @override
  ConsumerState<AddFundSheet> createState() => _AddFundSheetState();
}

enum _Mode { search, manual }

class _AddFundSheetState extends ConsumerState<AddFundSheet> {
  late _Mode _mode = widget.initial == null || widget.initial!.isIndian ? _Mode.search : _Mode.manual;
  final _query = TextEditingController();
  Timer? _debounce;
  List<FundScheme> _hits = const [];
  bool _searching = false;
  String? _searchError;

  FundScheme? _scheme;
  FundNav? _latest;
  bool _loadingNav = false;

  late final _name = TextEditingController(text: widget.initial?.name);
  late final _units = TextEditingController(text: widget.initial == null ? '' : widget.initial!.units.toString());
  late final _nav = TextEditingController(text: widget.initial == null ? '' : widget.initial!.nav.toString());
  late final _cost = TextEditingController(text: widget.initial?.avgCostNav?.toString() ?? '');
  late final _sip = TextEditingController(
    text: widget.initial?.sipAmountMinor == null ? '' : (widget.initial!.sipAmountMinor! / 100).toStringAsFixed(0),
  );
  late final _sipDay = TextEditingController(text: widget.initial?.sipDay?.toString() ?? '');
  late String _currency = widget.initial?.currency ?? 'AED';
  bool _busy = false;

  bool get _editing => widget.initial != null;
  bool get _hasPick => _scheme != null || (_editing && widget.initial!.isIndian);

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_query, _name, _units, _nav, _cost, _sip, _sipDay]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _hits = const [];
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final r = await ref.read(wealthServiceProvider).searchFunds(q);
      if (mounted && q == _query.text) setState(() => _hits = r);
    } on Object {
      if (mounted) setState(() => _searchError = 'Search is not reachable right now. You can enter the fund by hand.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _choose(FundScheme s) async {
    setState(() {
      _scheme = s;
      _currency = 'INR';
      _loadingNav = true;
    });
    try {
      final nav = await ref.read(fundLookupProvider).latest(s.code);
      if (mounted) {
        setState(() {
          _latest = nav;
          if (nav != null) _nav.text = nav.nav.toString();
        });
      }
    } on Object {
      // Offline: the user can type the NAV.
    } finally {
      if (mounted) setState(() => _loadingNav = false);
    }
  }

  double? get _unitsV {
    final v = parseNumber(_units.text);
    return v == null || v <= 0 ? null : v;
  }

  double? get _navV {
    final v = parseNumber(_nav.text);
    return v == null || v <= 0 ? null : v;
  }

  bool get _valid {
    if (_unitsV == null || _navV == null) return false;
    if (_mode == _Mode.manual || (_editing && !widget.initial!.isIndian)) return _name.text.trim().isNotEmpty;
    return _hasPick;
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _busy = true);
    try {
      final old = widget.initial;
      final indian = _mode == _Mode.search && _hasPick;
      final sipDay = int.tryParse(_sipDay.text.trim());
      final sipMinor = parseMinor(_sip.text);
      final hasSip = sipMinor != null && sipMinor > 0 && sipDay != null && sipDay >= 1 && sipDay <= 31;
      final navMarket = indian && _latest != null && _navV == _latest!.nav;
      final f = FundHolding(
        id: old?.id ?? newWealthId(),
        kind: indian ? 'india_mf' : 'manual',
        schemeCode: indian ? (_scheme?.code ?? old?.schemeCode) : null,
        name: indian ? (_scheme?.name ?? old!.name) : _name.text.trim(),
        currency: indian ? 'INR' : _currency,
        units: _unitsV!,
        avgCostNav: parseNumber(_cost.text),
        nav: _navV!,
        navDate: navMarket ? _latest!.navDate : (old != null && old.nav == _navV ? old.navDate : DateTime.now().toIso8601String().substring(0, 10)),
        navSource: navMarket ? 'market' : (old != null && old.nav == _navV ? old.navSource : 'manual'),
        navFetchedAt: navMarket ? DateTime.now().toUtc() : old?.navFetchedAt,
        sipAmountMinor: hasSip ? sipMinor : null,
        sipDay: hasSip ? sipDay : null,
        createdAt: old?.createdAt ?? DateTime.now(),
      );
      await ref.read(wealthServiceProvider).saveFund(f);
      invalidateWealth(ref);
      if (mounted) Navigator.of(context).pop(f.id);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That did not save. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final canSearch = ref.watch(fundLookupProvider).available;
    final detailsVisible = _mode == _Mode.manual || _hasPick;
    return SheetScaffold(
      title: _editing ? 'Edit fund' : 'Add a mutual fund',
      subtitle: 'Units and cost stay on this phone.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_editing)
            Row(
              children: [
                Pill('Search funds', selected: _mode == _Mode.search, onTap: () => setState(() => _mode = _Mode.search)),
                const SizedBox(width: Space.sm),
                Pill('Enter by hand', selected: _mode == _Mode.manual, onTap: () => setState(() => _mode = _Mode.manual)),
              ],
            ),
          if (_mode == _Mode.search && !_hasPick) ...[
            const SizedBox(height: Space.lg),
            if (!canSearch)
              EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Search needs the Pulse price service',
                message: 'Indian fund search runs through your Pulse server, which is not set up here. Enter the fund by hand instead.',
                action: PrimaryButton(label: 'Enter by hand', expand: false, onPressed: () => setState(() => _mode = _Mode.manual)),
              )
            else ...[
              TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search by fund name, like "flexi cap"', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: _onQuery,
              ),
              const SizedBox(height: Space.md),
              if (_searching) const SkeletonList(rows: 3, height: 48),
              if (_searchError != null) Text(_searchError!, style: context.tt.bodySmall!.copyWith(color: c.negative)),
              if (!_searching && _hits.isEmpty && _query.text.trim().length >= 2 && _searchError == null)
                Text('No schemes found. Try fewer words, or enter the fund by hand.', style: context.tt.bodySmall),
              if (_hits.isNotEmpty)
                RowGroup(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final h in _hits.take(12))
                      ListRow(dense: true, title: h.name, subtitle: 'Scheme ${h.code}', chevron: true, onTap: () => _choose(h)),
                  ],
                ),
            ],
          ],
          if (detailsVisible) ...[
            const SizedBox(height: Space.lg),
            if (_mode == _Mode.search && _hasPick)
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(Radii.md)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_scheme?.name ?? widget.initial!.name, style: context.tt.bodyLarge),
                          const SizedBox(height: 2),
                          Text(
                            _loadingNav
                                ? 'Looking up the latest NAV…'
                                : _latest != null
                                ? 'Latest NAV INR ${_latest!.nav.toStringAsFixed(4)} · ${_latest!.navDate}'
                                : 'NAV not found. Type it in below.',
                            style: context.tt.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!_editing)
                      TextAction('Change', onTap: () => setState(() {
                        _scheme = null;
                        _latest = null;
                      })),
                  ],
                ),
              ),
            if (_mode == _Mode.manual && !(_editing && widget.initial!.isIndian)) ...[
              TextField(
                controller: _name,
                autofocus: !_editing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Fund name'),
                onChanged: (_) => setState(() {}),
              ),
              const FieldLabel('Currency of the NAV'),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [for (final k in fundCurrencies) Pill(k, selected: _currency == k, onTap: () => setState(() => _currency = k))],
              ),
            ],
            const SizedBox(height: Space.md),
            TextField(
              controller: _units,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Units held'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _nav,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: 'Current NAV per unit', prefixText: '${_mode == _Mode.search && _hasPick ? 'INR' : _currency}  '),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: 'Average cost per unit (optional)', prefixText: '${_mode == _Mode.search && _hasPick ? 'INR' : _currency}  '),
            ),
            const FieldLabel('Monthly SIP (optional)'),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _sip,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(hintText: 'Amount'),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _sipDay,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Day (1-31)'),
                  ),
                ),
              ],
            ),
            if (_valid)
              _ValuePreview(units: _unitsV!, nav: _navV!, cost: parseNumber(_cost.text), currency: _mode == _Mode.search && _hasPick ? 'INR' : _currency),
            const SizedBox(height: Space.xl),
            PrimaryButton(label: _editing ? 'Save changes' : 'Add fund', loading: _busy, onPressed: _valid ? _save : null),
          ],
          if (!_editing) ...[
            const SizedBox(height: Space.md),
            const Hairline(),
            ListRow(
              leading: IconWell(Icons.picture_as_pdf_outlined, color: c.accent),
              title: 'Import a CAMS or KFintech statement',
              subtitle: 'Brings in every fund at once',
              chevron: true,
              onTap: () => showPulseSheet<void>(context, builder: (_) => const CasImportSheet()),
            ),
          ],
        ],
      ),
    );
  }
}

class _ValuePreview extends ConsumerWidget {
  const _ValuePreview({required this.units, required this.nav, required this.cost, required this.currency});
  final double units, nav;
  final double? cost;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(priceBookProvider).value;
    final v = valueFund(units: units, nav: nav, avgCostNav: cost, fxToAed: book?.fx(currency));
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Text(
        v.valueAedMinor == null
            ? 'Worth $currency ${Money.number(v.valueNativeMinor / 100, decimals: true)}. No exchange rate for $currency yet, so it is left out of net worth.'
            : 'Worth ${Money.aed(v.valueAedMinor! / 100, decimals: false)}'
                  '${v.gainPct == null ? '' : ' · ${pctText(v.gainPct!)} on cost'}',
        key: const Key('fund-preview'),
        style: context.tt.bodyMedium,
      ),
    );
  }
}

/// Entry point for CAS statements. Reading a statement means handling the
/// PAN-protected PDF and your holdings, which would have to be sent to a
/// server; Pulse keeps that on the phone, and an on-device reader is not built
/// yet. The file is not read and no password is asked for or stored.
class CasImportSheet extends StatefulWidget {
  const CasImportSheet({super.key});
  @override
  State<CasImportSheet> createState() => _CasImportSheetState();
}

class _CasImportSheetState extends State<CasImportSheet> {
  String? _picked;

  Future<void> _choose() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
      final f = files.firstOrNull;
      if (f != null && mounted) setState(() => _picked = f.name);
    } on Object {
      if (mounted) setState(() => _picked = '');
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Import a CAS statement',
    subtitle: 'CAMS and KFintech consolidated account statement (PDF).',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(label: 'Choose the PDF', icon: Icons.upload_file_outlined, secondary: true, onPressed: _choose),
        if (_picked != null) ...[
          const SizedBox(height: Space.lg),
          Container(
            key: const Key('cas-coming-soon'),
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: context.pc.surfaceElevated, borderRadius: BorderRadius.circular(Radii.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coming soon', style: context.tt.bodyLarge),
                const SizedBox(height: Space.xs),
                Text(
                  'Reading CAS statements is not available yet. The file was not opened or sent anywhere, '
                  'and no password was asked for or stored. For now, add each fund by search or by hand.',
                  style: context.tt.bodySmall,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        Text(
          'Your statement holds your PAN-linked holdings, so Pulse will only read it on this phone.',
          style: context.tt.bodySmall!.copyWith(color: context.pc.textTertiary),
        ),
      ],
    ),
  );
}

class FundDetailScreen extends ConsumerStatefulWidget {
  const FundDetailScreen({super.key, required this.fundId});
  final String fundId;

  @override
  ConsumerState<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends ConsumerState<FundDetailScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final n = await ref.read(wealthServiceProvider).refreshNavs();
    invalidateWealth(ref);
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(n > 0 ? 'NAV updated.' : 'Could not reach the NAV source. Showing the last NAV.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final funds = ref.watch(fundsProvider);
    final view = funds.value?.where((x) => x.holding.id == widget.fundId).firstOrNull;
    final svc = ref.watch(wealthServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(view?.holding.name ?? '', overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (view != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showPulseSheet<void>(context, full: true, builder: (_) => AddFundSheet(initial: view.holding)),
            ),
        ],
      ),
      body: view == null
          ? (funds.isLoading
                ? const SkeletonList(rows: 3)
                : const EmptyState(icon: Icons.pie_chart_outline_rounded, title: 'Fund not found', message: 'It may have been deleted.'))
          : _body(context, view, svc, c),
    );
  }

  Widget _body(BuildContext context, FundView view, WealthService svc, PulseColors c) {
    final f = view.holding, v = view.value;
    final gain = v.gainAedMinor, pct = v.gainPct;
    String u(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(3);
    final navAge = f.navFetchedAt != null ? 'fetched ${ago(f.navFetchedAt!)}' : (f.navDate != null ? 'as of ${f.navDate}' : '');
    return ListView(
      padding: const EdgeInsets.only(bottom: 60),
      children: [
        HeroNumber(
          label: 'Value',
          value: (v.valueAedMinor ?? 0) / 100,
          caption: v.valueAedMinor == null
              ? 'No exchange rate for ${f.currency}: not counted in net worth'
              : gain == null || pct == null
              ? 'Add your average cost to see gain or loss'
              : '${Money.aed(gain / 100, decimals: false, sign: true)} (${pctText(pct)}) on cost',
          captionColor: gain == null ? c.textTertiary : (gain >= 0 ? c.positive : c.negative),
        ),
        const SectionHeader('Holding'),
        RowGroup(
          children: [
            _kv(context, 'Units', u(f.units)),
            if (f.avgCostNav != null) _kv(context, 'Average cost', '${f.currency} ${f.avgCostNav!.toStringAsFixed(4)}'),
            ListRow(
              dense: true,
              title: 'NAV',
              subtitle: '${f.navSource == 'market' ? 'Market' : 'Entered by you'}${navAge.isEmpty ? '' : ' · $navAge'}',
              trailing: Text('${f.currency} ${f.nav.toStringAsFixed(4)}', style: PulseTheme.amount(c.textPrimary, size: 15)),
            ),
            _kv(context, 'Value in ${f.currency}', Money.number(v.valueNativeMinor / 100, decimals: true)),
            if (v.fxRate != null && f.currency != 'AED') _kv(context, 'Exchange rate', '1 ${f.currency} = AED ${v.fxRate!.toStringAsFixed(4)}'),
            if (f.hasSip)
              ListRow(
                dense: true,
                title: 'SIP',
                subtitle: 'Next ${formatDate(nextSipDate(f.sipDay!, svc.today))}',
                trailing: Text('${f.currency} ${(f.sipAmountMinor! / 100).toStringAsFixed(0)} / month', style: PulseTheme.amount(c.textPrimary, size: 15)),
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              if (f.isIndian && svc.fundLookup.available)
                PrimaryButton(label: 'Refresh NAV', icon: Icons.refresh_rounded, loading: _refreshing, onPressed: _refresh)
              else
                PrimaryButton(
                  label: 'Update NAV',
                  icon: Icons.edit_outlined,
                  onPressed: () => showPulseSheet<void>(context, full: true, builder: (_) => AddFundSheet(initial: f)),
                ),
              const SizedBox(height: Space.sm),
              PrimaryButton(
                label: 'Delete this fund',
                destructive: true,
                secondary: true,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete ${f.name}?'),
                      content: const Text('It is removed from your net worth.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await svc.deleteFund(f.id);
                  invalidateWealth(ref);
                  if (context.mounted) context.pop();
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
          child: Text(
            f.isIndian
                ? 'NAV comes from AMFI data via mfapi.in. Only the scheme code is looked up; your units never leave the phone.'
                : 'This NAV is the one you entered. Update it whenever you check the fund.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String k, String v) => ListRow(
    dense: true,
    title: k,
    trailing: Text(v, style: PulseTheme.amount(context.pc.textPrimary, size: 15)),
  );
}
