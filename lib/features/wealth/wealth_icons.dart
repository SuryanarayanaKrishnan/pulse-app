import 'package:material_ui/material_ui.dart';

import '../../core/icons/category_tint.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/category_icon.dart';
import '../../data/models.dart' show AssetKind, SpendCategory;

/// What a person can own or work toward, each with its own glyph and tint so
/// Goals, Gold, Funds, Stocks and Property never look alike on Wealth.
///
/// Glyphs come from the category icon family (`core/icons/glyphs.dart`).
/// Tints stay inside the Wealth palette: gold and amber for things you hold,
/// violet and indigo for things that grow or are saved toward; property sits
/// in a quiet warm stone.
enum WealthKind {
  goal('savings', 'violet', 'Goal'),
  payDown('fees', 'indigo', 'Pay down'),
  gold('gold', 'yellow', 'Gold'),
  jewellery('jewellery', 'amber', 'Jewellery'),
  fund('fund', 'indigo', 'Mutual fund'),
  stock('chart', 'fuchsia', 'Stock or ETF'),
  investingRule('percent', 'violet', 'Investing rule'),
  property('property', 'stone', 'Property'),
  deposit('landmark', 'amber', 'Deposit'),
  cash('coins', 'yellow', 'Cash'),
  loan('fees', 'rose', 'Loan'),
  other('wallet', 'stone', 'Other');

  const WealthKind(this.glyphKey, this.token, this.label);
  final String glyphKey;

  /// A hue name from `category_tint.dart`.
  final String token;
  final String label;

  static WealthKind forAsset(AssetKind k) => switch (k) {
    AssetKind.cash => WealthKind.cash,
    AssetKind.fixedDeposit => WealthKind.deposit,
    AssetKind.stocks => WealthKind.stock,
    AssetKind.funds => WealthKind.fund,
    AssetKind.gold => WealthKind.gold,
    AssetKind.realEstate => WealthKind.property,
    AssetKind.liability => WealthKind.loan,
    AssetKind.other => WealthKind.other,
  };

  Color tint({required bool dark}) => categoryTint(token, dark: dark);
}

/// The icon chip for a [WealthKind]: the same rounded tile as every category
/// icon, so lists and detail headers match.
class WealthIcon extends StatelessWidget {
  const WealthIcon(this.kind, {super.key, this.size = 40, this.glyphKey});
  final WealthKind kind;
  final double size;

  /// A goal's own picked glyph, drawn in the goal tint.
  final String? glyphKey;

  @override
  Widget build(BuildContext context) {
    final dark = context.pc.isDark;
    return CategoryIcon.well(
      SpendCategory.custom(
        'wealth_${kind.name}',
        kind.label,
        iconKey: glyphKey ?? kind.glyphKey,
      ),
      size: size,
      color: kind.tint(dark: dark),
    );
  }
}
