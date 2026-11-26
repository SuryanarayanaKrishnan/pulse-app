import 'package:material_ui/material_ui.dart';

import '../../core/engine/live_quote.dart';
import '../../core/theme/tokens.dart';

/// "Today +₹120 (+0.4%)" under a holding's value, from the stored previous
/// close/NAV. Shows nothing, never a guess, when there is no genuine
/// earlier price to compare with.
class DayChangeText extends StatelessWidget {
  const DayChangeText({
    super.key,
    required this.quote,
    required this.quantity,
    required this.currency,
  });
  final LiveQuote? quote;
  final double quantity;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final change = q?.dayChange, pct = q?.dayChangePct;
    if (q == null || change == null || pct == null)
      return const SizedBox.shrink();
    final c = context.pc;
    final total = change * quantity;
    final sign = total >= 0 ? '+' : '-';
    return Text(
      'Today $sign$currency ${total.abs().toStringAsFixed(0)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)',
      key: const Key('day-change'),
      style: context.tt.bodySmall!.copyWith(
        color: total >= 0 ? c.positive : c.negative,
      ),
    );
  }
}
