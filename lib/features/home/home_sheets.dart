import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/insights.dart';
import '../../data/providers.dart';

class SafeToSpendSheet extends ConsumerWidget {
  const SafeToSpendSheet(this.v, {super.key});
  final SafeToSpend v;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final flex = v.basis == SafeBasis.flex;
    final hasBudget = v.budgetLeft.isFinite;
    Text num(double x, {bool minus = false}) => Text(
      '${minus ? '−' : ''}${Money.aed(x, decimals: false)}',
      style: PulseTheme.amount(minus ? c.textSecondary : c.textPrimary),
    );
    return SheetScaffold(
      title: 'Safe to spend',
      subtitle: flex
          ? 'Your flexible budget, after what is already promised'
          : 'The lower of what your budget and your cash allow',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              if (hasBudget)
                ListRow(
                  key: const Key('sts_budget_left'),
                  dense: true,
                  title: flex ? 'Flexible left' : 'Left in budget',
                  subtitle: flex
                      ? 'The same number as on your Budget tab'
                      : null,
                  trailing: num(v.budgetLeft),
                ),
              ListRow(
                dense: true,
                title: 'Bills still to come',
                trailing: num(v.bills, minus: true),
              ),
              ListRow(
                dense: true,
                title: 'Card dues this month',
                subtitle: 'From your cash, not your budget',
                trailing: num(v.cardDues, minus: true),
              ),
              ListRow(
                dense: true,
                title: 'Set aside for goals',
                subtitle: v.goals > 0
                    ? '${Money.aed(v.goals, decimals: false)} set aside for goals'
                    : 'Nothing set aside right now',
                trailing: num(v.goals, minus: true),
                chevron: false,
              ),
              for (final g in v.goalLines)
                ListRow(
                  key: ValueKey('goal_line_${g.id}'),
                  dense: true,
                  title: g.name,
                  subtitle: 'Tap to pause',
                  trailing: num(g.amount, minus: true),
                  onTap: () async {
                    await ref.read(goalServiceProvider).setPaused(g.id, true);
                    invalidateGoals(ref);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${g.name} is paused. Safe to spend is updated.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ListRow(
                dense: true,
                title: 'Free until month end',
                titleStyle: context.tt.titleMedium,
                trailing: num(v.available),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (flex && hasBudget) ...[
            Text(
              'Your Budget tab shows Flexible left, before bills still to come and goal set-asides. Safe to spend takes those off, so it can be a little lower.',
              key: const Key('sts_explain'),
              style: context.tt.bodyMedium,
            ),
            const SizedBox(height: Space.md),
          ],
          Text(
            'Spread over ${v.daysLeft} days, that is ${Money.aed(v.today, decimals: false)} a day. It updates with every purchase.',
            style: context.tt.bodyMedium,
          ),
        ],
      ),
    );
  }
}
