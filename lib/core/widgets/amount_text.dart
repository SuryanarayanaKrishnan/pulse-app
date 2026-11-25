import 'package:material_ui/material_ui.dart';

import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';

/// AED amount with tabular figures. When the value changes it eases from the
/// previous value; it never counts up from zero on first build.
class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.size = 17,
    this.color,
    this.decimals = false,
    this.signed = false,
    this.compact = false,
    this.animate = true,
    this.weight = FontWeight.w600,
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
      tween: Tween(begin: value, end: value),
      duration: Motion.slow,
      curve: Motion.curve,
      builder: (_, v, _) =>
          Text(fmt(v), style: style, maxLines: 1, semanticsLabel: fmt(value)),
    );
  }
}

/// The one large number on a screen, with a quiet label above and an
/// optional caption below.
class HeroNumber extends StatelessWidget {
  const HeroNumber({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.captionColor,
    this.color,
    this.footer,
  });
  final String label;
  final double value;
  final String? caption;
  final Color? captionColor;
  final Color? color;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.tt.bodyMedium),
        const SizedBox(height: Space.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AmountText(
            value,
            size: 40,
            weight: FontWeight.w700,
            color:
                color ?? (value < 0 ? context.pc.negative : context.tabInk()),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            caption!,
            style: context.tt.bodyMedium!.copyWith(color: captionColor),
          ),
        ],
        if (footer != null) ...[const SizedBox(height: Space.lg), footer!],
      ],
    ),
  );
}
