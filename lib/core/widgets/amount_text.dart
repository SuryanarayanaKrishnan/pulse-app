import 'package:material_ui/material_ui.dart';

import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';

/// Animated count-up AED amount with tabular figures.
class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.size = 28,
    this.color,
    this.decimals = false,
    this.signed = false,
    this.compact = false,
    this.animate = true,
    this.weight = FontWeight.w800,
  });

  final double value;
  final double size;
  final Color? color;
  final bool decimals;
  final bool signed;
  final bool compact;
  final bool animate;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final style = PulseTheme.amount(
      color ?? context.pc.textPrimary,
      size: size,
      weight: weight,
    );
    String fmt(double v) => compact
        ? Money.aedCompact(v)
        : Money.aed(v, decimals: decimals, sign: signed);
    if (!animate) return Text(fmt(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(fmt(v), style: style),
    );
  }
}
