import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Budget dashboard: first-class tab.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(budgetProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            ScreenHeader(
              'Budget',
              subtitle: 'This month',
              trailing: [
                RoundIconButton(
                  icon: Icons.receipt_long_rounded,
                  label: 'Activity',
                  onTap: () => context.push(Routes.activity),
                ),
              ],
            ),
            AsyncView<BudgetOverview>(
              value: b,
              onRetry: () => ref.invalidate(budgetProvider),
              loading: const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SkeletonList(rows: 4, height: 150),
              ),
              builder: (o) => _Body(o),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.o);
  final BudgetOverview o;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _Overview(o),
      _AutoCapture(o),
      const SectionHeader('Categories'),
      _Categories(o),
      const SectionHeader('Month over month'),
      Padding(
        padding: screenPad,
        child: GlassCard(
          child: TrendBars(
            labels: [for (final m in o.trend) m.label],
            values: [for (final m in o.trend) m.spent],
            planned: o.planned,
          ),
        ),
      ),
      const SectionHeader('Top merchants'),
      _Merchants(o),
      const SectionHeader('By card'),
      _Breakdown(o.byCard),
      const SectionHeader('By account'),
      _Breakdown(o.byAccount),
    ];
    return Column(
      children: [
        for (var i = 0; i < sections.length; i++)
          sections[i]
              .animate(delay: stagger(i.clamp(0, 6)))
              .fadeIn(duration: 420.ms)
              .slideY(begin: 0.06, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview(this.o);
  final BudgetOverview o;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: screenPad,
      child: GlassCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent.withValues(alpha: 0.28), c.surface],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ProgressRing(
                  progress: o.progress,
                  size: 128,
                  stroke: 14,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${o.daysLeft}',
                        style: PulseTheme.amount(c.textPrimary, size: 30),
                      ),
                      Text('days left', style: context.tt.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: Space.xl),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SPENT', style: context.tt.labelSmall),
                      AmountText(o.spent, size: 26),
                      const SizedBox(height: 10),
                      Text('PLANNED', style: context.tt.labelSmall),
                      Text(
                        Money.aed(o.planned, decimals: false),
                        style: PulseTheme.amount(
                          c.textSecondary,
                          size: 18,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: c.accentAlt.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_moon_rounded, color: c.accentAlt),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text('Safe to spend', style: context.tt.titleSmall),
                  ),
                  Text(
                    '${Money.aed(o.safePerDay, decimals: false)} / day',
                    style: PulseTheme.amount(
                      c.accentAlt,
                      size: 17,
                      weight: FontWeight.w800,
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
}

class _AutoCapture extends StatelessWidget {
  const _AutoCapture(this.o);
  final BudgetOverview o;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final pct = (o.autoShare * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: c.accentAlt),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$pct% auto-captured', style: context.tt.titleSmall),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: o.autoShare),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        color: c.accentAlt,
                        backgroundColor: c.warning.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Text(
              '${o.autoCaptured} auto\n${o.manual} manual',
              style: context.tt.bodySmall,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories(this.o);
  final BudgetOverview o;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final top = o.lines.take(4).toList();
    final rest = o.lines.skip(4).toList();
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: screenPad,
            itemCount: top.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (_, i) {
              final l = top[i];
              return SizedBox(
                width: 140,
                child: GlassCard(
                  padding: const EdgeInsets.all(Space.md),
                  onTap: () => context.push(
                    '${Routes.activity}?category=${l.category.name}',
                  ),
                  child: Column(
                    children: [
                      ProgressRing(
                        progress: l.progress,
                        size: 70,
                        stroke: 8,
                        color: l.progress > 1 ? c.negative : l.category.color,
                        child: Icon(
                          l.category.icon,
                          color: l.category.color,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l.category.label,
                        style: context.tt.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${Money.number(l.spent)} / ${Money.number(l.planned)}',
                        style: context.tt.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.md),
        Padding(
          padding: screenPad,
          child: GlassCard(
            child: Column(children: [for (final l in rest) _Bar(l)]),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.l);
  final BudgetLine l;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final over = l.progress > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(l.category.icon, size: 18, color: l.category.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.category.label, style: context.tt.titleSmall),
              ),
              Text(
                '${Money.number(l.spent)} / ${Money.number(l.planned)}',
                style: context.tt.bodySmall!.copyWith(
                  color: over ? c.negative : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: l.progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: over ? c.negative : l.category.color,
                backgroundColor: c.border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Merchants extends StatelessWidget {
  const _Merchants(this.o);
  final BudgetOverview o;
  @override
  Widget build(BuildContext context) => Padding(
    padding: screenPad,
    child: GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < o.topMerchants.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text('${i + 1}', style: context.tt.labelMedium),
                  const SizedBox(width: Space.md),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: o.topMerchants[i].category.color.withValues(
                        alpha: 0.16,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      o.topMerchants[i].category.icon,
                      size: 18,
                      color: o.topMerchants[i].category.color,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.topMerchants[i].merchant,
                          style: context.tt.titleSmall,
                        ),
                        Text(
                          '${o.topMerchants[i].count} transactions',
                          style: context.tt.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Money.aed(o.topMerchants[i].total, decimals: false),
                    style: PulseTheme.amount(
                      context.pc.textPrimary,
                      size: 15,
                      weight: FontWeight.w700,
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

class _Breakdown extends StatelessWidget {
  const _Breakdown(this.data);
  final Map<String, double> data;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (a, e) => a + e.value);
    return Padding(
      padding: screenPad,
      child: GlassCard(
        child: Column(
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.key, style: context.tt.titleSmall),
                        ),
                        Text(
                          Money.aed(e.value, decimals: false),
                          style: context.tt.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : e.value / total,
                        minHeight: 4,
                        color: c.accent,
                        backgroundColor: c.border,
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
}
