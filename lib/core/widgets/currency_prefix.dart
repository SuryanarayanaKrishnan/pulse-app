import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// The currency shown inside an amount field, always visible.
///
/// Use it as `prefixIcon: CurrencyPrefix('AED')` together with
/// `prefixIconConstraints: kCurrencyPrefixConstraints`. A plain `prefixText`
/// is hidden by Flutter until the field is focused, which leaves a blank gap
/// before the hint, so never use it for amounts.
class CurrencyPrefix extends StatelessWidget {
  const CurrencyPrefix(this.currency, {super.key});
  final String currency;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Space.lg, right: Space.sm),
    child: Text(
      currency,
      style: context.tt.bodyLarge!.copyWith(color: context.pc.textSecondary),
    ),
  );
}

const kCurrencyPrefixConstraints = BoxConstraints(minWidth: 0, minHeight: 0);
