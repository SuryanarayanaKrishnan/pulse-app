import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/insights.dart';

/// What the health score is made of, factor by factor.
class HealthSheet extends StatelessWidget {
  const HealthSheet(this.h, {super.key});
  final HealthScore h;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Color tone(double v) => v >= 0.7
        ? c.accent
        : v >= 0.4
        ? c.warning
        : c.negative;
    return SheetScaffold(
      title: 'Financial health',
      subtitle: h.readiness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${h.score}',
                style: PulseTheme.amount(
                  c.textPrimary,
                  size: 40,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                '/ 100 · ${h.band}',
                style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          for (final f in h.factors) ...[
            Row(
              children: [
                Expanded(child: Text(f.name, style: context.tt.bodyLarge)),
                Text(
                  '${(f.score * 100).round()}',
                  style: PulseTheme.amount(c.textPrimary, size: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Meter(value: f.score, color: tone(f.score)),
            const SizedBox(height: 6),
            Text(f.reading, style: context.tt.bodySmall),
            const SizedBox(height: Space.lg),
          ],
          Text(
            'Savings rate 30%, card utilisation 25%, bills on time 25%, emergency runway 20%. Recomputed every morning.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}
