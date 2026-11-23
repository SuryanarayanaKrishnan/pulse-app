import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final _page = PageController(viewportFraction: 0.88);
  int _index = 0;
  SpendCategory _cat = SpendCategory.groceries;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(myCardsProvider);
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const ScreenHeader('Cards', subtitle: 'Your wallet'),
            AsyncView<List<CreditCard>>(
              value: cards,
              loading: const SkeletonList(rows: 2, height: 190),
              onRetry: () => ref.invalidate(myCardsProvider),
              builder: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 214,
                    child: PageView.builder(
                      controller: _page,
                      itemCount: list.length,
                      onPageChanged: (i) {
                        Haptics.tap();
                        setState(() => _index = i);
                      },
                      itemBuilder: (_, i) => AnimatedScale(
                        scale: i == _index ? 1 : 0.94,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: CreditCardVisual(card: list[i]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < list.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? context.pc.accent
                                : context.pc.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.lg,
                      Space.gutter,
                      0,
                    ),
                    child: _CardDetail(list[_index.clamp(0, list.length - 1)]),
                  ),
                  const SectionHeader('Rewards summary'),
                  _Rewards(list),
                  const SectionHeader('Which card should I use?'),
                  _Recommender(
                    cards: list,
                    category: _cat,
                    onCategory: (c) {
                      ref
                          .read(analyticsProvider)
                          .track(
                            AnalyticsEvent.cardRecommendationViewed(c.name),
                          );
                      setState(() => _cat = c);
                    },
                  ),
                ],
              ),
            ),
            const SectionHeader('Discover cards'),
            AsyncView<List<CreditCard>>(
              value: catalog,
              loading: const SkeletonList(rows: 2),
              builder: (list) => Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    _CatalogTile(list[i])
                        .animate(delay: stagger(i))
                        .fadeIn()
                        .slideY(begin: 0.1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDetail extends StatelessWidget {
  const _CardDetail(this.card);
  final CreditCard card;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  'Balance',
                  Money.aed(card.balance, decimals: false),
                ),
              ),
              Expanded(
                child: _Stat('Limit', Money.aed(card.limit, decimals: false)),
              ),
              Expanded(
                child: _Stat('Due', DateFormat('d MMM').format(card.dueDate)),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(card.id),
              tween: Tween(begin: 0, end: card.utilisation),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: card.utilisation > 0.3 ? c.warning : c.positive,
                backgroundColor: c.border,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(card.utilisation * 100).round()}% utilisation',
                style: context.tt.bodySmall,
              ),
              const Spacer(),
              Text('Keep under 30%', style: context.tt.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: context.tt.labelSmall),
      const SizedBox(height: 4),
      Text(
        value,
        style: PulseTheme.amount(
          context.pc.textPrimary,
          size: 16,
          weight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _Rewards extends StatelessWidget {
  const _Rewards(this.cards);
  final List<CreditCard> cards;
  @override
  Widget build(BuildContext context) {
    final total = cards.fold(0.0, (a, c) => a + c.rewardValueAed);
    return Padding(
      padding: screenPad,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EARNED VALUE', style: context.tt.labelSmall),
            const SizedBox(height: 6),
            AmountText(total, size: 30, color: context.pc.accentAlt),
            const SizedBox(height: Space.md),
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: c.gradient),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${c.issuer} · ${c.rewardsLabel}',
                        style: context.tt.titleSmall,
                      ),
                    ),
                    Text(
                      c.rewardPoints > 0
                          ? '${Money.number(c.rewardPoints)} pts'
                          : Money.aed(c.rewardValueAed, decimals: false),
                      style: context.tt.bodyMedium,
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

class _Recommender extends StatelessWidget {
  const _Recommender({
    required this.cards,
    required this.category,
    required this.onCategory,
  });
  final List<CreditCard> cards;
  final SpendCategory category;
  final ValueChanged<SpendCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    final ranked = rankCardsFor(cards, category);
    final cats = SpendCategory.values
        .where((c) => c != SpendCategory.income && c != SpendCategory.rent)
        .toList();
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: screenPad,
            itemCount: cats.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Pill(
              cats[i].label,
              icon: cats[i].icon,
              color: cats[i].color,
              selected: cats[i] == category,
              onTap: () => onCategory(cats[i]),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        Padding(
          padding: screenPad,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Column(
              key: ValueKey(category),
              children: [
                for (var i = 0; i < ranked.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: GlassCard(
                      padding: const EdgeInsets.all(Space.md),
                      gradient: i == 0
                          ? LinearGradient(
                              colors: [
                                context.pc.accent.withValues(alpha: 0.25),
                                context.pc.surface,
                              ],
                            )
                          : null,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: CreditCardVisual(
                              card: ranked[i],
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ranked[i].name,
                                  style: context.tt.titleSmall,
                                ),
                                if (i == 0)
                                  Text(
                                    'Best for ${category.label.toLowerCase()}',
                                    style: context.tt.bodySmall!.copyWith(
                                      color: context.pc.accentAlt,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${rateFor(ranked[i], category).toStringAsFixed(rateFor(ranked[i], category) % 1 == 0 ? 0 : 1)}%',
                            style: PulseTheme.amount(
                              context.pc.textPrimary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogTile extends ConsumerWidget {
  const _CatalogTile(this.card);
  final CreditCard card;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
    child: GlassCard(
      onTap: () => ref.read(analyticsProvider).track(AnalyticsEvent.cardAdded),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: CreditCardVisual(card: card, compact: true),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.issuer} ${card.name}',
                  style: context.tt.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  card.highlight,
                  style: context.tt.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  card.annualFee == 0
                      ? 'No annual fee'
                      : '${Money.aed(card.annualFee, decimals: false)} / year',
                  style: context.tt.labelMedium!.copyWith(
                    color: context.pc.accentAlt,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
