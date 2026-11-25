import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_ranking.dart';
import '../../data/card_util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/local/local_repository.dart';
import '../wallet/add_sheets.dart';
import '../wallet/wallet_sections.dart';
import '../wallet/wallet_stack.dart';
import 'card_widgets.dart';
import 'combo_widgets.dart';
import 'digit_widgets.dart';
import 'quick_pick_sheet.dart';
import 'suggestion_widgets.dart';
import '../tour/tab_tip.dart';
import '../tour/tour_progress.dart';
import '../coach/coach.dart';

enum _Wallet { cards, accounts }

/// Cards and accounts as a wallet: totals first, then the stack. Tap a card
/// to open it; swipe between cards inside.
class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});
  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  _Wallet _tab = _Wallet.cards;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return CoachHost(
      screen: CoachScreen.cards,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: c.accent,
            backgroundColor: c.surface,
            onRefresh: () async {
              ref.invalidate(myCardsProvider);
              ref.invalidate(bankAccountsProvider);
              invalidateLedger(ref);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                ScreenHeader(
                  'Cards',
                  subtitle: 'Your wallet',
                  trailing: [
                    CoachTarget(
                      id: 'add',
                      child: RoundIconButton(
                        icon: Icons.add_rounded,
                        label: 'Add a card or account',
                        onTap: () => showAddMenu(context),
                      ),
                    ),
                    CoachTarget(
                      id: 'which',
                      child: TabTip(
                        tab: TipTab.cards,
                        child: RoundIconButton(
                          icon: Icons.bolt_rounded,
                          label: 'Which card should I use?',
                          onTap: () => showWhichCard(context, ref),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    0,
                    Space.gutter,
                    Space.lg,
                  ),
                  child: CoachTarget(
                    id: 'switch',
                    child: Segmented<_Wallet>(
                      segments: const {
                        _Wallet.cards: 'Cards',
                        _Wallet.accounts: 'Accounts',
                      },
                      value: _tab,
                      onChanged: (v) => setState(() => _tab = v),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : Motion.base,
                  child: _tab == _Wallet.cards
                      ? const _CardsView(key: ValueKey('cards'))
                      : const _AccountsView(key: ValueKey('accounts')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardsView extends ConsumerWidget {
  const _CardsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final cards = ref.watch(myCardsProvider);
    final txs = ref.watch(transactionsProvider).value ?? const [];
    final catalog = ref.watch(catalogProvider);
    return AsyncView<List<CreditCard>>(
      value: cards,
      loading: const SkeletonList(rows: 3, height: 120),
      onRetry: () => ref.invalidate(myCardsProvider),
      builder: (list) {
        if (list.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmptyState(
                icon: Icons.credit_card_outlined,
                title: 'No cards yet',
                message:
                    'Add the cards you carry. Pulse then tracks what each one '
                    'earns and which to use, all on this phone.',
                action: PrimaryButton(
                  label: 'Pick your cards',
                  expand: false,
                  onPressed: () => showQuickPickCards(context),
                ),
              ),
              const CardSuggestionsSection(),
              const CardCombosSection(),
            ],
          );
        }
        final standings = cardStandings(list, txs);
        // (the digit question sits above the totals, see below)
        final due = list.fold<double>(0, (a, k) => a + k.totalDue);
        final minDue = list.fold<double>(0, (a, k) => a + k.minDue);
        final limit = list.fold<double>(0, (a, k) => a + k.limit);
        final used = list.fold<double>(0, (a, k) => a + k.balance);
        final u = limit == 0 ? 0.0 : used / limit;
        final earned = standings.fold<double>(0, (a, s) => a + s.rewards);
        // Cards with no due day set have nothing to count down to.
        final dues = [
          for (final k in list)
            if (k.hasDueDate) dueInfo(k),
        ]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
        final next = dues.isEmpty ? null : dues.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DigitSuggestionBanner(),
            HeroNumber(
              label: 'Total due',
              value: due,
              caption: next == null
                  ? 'Add a due day to a card to see when to pay'
                  : 'Next: ${next.card.issuer} on ${DateFormat('d MMM').format(next.card.dueDate)}',
              captionColor: next != null && next.urgent ? c.warning : null,
            ),
            FigureRow([
              ('Minimum', Money.aed(minDue, decimals: false), null),
              (
                'Utilisation',
                '${(u * 100).round()}%',
                u > 0.5 ? c.negative : (u > 0.3 ? c.warning : null),
              ),
              (
                'Rewards this month',
                Money.aed(earned, decimals: false),
                c.positive,
              ),
            ]),
            SectionHeader(
              'Your cards',
              action: 'Ranked',
              onAction: () => context.push(Routes.cardsRanked),
            ),
            const SizedBox(height: Space.sm),
            WalletStack(
              count: list.length,
              faceBuilder: (_, i) =>
                  CreditCardVisual(card: list[i], elevated: true),
              heroTag: (i) => 'card-${list[i].id}',
              semanticLabel: (i) => cardName(list[i]),
              onTap: (i) {
                ref
                    .read(analyticsProvider)
                    .track(AnalyticsEvent.cardRecommendationViewed('detail'));
                openCardDetail(context, list, i);
              },
            ),
            if (dues.isNotEmpty) ...[
              const SectionHeader('Upcoming dues'),
              RowGroup(
                indent: ListRow.leadingInset,
                children: [
                  for (final d in dues)
                    DueRow(
                      d,
                      onTap: () =>
                          openCardDetail(context, list, list.indexOf(d.card)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.lg),
            RowGroup(
              indent: ListRow.leadingInset,
              children: [
                ListRow(
                  leading: IconWell(
                    Icons.leaderboard_outlined,
                    color: c.accent,
                  ),
                  title: 'My cards ranked',
                  subtitle: 'By use, rewards and return after fees',
                  chevron: true,
                  onTap: () => context.push(Routes.cardsRanked),
                ),
                ListRow(
                  leading: IconWell(Icons.bolt_rounded, color: c.accent),
                  title: 'Which card should I use?',
                  subtitle: 'Before you pay',
                  chevron: true,
                  onTap: () => showWhichCard(context, ref),
                ),
              ],
            ),
            const SectionHeader('Utilisation'),
            UtilisationChart(list),
            const CardSuggestionsSection(),
            const CardCombosSection(limit: 3),
            AsyncView<List<CreditCard>>(
              value: catalog,
              loading: const SizedBox.shrink(),
              builder: (cat) => cat.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader('Discover'),
                        RowGroup(
                          indent: 56 + Space.md,
                          children: [for (final k in cat) _CatalogRow(k)],
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountsView extends ConsumerWidget {
  const _AccountsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final accounts = ref.watch(bankAccountsProvider);
    final cf = ref.watch(cashflowProvider).value;
    return AsyncView<List<BankAccount>>(
      value: accounts,
      loading: const SkeletonList(rows: 3, height: 120),
      onRetry: () => ref.invalidate(bankAccountsProvider),
      builder: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'No accounts yet',
            message:
                'Add your bank accounts so balances and safe-to-spend are '
                'real. Alerts then keep them current.',
            action: PrimaryButton(
              label: 'Add an account',
              expand: false,
              onPressed: () => showPulseSheet<void>(
                context,
                builder: (_) => const AddAccountSheet(),
              ),
            ),
          );
        }
        final total = list.fold<double>(0, (a, k) => a + k.balance);
        final inflow = list.fold<double>(0, (a, k) => a + k.monthIn);
        final outflow = list.fold<double>(0, (a, k) => a + k.monthOut);
        final net = inflow - outflow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroNumber(
              label: 'Total balance',
              value: total,
              caption:
                  'Across ${list.length} ${list.length == 1 ? 'account' : 'accounts'}',
            ),
            FigureRow([
              ('In this month', Money.aed(inflow, decimals: false), null),
              ('Out', Money.aed(outflow, decimals: false), null),
              (
                'Net',
                '${net >= 0 ? '+' : '−'}${Money.aed(net.abs(), decimals: false)}',
                net >= 0 ? c.positive : c.negative,
              ),
            ]),
            const SectionHeader('Your accounts'),
            const SizedBox(height: Space.sm),
            WalletStack(
              count: list.length,
              faceBuilder: (_, i) =>
                  AccountCardVisual(account: list[i], elevated: true),
              heroTag: (i) => 'account-${list[i].id}',
              semanticLabel: (i) => list[i].label,
              onTap: (i) => openAccountDetail(context, list, i),
            ),
            if (cf != null && cf.months.isNotEmpty) ...[
              const SectionHeader('Cashflow'),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.md,
                  Space.gutter,
                  0,
                ),
                child: GroupedBarChart(
                  height: 120,
                  labels: [for (final m in cf.months) m.label],
                  title: (i) => i == cf.months.length - 1
                      ? '${cf.months[i].label} so far'
                      : cf.months[i].label,
                  series: [
                    ChartSeries('In', [
                      for (final m in cf.months) m.income,
                    ], c.textTertiary),
                    ChartSeries('Out', [
                      for (final m in cf.months) m.spend,
                    ], c.accent),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CatalogRow extends ConsumerWidget {
  const _CatalogRow(this.card);
  final CreditCard card;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListRow(
    leading: SizedBox(
      width: 56,
      child: CreditCardVisual(card: card, compact: true),
    ),
    title: '${card.issuer} ${card.name}',
    subtitle: [
      card.highlight,
      card.annualFee == 0
          ? 'No annual fee'
          : '${Money.aed(card.annualFee, decimals: false)} a year',
    ].where((s) => s.isNotEmpty).join(' · '),
    chevron: true,
    onTap: () {
      ref.read(analyticsProvider).track(AnalyticsEvent.cardAdded);
      ref.read(analyticsProvider).track(AnalyticsEvent.firstCardAdded);
      if (ref.read(repositoryProvider) is LocalPulseRepository) {
        showPulseSheet<void>(
          context,
          builder: (_) => AddCardSheet(initial: card),
          full: true,
        );
      }
    },
  );
}
