import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics.dart';
import '../../core/env/env.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../transactions/tx_detail_sheet.dart';
import '../transactions/tx_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.accent,
          backgroundColor: c.surfaceElevated,
          onRefresh: () async {
            ref.invalidate(netWorthProvider);
            ref.invalidate(budgetProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(myCardsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                'Hi, Sara',
                subtitle: '$greeting · ${Env.appName}',
                trailing: [
                  RoundIconButton(
                    icon: Icons.person_rounded,
                    label: 'Settings',
                    onTap: () => context.push(Routes.settings),
                  ),
                ],
              ),
              const _NetWorthHero()
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutCubic),
              const SizedBox(height: Space.lg),
              const _SpendCard()
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutCubic),
              const _DueDates(),
              const _BestCardTip()
                  .animate(delay: 160.ms)
                  .fadeIn(duration: 500.ms),
              SectionHeader(
                'Recent activity',
                action: 'See all',
                onAction: () => context.push(Routes.activity),
              ),
              const _Recent(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetWorthHero extends ConsumerWidget {
  const _NetWorthHero();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final nw = ref.watch(netWorthProvider);
    return Padding(
      padding: screenPad,
      child: GlassCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.heroGradient[0],
            c.heroGradient[1].withValues(alpha: 0.85),
            c.surface,
          ],
          stops: const [0, 0.55, 1],
        ),
        padding: const EdgeInsets.fromLTRB(
          Space.xl,
          Space.xl,
          Space.xl,
          Space.lg,
        ),
        child: nw.when(
          loading: () => const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => const SizedBox(
            height: 120,
            child: Center(child: Text('Unable to load net worth')),
          ),
          data: (n) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NET WORTH',
                style: context.tt.labelSmall!.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              AmountText(n.total, size: 38, color: Colors.white),
              const SizedBox(height: 10),
              Row(
                children: [
                  Pill(
                    '${n.changePct >= 0 ? '+' : ''}${n.changePct.toStringAsFixed(1)}% this month',
                    icon: Icons.trending_up_rounded,
                    selected: true,
                    color: c.accentAlt,
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Sparkline(values: n.series, color: Colors.white, height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendCard extends ConsumerWidget {
  const _SpendCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(budgetProvider);
    return Padding(
      padding: screenPad,
      child: GlassCard(
        onTap: () => context.go(Routes.budget),
        child: b.when(
          loading: () => const SizedBox(
            height: 120,
            child: Skeleton(height: 120, radius: 20),
          ),
          error: (e, _) => const Text('Unable to load budget'),
          data: (o) => Row(
            children: [
              ProgressRing(
                progress: o.progress,
                size: 110,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(o.progress * 100).round()}%',
                      style: context.tt.titleLarge,
                    ),
                    Text('used', style: context.tt.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIS MONTH', style: context.tt.labelSmall),
                    const SizedBox(height: 6),
                    AmountText(o.spent, size: 26),
                    Text(
                      'of ${Money.aed(o.planned, decimals: false)}',
                      style: context.tt.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Safe to spend ${Money.aed(o.safePerDay, decimals: false)}/day',
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
      ),
    );
  }
}

class _DueDates extends ConsumerWidget {
  const _DueDates();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myCardsProvider).value;
    if (cards == null) return const SizedBox.shrink();
    final sorted = List.of(cards)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Upcoming dues'),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: screenPad,
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (_, i) {
              final k = sorted[i];
              final days = k.dueDate.difference(DateTime.now()).inDays;
              final soon = days <= 5;
              return SizedBox(
                width: 170,
                child: GlassCard(
                  padding: const EdgeInsets.all(Space.md),
                  onTap: () => context.go(Routes.cards),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: k.gradient),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              k.issuer,
                              style: context.tt.labelMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        Money.aed(k.minDue, decimals: false),
                        style: context.tt.titleMedium,
                      ),
                      Text(
                        'min due · ${DateFormat('d MMM').format(k.dueDate)}',
                        style: context.tt.bodySmall!.copyWith(
                          color: soon ? c.warning : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ].animate(interval: 60.ms).fadeIn(duration: 400.ms),
    );
  }
}

class _BestCardTip extends ConsumerWidget {
  const _BestCardTip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myCardsProvider).value;
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();
    const cat = SpendCategory.groceries;
    final best = rankCardsFor(cards, cat).first;
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xl,
        Space.gutter,
        0,
      ),
      child: GlassCard(
        onTap: () {
          ref
              .read(analyticsProvider)
              .track(AnalyticsEvent.cardRecommendationViewed(cat.name));
          context.go(Routes.cards);
        },
        gradient: LinearGradient(
          colors: [c.accentAlt.withValues(alpha: 0.18), c.surface],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accentAlt.withValues(alpha: 0.2),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: c.accentAlt),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Best card for groceries', style: context.tt.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Use ${best.issuer} ${best.name} for ${rateFor(best, cat).toStringAsFixed(rateFor(best, cat) % 1 == 0 ? 0 : 1)}% back',
                    style: context.tt.titleSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(transactionsProvider);
    return Padding(
      padding: screenPad,
      child: tx.when(
        loading: () => const SkeletonList(rows: 4, height: 56),
        error: (e, _) => const Text('Unable to load activity'),
        data: (list) => Column(
          children: [
            for (var i = 0; i < list.take(5).length; i++)
              TxTile(
                    list[i],
                    onTap: () => showPulseSheet<void>(
                      context,
                      builder: (_) => TxDetailSheet(tx: list[i]),
                    ),
                  )
                  .animate(delay: stagger(i))
                  .fadeIn(duration: 350.ms)
                  .slideX(begin: 0.05, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
