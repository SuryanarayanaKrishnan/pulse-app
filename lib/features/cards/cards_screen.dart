import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key});
  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends ConsumerState<CardsScreen> {
  final _page = PageController(viewportFraction: 0.84);
  int _index = 0;
  SpendCategory _cat = SpendCategory.groceries;

  static const _recommendable = [
    SpendCategory.groceries,
    SpendCategory.dining,
    SpendCategory.transport,
    SpendCategory.shopping,
    SpendCategory.travel,
    SpendCategory.entertainment,
    SpendCategory.health,
    SpendCategory.utilities,
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(myCardsProvider);
    final catalog = ref.watch(catalogProvider);
    final c = context.pc;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            ScreenHeader(
              'Cards',
              subtitle: cards.value == null
                  ? null
                  : '${cards.value!.length} in your wallet',
            ),
            AsyncView<List<CreditCard>>(
              value: cards,
              loading: const SkeletonList(rows: 2, height: 190),
              onRetry: () => ref.invalidate(myCardsProvider),
              builder: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.credit_card_outlined,
                    title: 'No cards yet',
                    message: 'Cards appear here once a statement or alert arrives.',
                  );
                }
                final card = list[_index.clamp(0, list.length - 1)];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 206,
                      child: PageView.builder(
                        controller: _page,
                        padEnds: false,
                        itemCount: list.length,
                        onPageChanged: (i) {
                          Haptics.tap();
                          setState(() => _index = i);
                        },
                        itemBuilder: (_, i) => Padding(
                          padding: EdgeInsets.only(
                            left: i == 0 ? Space.gutter : Space.xs,
                            right: i == list.length - 1
                                ? Space.gutter
                                : Space.xs,
                          ),
                          child: Center(child: CreditCardVisual(card: list[i])),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < list.length; i++)
                          AnimatedContainer(
                            duration: Motion.base,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index ? c.textPrimary : c.border,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    HeroNumber(
                      label: 'Balance',
                      value: card.balance,
                      caption: card.minDue > 0
                          ? 'Due ${DateFormat('d MMMM').format(card.dueDate)} · minimum ${Money.aed(card.minDue, decimals: false)}'
                          : 'Due ${DateFormat('d MMMM').format(card.dueDate)}',
                    ),
                    const SizedBox(height: Space.lg),
                    RowGroup(
                      children: [
                        ListRow(
                          dense: true,
                          title: 'Limit',
                          trailing: Text(
                            Money.aed(card.limit, decimals: false),
                            style: PulseTheme.amount(c.textPrimary),
                          ),
                        ),
                        ListRow(
                          dense: true,
                          title: 'Utilisation',
                          subtitle: 'Keep it under 30%',
                          trailing: SizedBox(
                            width: 120,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Meter(
                                    value: card.utilisation,
                                    color: card.utilisation > 0.3
                                        ? c.warning
                                        : c.accent,
                                  ),
                                ),
                                const SizedBox(width: Space.sm),
                                Text(
                                  '${(card.utilisation * 100).round()}%',
                                  style: PulseTheme.amount(c.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ListRow(
                          dense: true,
                          title: card.rewardsLabel,
                          trailing: Text(
                            card.rewardPoints > 0
                                ? '${Money.number(card.rewardPoints)} pts'
                                : Money.aed(card.rewardValueAed, decimals: false),
                            style: PulseTheme.amount(c.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SectionHeader('Best card for'),
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.gutter,
                          vertical: Space.md,
                        ),
                        itemCount: _recommendable.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: Space.sm),
                        itemBuilder: (_, i) {
                          final x = _recommendable[i];
                          return Pill(
                            x.label,
                            selected: x == _cat,
                            onTap: () {
                              ref
                                  .read(analyticsProvider)
                                  .track(
                                    AnalyticsEvent.cardRecommendationViewed(
                                      x.name,
                                    ),
                                  );
                              setState(() => _cat = x);
                            },
                          );
                        },
                      ),
                    ),
                    _Ranked(cards: list, category: _cat),
                  ],
                );
              },
            ),
            AsyncView<List<CreditCard>>(
              value: catalog,
              loading: const SizedBox.shrink(),
              builder: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader('Discover'),
                        RowGroup(
                          indent: 56 + Space.md,
                          children: [for (final k in list) _CatalogRow(k)],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ranked extends StatelessWidget {
  const _Ranked({required this.cards, required this.category});
  final List<CreditCard> cards;
  final SpendCategory category;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final ranked = rankCardsFor(cards, category);
    String pct(double r) => '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}%';
    return AnimatedSwitcher(
      duration: Motion.base,
      child: RowGroup(
        key: ValueKey(category),
        indent: 40 + Space.md,
        children: [
          for (var i = 0; i < ranked.length; i++)
            ListRow(
              leading: SizedBox(
                width: 40,
                child: CreditCardVisual(card: ranked[i], compact: true),
              ),
              title: '${ranked[i].issuer} ${ranked[i].name}',
              subtitle: i == 0 ? 'Best for ${category.label.toLowerCase()}' : null,
              subtitleColor: c.accent,
              trailing: Text(
                pct(rateFor(ranked[i], category)),
                style: PulseTheme.amount(
                  i == 0 ? c.textPrimary : c.textSecondary,
                ),
              ),
            ),
        ],
      ),
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
    onTap: () => ref.read(analyticsProvider).track(AnalyticsEvent.cardAdded),
  );
}
