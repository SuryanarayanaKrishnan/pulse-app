import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/prices.dart';
import '../../core/engine/valuation.dart';
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../data/wealth_service.dart';
import '../net_worth/wealth_screen.dart' show ago;
import '../../core/engine/live_quote.dart';
import '../../data/local/live_prices.dart';
import 'document_screens.dart';
import 'live_widgets.dart';
import 'fund_screens.dart';
import 'investing_screens.dart';
import 'jewellery_screens.dart';
import 'wealth_icons.dart';
import 'wealth_widgets.dart';

/// What can be added from Wealth.
Future<void> showWealthAddMenu(
  BuildContext context, {
  required Widget Function(BuildContext) assetSheet,
}) => showPulseSheet<void>(
  context,
  builder: (sheet) {
    final c = context.pc;
    void open(Widget Function(BuildContext) b, {bool full = true}) {
      Navigator.of(sheet).pop();
      showPulseSheet<void>(context, builder: b, full: full);
    }

    return SheetScaffold(
      title: 'Add to Wealth',
      subtitle: 'Saved on this phone only.',
      child: RowGroup(
        padding: EdgeInsets.zero,
        children: [
          ListRow(
            leading: IconWell(Icons.document_scanner_outlined, color: c.calm),
            title: 'Scan a bill or portfolio',
            subtitle:
                'Gold bill, stock or fund screenshot. Or just describe it',
            chevron: true,
            onTap: () {
              Navigator.of(sheet).pop();
              openScan(context);
            },
          ),
          ListRow(
            leading: const WealthIcon(WealthKind.stock, size: 32),
            title: 'Stock or ETF',
            subtitle: 'Live price and profit, in AED',
            chevron: true,
            onTap: () => open((_) => const AddHoldingSheet()),
          ),
          ListRow(
            leading: const WealthIcon(WealthKind.investingRule, size: 32),
            title: 'Investing rule',
            subtitle: 'Like "buy \$200 of VOO monthly"',
            chevron: true,
            onTap: () => open((_) => const AddRuleSheet()),
          ),
          ListRow(
            leading: const WealthIcon(WealthKind.gold, size: 32),
            title: 'Gold or jewellery',
            subtitle: 'Photo, weight and karat. Valued from the gold price',
            chevron: true,
            onTap: () => open((_) => const AddJewellerySheet()),
          ),
          ListRow(
            leading: const WealthIcon(WealthKind.fund, size: 32),
            title: 'Mutual fund',
            subtitle: 'Search by name or enter by hand',
            chevron: true,
            onTap: () => open((_) => const AddFundSheet()),
          ),
          ListRow(
            leading: IconWell(Icons.description_outlined, color: c.calm),
            title: 'Document',
            subtitle: 'Title deed, FD certificate, insurance, passport',
            chevron: true,
            onTap: () => open((_) => const AddDocumentSheet()),
          ),
          ListRow(
            leading: const WealthIcon(WealthKind.property, size: 32),
            title: 'Other asset or loan',
            subtitle: 'Property, deposits, debts',
            chevron: true,
            onTap: () => open(assetSheet, full: false),
          ),
        ],
      ),
    );
  },
);

/// "Live · updated 3 min ago" / "Saved prices · updated 2 days ago" /
/// "Demo prices" plus a refresh button when a price service is configured.
class PriceStatusLine extends ConsumerStatefulWidget {
  const PriceStatusLine({super.key});
  @override
  ConsumerState<PriceStatusLine> createState() => _PriceStatusLineState();
}

class _PriceStatusLineState extends ConsumerState<PriceStatusLine> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final svc = ref.read(wealthServiceProvider);
    await svc.prices.refresh(force: true);
    await svc.refreshNavs();
    final live = await ref.read(livePriceServiceProvider).refresh(force: true);
    await svc.recordValuations();
    if (mounted) invalidateWealth(ref);
    if (mounted) {
      setState(() => _busy = false);
      if (svc.prices.lastError != null || live.errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline. Showing the last saved prices.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final book = ref.watch(priceBookProvider).value;
    if (book == null) return const SizedBox.shrink();
    final at = book.fetchedAt;
    // Funds and stocks refresh from public sources on the phone, so there is
    // always something to refresh.
    const canFetch = true;
    final fresh =
        at != null && DateTime.now().difference(at) < const Duration(hours: 1);
    final (label, color) = book.origin == PriceOrigin.bundled
        ? (
            'Gold price is an estimate for now · funds and stocks update from public sources',
            c.warning,
          )
        : fresh
        ? ('Live · updated ${ago(at)}', c.positive)
        : ('Saved prices · updated ${ago(at!)}', c.warning);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.sm, 0),
      child: Row(
        children: [
          Dot(color, size: 6),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              key: const Key('price-status'),
              style: context.tt.bodySmall,
            ),
          ),
          if (canFetch)
            IconButton(
              tooltip: 'Refresh prices',
              visualDensity: VisualDensity.compact,
              onPressed: _busy ? null : _refresh,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: c.textSecondary,
                    ),
            ),
        ],
      ),
    );
  }
}

/// Documents with a date and fund SIPs, soonest first.
class UpcomingSection extends ConsumerWidget {
  const UpcomingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(upcomingProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Upcoming'),
        RowGroup(
          children: [
            for (final u in items.take(5))
              ListRow(
                dense: true,
                leading: IconWell(
                  u.kind == UpcomingKind.document
                      ? Icons.event_available_outlined
                      : Icons.autorenew_rounded,
                  color: statusColor(context, u.status),
                ),
                title: u.title,
                subtitle: u.detail,
                subtitleColor: u.status == DueStatus.upcoming
                    ? null
                    : statusColor(context, u.status),
                trailing: Text(
                  formatDate(u.date),
                  style: PulseTheme.amount(c.textSecondary, size: 13),
                ),
                chevron: u.kind != UpcomingKind.buy,
                onTap: u.kind == UpcomingKind.buy
                    ? null
                    : () => context.push(
                        u.kind == UpcomingKind.sip
                            ? '${Routes.fund}/${u.refId}'
                            : '${Routes.document}/${u.refId}',
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

class JewellerySection extends ConsumerWidget {
  const JewellerySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final list = ref.watch(jewelleryProvider).value ?? const [];
    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Gold and jewellery',
            action: 'Add',
            onAction: () => showPulseSheet<void>(
              context,
              full: true,
              builder: (_) => const AddJewellerySheet(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Add a piece with a photo, its weight and karat. Pulse values it from the gold price, on this phone.',
              style: context.tt.bodySmall,
            ),
          ),
        ],
      );
    }
    final total = list.fold<int>(0, (a, v) => a + v.value.valueMinor);
    final paid = list.every((v) => v.item.purchasePriceMinor != null)
        ? list.fold<int>(0, (a, v) => a + v.item.purchasePriceMinor!)
        : null;
    final grams = list.fold<double>(0, (a, v) => a + v.item.weightGrams);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Gold and jewellery',
          action: 'Add',
          onAction: () => showPulseSheet<void>(
            context,
            full: true,
            builder: (_) => const AddJewellerySheet(),
          ),
        ),
        RowGroup(
          children: [
            for (final v in list)
              ListRow(
                leading: _Thumb(
                  v.item.photoPaths.firstOrNull,
                  const WealthIcon(WealthKind.jewellery),
                ),
                title: v.item.name,
                subtitle:
                    '${v.item.approximate ? '~' : ''}${v.item.weightGrams.toStringAsFixed(v.item.weightGrams == v.item.weightGrams.roundToDouble() ? 0 : 1)} g · ${v.item.purityLabel}${v.item.approximate ? ' · approximate' : ''}',
                chevron: true,
                onTap: () => context.push('${Routes.jewellery}/${v.item.id}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${v.item.approximate ? '~' : ''}${Money.aed(v.value.valueMinor / 100, decimals: false)}',
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
          child: Text(
            '${list.length} ${list.length == 1 ? 'piece' : 'pieces'} · ${grams.toStringAsFixed(1)} g · ${Money.aed(total / 100, decimals: false)}'
            '${paid == null || paid <= 0 ? '' : ' · ${pctText((total - paid) / paid * 100)} vs paid'}',
            style: context.tt.bodySmall,
          ),
        ),
      ],
    );
  }
}

class FundsSection extends ConsumerWidget {
  const FundsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final list = ref.watch(fundsProvider).value ?? const [];
    final quotes = ref.watch(liveQuotesProvider).value ?? const {};
    final today = DateTime.now();
    void add() => showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => const AddFundSheet(),
    );
    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('Mutual funds', action: 'Add', onAction: add),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Search an Indian fund by name or enter any fund by hand. Units and cost stay on this phone.',
              style: context.tt.bodySmall,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Mutual funds', action: 'Add', onAction: add),
        RowGroup(
          children: [
            for (final v in list)
              ListRow(
                leading: const WealthIcon(WealthKind.fund),
                title: v.holding.name,
                subtitle:
                    '${_units(v.holding.units)} units · NAV ${v.holding.currency} ${v.holding.nav.toStringAsFixed(2)}'
                    '${v.holding.hasSip ? ' · SIP' : ''}'
                    '${v.holding.isIndian ? '\n${asOfLabel(v.holding.navDate, today, fund: true)}' : ''}',
                chevron: true,
                onTap: () => context.push('${Routes.fund}/${v.holding.id}'),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v.value.valueAedMinor == null
                          ? '–'
                          : Money.aed(
                              v.value.valueAedMinor! / 100,
                              decimals: false,
                            ),
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
                    if (v.holding.schemeCode != null)
                      DayChangeText(
                        quote:
                            quotes[LivePriceService.fundKey(
                              v.holding.schemeCode!,
                            )],
                        quantity: v.holding.units,
                        currency: v.holding.currency,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _units(double u) => fmtNum(u, maxDecimals: 2);
}

class DocumentsSection extends ConsumerWidget {
  const DocumentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final docs = ref.watch(documentsProvider).value ?? const [];
    void add() => showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => const AddDocumentSheet(),
    );
    final today = ref.watch(wealthServiceProvider).today;
    if (docs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('Documents', action: 'Add', onAction: add),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Keep photos of title deeds, certificates and policies on this phone, with reminders before they expire.',
              style: context.tt.bodySmall,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Documents', action: 'Add', onAction: add),
        RowGroup(
          children: [
            for (final d in docs)
              ListRow(
                dense: true,
                leading: _Thumb(
                  d.filePaths.firstOrNull,
                  IconWell(docIcon(d.category), color: c.calm, size: 40),
                  document: true,
                ),
                title: d.title,
                subtitle: d.dueOn == null
                    ? (d.title == d.category.label
                          ? 'Photo on this phone'
                          : d.category.label)
                    : '${d.title == d.category.label ? '' : '${d.category.label} · '}${d.dueLabel} ${dueText(d.dueOn!, today)}',
                subtitleColor: d.dueOn == null
                    ? null
                    : (dueStatus(d.dueOn!, today) == DueStatus.upcoming
                          ? null
                          : statusColor(context, dueStatus(d.dueOn!, today))),
                chevron: true,
                onTap: () => context.push('${Routes.document}/${d.id}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.path, this.fallback, {this.document = false});
  final String? path;
  final Widget fallback;
  final bool document;

  @override
  Widget build(BuildContext context) => path == null
      ? fallback
      : ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: SizedBox(
            width: 40,
            height: 40,
            child: AttachmentImage(path!, document: document),
          ),
        );
}
