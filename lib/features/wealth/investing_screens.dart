import 'wealth_icons.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/investing.dart';
import '../../core/engine/markets.dart';
import '../../core/engine/valuation.dart' show dueText;
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../core/vault/vault_models.dart';
import '../../core/engine/live_quote.dart';
import '../../data/investing_service.dart';
import '../../data/local/live_prices.dart';
import '../../data/local/wealth_store.dart' show newWealthId;
import '../../data/providers.dart';
import '../../data/wealth_models.dart';
import '../net_worth/wealth_screen.dart' show ago;
import '../vault/held_at.dart';
import 'live_widgets.dart';
import 'scan_screens.dart';
import 'wealth_widgets.dart';

const _currencies = ['USD', 'AED', 'INR', 'EUR', 'GBP'];

String _ccy(String code, double v, {bool decimals = true}) {
  final sym = switch (code) {
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    'INR' => '₹',
    _ => '$code ',
  };
  return '$sym${Money.number(v, decimals: decimals)}';
}

Future<void> openScan(BuildContext context, {String? text}) =>
    showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => ScanSheet(initialText: text),
    );

/// Stock and ETF positions: from screenshots, typed estimates or recurring
/// buys. Value and P&L come from the last close, converted to AED.
class InvestmentsSection extends ConsumerStatefulWidget {
  const InvestmentsSection({super.key});
  @override
  ConsumerState<InvestmentsSection> createState() => _InvestmentsSectionState();
}

class _InvestmentsSectionState extends ConsumerState<InvestmentsSection> {
  bool _refreshing = false, _didAuto = false;

  /// [auto] is the quiet refresh when the section first shows: no spinner,
  /// and the throttle applies. The button forces one.
  Future<void> _refresh({bool auto = false}) async {
    if (!mounted) return;
    if (!auto) setState(() => _refreshing = true);
    try {
      final investing = ref.read(investingServiceProvider);
      final prices = ref.read(livePriceServiceProvider);
      final n = await investing.refreshPrices();
      final live = await prices.refresh(force: !auto);
      if (mounted && (n > 0 || live.anyUpdated)) invalidateWealth(ref);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final list = ref.watch(stockViewsProvider).value ?? const [];
    if (list.isNotEmpty && !_didAuto) {
      _didAuto = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(auto: true));
    }
    void add() => showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => const AddHoldingSheet(),
    );
    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Stocks and ETFs',
            action: 'Scan',
            onAction: () => openScan(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Snap a portfolio screenshot, or just type "50 shares of VOO". Pulse reads it on this phone and tracks live price and profit.',
              style: context.tt.bodySmall,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: TextAction('Add by hand', onTap: add),
            ),
          ),
        ],
      );
    }
    final totalAed = list.fold<int>(
      0,
      (a, v) => a + (v.value.valueAedMinor ?? 0),
    );
    final costAed = list.every((v) => v.value.costAedMinor != null)
        ? list.fold<int>(0, (a, v) => a + v.value.costAedMinor!)
        : null;
    final stale = list.any((v) => v.priceStale);
    final newest = [
      for (final v in list)
        if (v.holding.priceAt != null) v.holding.priceAt!,
    ].fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Stocks and ETFs',
          action: 'Scan',
          onAction: () => openScan(context),
        ),
        RowGroup(
          children: [
            for (final v in list)
              ListRow(
                leading: const WealthIcon(WealthKind.stock, size: 32),
                title: v.holding.title,
                subtitle: _holdingLine(v),
                chevron: true,
                onTap: () => showPulseSheet<void>(
                  context,
                  full: true,
                  builder: (_) => AddHoldingSheet(initial: v.holding),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v.value.valueAedMinor == null
                          ? _ccy(
                              v.holding.currency,
                              v.value.valueNativeMinor / 100,
                              decimals: false,
                            )
                          : '${v.holding.approximate ? '~' : ''}${Money.aed(v.value.valueAedMinor! / 100, decimals: false)}',
                      style: PulseTheme.amount(c.textPrimary, size: 15),
                    ),
                    if (v.value.gainPct != null)
                      Text(
                        pctText(v.value.gainPct!),
                        style: context.tt.bodySmall!.copyWith(
                          color: v.value.gainPct! >= 0
                              ? c.positive
                              : c.negative,
                        ),
                      ),
                    DayChangeText(
                      quote: ref
                          .watch(liveQuotesProvider)
                          .value?[LivePriceService.stockKey(v.holding.symbol)],
                      quantity: v.holding.quantity,
                      currency: v.holding.currency,
                    ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${Money.aed(totalAed / 100, decimals: false)}'
                  '${costAed == null || costAed <= 0 ? '' : ' · ${pctText((totalAed - costAed) / costAed * 100)} overall'}'
                  '${newest == null ? '' : ' · ${stale ? 'saved prices' : 'prices'} ${ago(newest)}'}',
                  style: context.tt.bodySmall,
                ),
              ),
              _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Refresh prices',
                      visualDensity: VisualDensity.compact,
                      onPressed: _refresh,
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: c.textSecondary,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  String _holdingLine(StockView v) {
    final h = v.holding;
    final qty = h.quantity == h.quantity.roundToDouble()
        ? h.quantity.toStringAsFixed(0)
        : fmtNum(h.quantity, maxDecimals: 4);
    final price = h.lastPrice == null
        ? 'no price yet'
        : _ccy(h.currency, h.lastPrice!);
    final asOf =
        h.priceSource != null && h.priceSource!.startsWith('last close ')
        ? '\n${asOfLabel(h.priceSource!.substring(11), DateTime.now(), fund: false)}'
        : '';
    return '${h.approximate ? '~' : ''}$qty × $price${v.priceStale && h.lastPrice != null ? ' · saved' : ''}${h.approximate ? ' · approximate' : ''}$asOf';
  }
}

/// Recurring investing rules, buys waiting for a yes or no, and how well the
/// plan has been kept.
class InvestingPlanSection extends ConsumerWidget {
  const InvestingPlanSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final rules = ref.watch(ruleViewsProvider).value ?? const [];
    final pending = ref.watch(pendingBuysProvider).value ?? const [];
    void add() => showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => const AddRuleSheet(),
    );
    if (rules.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('Investing plan', action: 'Add', onAction: add),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Say it once: "buy \$200 of VOO monthly" or "SIP 5000 in Parag Parikh Flexi Cap". Pulse reminds you each time and tracks whether you kept to it.',
              style: context.tt.bodySmall,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Investing plan', action: 'Add', onAction: add),
        for (final p in pending.take(3))
          _PendingCard(rule: p.rule, occurrence: p.occurrence),
        RowGroup(
          children: [
            for (final v in rules)
              ListRow(
                leading: Opacity(
                  opacity: v.rule.active ? 1 : 0.5,
                  child: const WealthIcon(WealthKind.investingRule, size: 32),
                ),
                title:
                    '${_ccy(v.rule.currency, v.rule.amountMinor / 100, decimals: v.rule.amountMinor % 100 != 0)} into ${v.rule.label}',
                subtitle: !v.rule.active
                    ? 'Paused'
                    : '${v.rule.cadenceLabel}${v.next == null ? '' : ' · next ${formatDate(v.next!)}'}',
                chevron: true,
                onTap: () => showPulseSheet<void>(
                  context,
                  full: true,
                  builder: (_) => AddRuleSheet(initial: v.rule),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v.adherence.summary, style: context.tt.bodyMedium),
                    if (v.adherence.streak >= 2)
                      Text(
                        '${v.adherence.streak} in a row',
                        style: context.tt.bodySmall!.copyWith(
                          color: c.positive,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.rule, required this.occurrence});
  final InvestRule rule;
  final RuleOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final amount = _ccy(
      rule.currency,
      occurrence.amountMinor / 100,
      decimals: occurrence.amountMinor % 100 != 0,
    );
    final today = toDubaiDate(DateTime.now());
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.sm,
      ),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rule.isFund
                ? 'Did your $amount SIP into ${rule.label} go through?'
                : 'Did you buy $amount of ${rule.symbol}?',
            style: context.tt.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Planned ${dueText(occurrence.due, today)} · ${formatDate(occurrence.due)}',
            style: context.tt.bodySmall,
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Yes, bought',
                  onPressed: () => showPulseSheet<void>(
                    context,
                    builder: (_) =>
                        ConfirmBuySheet(rule: rule, occurrence: occurrence),
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: PrimaryButton(
                  label: 'Skipped',
                  secondary: true,
                  onPressed: () async {
                    await ref
                        .read(investingServiceProvider)
                        .skipBuy(occurrence.id);
                    invalidateWealth(ref);
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await ref
                    .read(investingServiceProvider)
                    .remindTomorrow(occurrence, rule);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Not yet. I will ask again tomorrow morning.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Not yet, remind me tomorrow'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirm a planned buy at the price it actually went through at.
class ConfirmBuySheet extends ConsumerStatefulWidget {
  const ConfirmBuySheet({
    super.key,
    required this.rule,
    required this.occurrence,
  });
  final InvestRule rule;
  final RuleOccurrence occurrence;
  @override
  ConsumerState<ConfirmBuySheet> createState() => _ConfirmBuySheetState();
}

class _ConfirmBuySheetState extends ConsumerState<ConfirmBuySheet> {
  late final _price = TextEditingController();
  late final _amount = TextEditingController(
    text: (widget.occurrence.amountMinor / 100).toStringAsFixed(
      widget.occurrence.amountMinor % 100 == 0 ? 0 : 2,
    ),
  );
  bool _busy = false;
  double? _lastNav;

  @override
  void initState() {
    super.initState();
    if (widget.rule.isFund) {
      // Blank NAV = today's official NAV; the last one is shown as a hint.
      ref.read(wealthServiceProvider).fundViews().then((all) {
        final f = all
            .map((v) => v.holding)
            .where((e) => e.id == widget.rule.fundId)
            .firstOrNull;
        if (f != null && mounted) setState(() => _lastNav = f.nav);
      });
      return;
    }
    ref.read(investingStoreProvider).holdings().then((all) {
      final h = all.where((e) => e.symbol == widget.rule.symbol).firstOrNull;
      if (h?.lastPrice != null && mounted)
        setState(() => _price.text = h!.lastPrice!.toString());
    });
  }

  @override
  void dispose() {
    _price.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _p => parseNumber(_price.text);
  double? get _a => parseNumber(_amount.text);

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(investingServiceProvider)
        .confirmBuy(widget.occurrence.id, price: _p, amount: _a);
    if (!mounted) return;
    if (ok) {
      invalidateWealth(ref);
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    final units = _p != null && _p! > 0 && _a != null ? _a! / _p! : null;
    final fund = r.isFund;
    return SheetScaffold(
      title: fund ? 'SIP into ${r.label}' : 'Bought ${r.symbol}',
      subtitle: fund
          ? 'Planned for ${formatDate(widget.occurrence.due)}. Leave the NAV blank to use the official NAV; type the one on your confirmation if it differs.'
          : 'Planned for ${formatDate(widget.occurrence.due)}. Use the price your broker filled at.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Amount invested',
              prefixIcon: CurrencyPrefix(r.currency),
 prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _price,
            autofocus: !fund,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: fund
                  ? (_lastNav == null
                        ? 'NAV per unit (optional)'
                        : 'NAV per unit (last ${fmtNum(_lastNav!, maxDecimals: 4)})')
                  : 'Price per share',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (units != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Text(
                'That is ${fmtNum(units, maxDecimals: 4)} ${fund ? 'units' : 'shares'}.',
                style: context.tt.bodySmall,
              ),
            ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: fund ? 'Add units' : 'Add to holding',
            loading: _busy,
            onPressed: (fund || (_p != null && _p! > 0)) && (_a ?? 0) > 0
                ? _save
                : null,
          ),
        ],
      ),
    );
  }
}

/// Add or edit a stock or ETF by hand.
class AddHoldingSheet extends ConsumerStatefulWidget {
  const AddHoldingSheet({super.key, this.initial});
  final StockHolding? initial;
  @override
  ConsumerState<AddHoldingSheet> createState() => _AddHoldingSheetState();
}

class _AddHoldingSheetState extends ConsumerState<AddHoldingSheet> {
  late final _symbol = TextEditingController(text: widget.initial?.symbol);
  late final _qty = TextEditingController(
    text: widget.initial == null
        ? ''
        : fmtNum(widget.initial!.quantity, maxDecimals: 6).replaceAll(',', ''),
  );
  late final _avg = TextEditingController(
    text: widget.initial?.avgCost?.toString() ?? '',
  );
  late final _price = TextEditingController(
    text: widget.initial?.lastPrice?.toString() ?? '',
  );
  late String _currency = widget.initial?.currency ?? 'USD';
  late Exchange _market = widget.initial == null
      ? Exchange.us
      : listingOf(widget.initial!.symbol).exchange;
  late bool _approx = widget.initial?.approximate ?? false;
  bool _busy = false;
  final _platform = TextEditingController();
  VaultEntry? _vaultEntry;

  @override
  void initState() {
    super.initState();
    final base = widget.initial;
    if (base == null) return;
    // "Held at" lives in the family vault, so nominees can find the account.
    ref.read(vaultServiceProvider).entries().then((all) {
      final e = all
          .where((x) => x.sourceRef == 'asset:stock:${base.id}')
          .firstOrNull;
      if (e != null && mounted) {
        _vaultEntry = e;
        setState(() => _platform.text = e.institution);
      }
    });
  }

  bool get _editing => widget.initial != null;
  double? get _q => parseNumber(_qty.text);

  Listing get _listing {
    final l = listingOf(_symbol.text);
    // Typing "RELIANCE" with India picked means RELIANCE.NS.
    return l.exchange == Exchange.us && _market != Exchange.us
        ? Listing(l.base, _market)
        : l;
  }

  Future<void> _saveHeldAt(StockHolding h) async {
    final problem = await saveHeldAt(
      ref,
      sourceRef: 'asset:stock:${h.id}',
      type: VaultType.investment,
      where: _platform.text,
      title: h.title,
      existing: _vaultEntry,
    );
    if (problem != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  bool get _valid => _symbol.text.trim().isNotEmpty && (_q ?? 0) > 0;

  @override
  void dispose() {
    _symbol.dispose();
    _qty.dispose();
    _avg.dispose();
    _price.dispose();
    _platform.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final svc = ref.read(investingServiceProvider);
    final now = DateTime.now().toUtc();
    final price = parseNumber(_price.text);
    final base = widget.initial;
    final h = StockHolding(
      id: base?.id ?? newWealthId(),
      symbol: _editing ? base!.symbol : _listing.symbol,
      name: base?.name,
      currency: _currency,
      quantity: _q!,
      avgCost: parseNumber(_avg.text),
      lastPrice: price,
      priceAt: price == null
          ? base?.priceAt
          : (price == base?.lastPrice ? base?.priceAt : now),
      priceSource: price == null
          ? base?.priceSource
          : (price == base?.lastPrice ? base?.priceSource : 'manual'),
      approximate: _approx,
      source: base?.source ?? 'manual',
      note: base?.note,
      createdAt: base?.createdAt ?? now,
    );
    await svc.saveHolding(h);
    await _saveHeldAt(h);
    if (price == null) await svc.refreshPrices();
    invalidateWealth(ref);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SheetScaffold(
      title: _editing ? widget.initial!.title : 'Add a stock or ETF',
      subtitle: 'Saved on this phone only.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _symbol,
            enabled: !_editing,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: switch (_market) {
                Exchange.nse => 'Ticker, e.g. RELIANCE',
                Exchange.dfm => 'Ticker, e.g. EMAAR',
                Exchange.adx => 'Ticker, e.g. FAB',
                Exchange.bse => 'BSE code, e.g. 500325',
                Exchange.us => 'Ticker, e.g. VOO',
              },
            ),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('Market'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final m in Exchange.values)
                Pill(
                  switch (m) {
                    Exchange.us => 'US',
                    Exchange.nse => 'India NSE',
                    Exchange.bse => 'India BSE',
                    Exchange.dfm => 'Dubai DFM',
                    Exchange.adx => 'Abu Dhabi ADX',
                  },
                  selected: _market == m,
                  onTap: _editing
                      ? null
                      : () => setState(() {
                          _market = m;
                          _currency = m.currency;
                        }),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Shares or units held'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _avg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Average cost per share (optional)',
              prefixIcon: CurrencyPrefix(_currency),
 prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: _market.livePrice
                  ? 'Price (blank = fetch live)'
                  : 'Current price',
              prefixIcon: CurrencyPrefix(_currency),
 prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
          ),
          const FieldLabel('Currency'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final k in _currencies)
                Pill(
                  k,
                  selected: _currency == k,
                  onTap: _editing ? null : () => setState(() => _currency = k),
                ),
            ],
          ),
          if (!_market.livePrice)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'There is no free live price for ${_market.label} yet. Enter the price and update it when you like; value and gain still work.',
                style: context.tt.bodySmall,
              ),
            ),
          const SizedBox(height: Space.md),
          HeldAtField(
            controller: _platform,
            hint: 'Held at, e.g. Mashreq Securities or Zerodha',
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Approximate', style: context.tt.titleSmall),
                    Text(
                      'Estimated, not read off a statement',
                      style: context.tt.bodySmall!.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _approx,
                onChanged: (v) => setState(() => _approx = v),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: _editing ? 'Save changes' : 'Add',
            loading: _busy,
            onPressed: _valid ? _save : null,
          ),
          if (_editing) ...[
            const SizedBox(height: Space.sm),
            PrimaryButton(
              label: 'Remove',
              secondary: true,
              destructive: true,
              onPressed: () async {
                await ref
                    .read(investingServiceProvider)
                    .deleteHolding(widget.initial!.id);
                invalidateWealth(ref);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Add or edit a recurring buy: type it in a sentence or fill the fields.
class AddRuleSheet extends ConsumerStatefulWidget {
  const AddRuleSheet({super.key, this.initial});
  final InvestRule? initial;
  @override
  ConsumerState<AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends ConsumerState<AddRuleSheet> {
  final _sentence = TextEditingController();
  late final _symbol = TextEditingController(text: widget.initial?.symbol);
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : (widget.initial!.amountMinor / 100).toStringAsFixed(
            widget.initial!.amountMinor % 100 == 0 ? 0 : 2,
          ),
  );
  late String _currency = widget.initial?.currency ?? 'USD';
  late RuleFrequency _freq = widget.initial?.frequency ?? RuleFrequency.monthly;
  late int _day = widget.initial?.day ?? 1;
  late bool _active = widget.initial?.active ?? true;
  late final _dayCtl = TextEditingController(text: '$_day');
  bool _busy = false;

  // A SIP into a mutual fund instead of a ticker.
  late bool _fundMode = widget.initial?.isFund ?? false;
  final _fundQuery = TextEditingController();
  Timer? _debounce;
  List<FundScheme> _hits = const [];
  FundScheme? _scheme;
  bool _searching = false;
  String? _searchError;

  bool get _editing => widget.initial != null;
  double? get _a => parseNumber(_amount.text);
  bool get _valid =>
      (_fundMode
          ? (_editing || _scheme != null)
          : _symbol.text.trim().isNotEmpty) &&
      (_a ?? 0) > 0 &&
      _day >= 1 &&
      _day <= (_freq == RuleFrequency.weekly ? 7 : 31);

  @override
  void dispose() {
    _debounce?.cancel();
    _sentence.dispose();
    _symbol.dispose();
    _fundQuery.dispose();
    _amount.dispose();
    _dayCtl.dispose();
    super.dispose();
  }

  void _onFundQuery(String q) {
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
      if (mounted && q == _fundQuery.text)
        setState(() => _hits = r.take(6).toList());
    } on Object {
      if (mounted) {
        setState(
          () => _searchError = 'Fund search is not reachable right now.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _fromSentence(String t) {
    final lower = t.toLowerCase();
    if (RegExp(r'\bsip\b|mutual fund|\bfund\b|flexi|\belss\b|\bnifty\b|₹')
        .hasMatch(lower)) {
      final s = parseSipText(t);
      if (s != null) {
        setState(() {
          _fundMode = true;
          _scheme = null;
          _amount.text = (s.amountMinor / 100).toStringAsFixed(
            s.amountMinor % 100 == 0 ? 0 : 2,
          );
          _currency = s.currency;
          _freq = s.frequency;
          _day = s.day;
          _dayCtl.text = '$_day';
          _fundQuery.text = s.fundQuery;
        });
        _onFundQuery(s.fundQuery);
        return;
      }
    }
    final d = parseRuleText(t);
    if (d == null) return;
    setState(() {
      _symbol.text = d.symbol;
      _amount.text = (d.amountMinor / 100).toStringAsFixed(
        d.amountMinor % 100 == 0 ? 0 : 2,
      );
      _currency = d.currency;
      _freq = d.frequency;
      _day = d.day;
      _dayCtl.text = '$_day';
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final svc = ref.read(investingServiceProvider);
    final minor = (_a! * 100).round();
    final base = widget.initial;
    if (base == null && _fundMode) {
      await svc.startFundSip(
        _scheme!,
        amountMinor: minor,
        day: _day,
        frequency: _freq,
      );
    } else if (base == null) {
      await svc.saveRule(
        svc.newRule(
          RuleDraft(
            symbol: _symbol.text.trim().toUpperCase(),
            amountMinor: minor,
            currency: _currency,
            frequency: _freq,
            day: _day,
          ),
        ),
      );
    } else {
      await svc.saveRule(
        base.copyWith(
          amountMinor: minor,
          frequency: _freq,
          day: _day,
          active: _active,
        ),
      );
    }
    invalidateWealth(ref);
    if (mounted) Navigator.of(context).pop();
  }

  List<Widget> _fundPicker(BuildContext context) {
    final c = context.pc;
    if (_editing) {
      return [Text(widget.initial!.label, style: context.tt.titleSmall)];
    }
    return [
      TextField(
        controller: _fundQuery,
        decoration: const InputDecoration(
          hintText: 'Search the fund, e.g. Parag Parikh Flexi Cap',
        ),
        onChanged: (v) {
          _scheme = null;
          _onFundQuery(v);
        },
      ),
      if (_searching)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text('Searching…', style: context.tt.bodySmall),
        ),
      if (_searchError != null)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(
            _searchError!,
            style: context.tt.bodySmall!.copyWith(color: c.negative),
          ),
        ),
      if (_scheme != null)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text(
            _scheme!.name,
            style: context.tt.titleSmall!.copyWith(color: c.accent),
          ),
        )
      else
        for (final h in _hits)
          ListRow(
            dense: true,
            title: h.name,
            onTap: () => setState(() {
              _scheme = h;
              _hits = const [];
            }),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SheetScaffold(
      title: _editing ? 'Investing rule' : 'New investing rule',
      subtitle: 'Pulse reminds you on the day and asks you to confirm. It never trades for you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_editing) ...[
            TextField(
              controller: _sentence,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'buy \$200 of VOO monthly',
              ),
              onChanged: _fromSentence,
            ),
            const SizedBox(height: Space.md),
            const Hairline(),
            const FieldLabel('Invest in'),
            Wrap(
              spacing: Space.sm,
              children: [
                Pill(
                  'Stock or ETF',
                  selected: !_fundMode,
                  onTap: () => setState(() => _fundMode = false),
                ),
                Pill(
                  'Mutual fund SIP',
                  selected: _fundMode,
                  onTap: () => setState(() {
                    _fundMode = true;
                    if (_currency == 'USD') _currency = 'INR';
                  }),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.md),
          if (_fundMode)
            ..._fundPicker(context)
          else
            TextField(
              controller: _symbol,
              enabled: !_editing,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ticker, e.g. VOO or RELIANCE.NS',
              ),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Amount each time',
              prefixIcon: CurrencyPrefix(_currency),
 prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('Currency'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final k in const ['USD', 'AED', 'EUR', 'GBP', 'INR'])
                Pill(
                  k,
                  selected: _currency == k,
                  onTap: _editing ? null : () => setState(() => _currency = k),
                ),
            ],
          ),
          const FieldLabel('How often'),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final f in RuleFrequency.values)
                Pill(
                  f.label,
                  selected: _freq == f,
                  onTap: () => setState(() {
                    _freq = f;
                    _day = 1;
                    _dayCtl.text = '1';
                  }),
                ),
            ],
          ),
          FieldLabel(_freq == RuleFrequency.weekly ? 'On' : 'On day of month'),
          if (_freq == RuleFrequency.weekly)
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (var d = 1; d <= 7; d++)
                  Pill(
                    weekdayName(d).substring(0, 3),
                    selected: _day == d,
                    onTap: () => setState(() => _day = d),
                  ),
              ],
            )
          else
            SizedBox(
              width: 120,
              child: TextField(
                controller: _dayCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '1-31'),
                onChanged: (v) => setState(() => _day = int.tryParse(v) ?? 0),
              ),
            ),
          if (_editing) ...[
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active', style: context.tt.titleSmall),
                      Text(
                        _active
                            ? 'You will be asked on each date'
                            : 'Paused, no reminders',
                        style: context.tt.bodySmall!.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: _editing ? 'Save changes' : 'Add rule',
            loading: _busy,
            onPressed: _valid ? _save : null,
          ),
          if (_editing) ...[
            const SizedBox(height: Space.sm),
            PrimaryButton(
              label: 'Delete rule',
              secondary: true,
              destructive: true,
              onPressed: () async {
                await ref
                    .read(investingServiceProvider)
                    .deleteRule(widget.initial!.id);
                invalidateWealth(ref);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}
