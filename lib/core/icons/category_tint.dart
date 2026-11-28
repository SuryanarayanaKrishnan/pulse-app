import 'package:material_ui/material_ui.dart';

/// Hue (and how much colour) behind each category colour token from
/// `default_categories.dart`. Deliberately restrained: every tint lands at the
/// same lightness, so no category shouts and the family reads as one.
const _hues = <String, (double, double)>{
  'emerald': (158, 1),
  'lime': (85, 1),
  'green': (135, 1),
  'orange': (24, 1),
  'sky': (200, 1),
  'blue': (216, 1),
  'slate': (214, 0.22),
  'indigo': (236, 1),
  'yellow': (42, 1),
  'cyan': (186, 1),
  'violet': (262, 1),
  'rose': (346, 1),
  'pink': (328, 1),
  'teal': (174, 1),
  'fuchsia': (294, 1),
  'amber': (36, 1),
  'gray': (150, 0.08),
  'stone': (40, 0.12),
  'red': (8, 1),
};

/// The colour token each default category wears (mirrors the seeded rows).
const defaultCategoryTokens = <String, String>{
  'salary': 'emerald',
  'income': 'emerald',
  'other_income': 'lime',
  'groceries': 'green',
  'dining': 'orange',
  'transport': 'sky',
  'car_loan': 'blue',
  'home_loan': 'slate',
  'rent': 'indigo',
  'utilities': 'yellow',
  'telecom': 'cyan',
  'fixed_expenses': 'violet',
  'education': 'blue',
  'health': 'rose',
  'shopping': 'pink',
  'travel': 'teal',
  'entertainment': 'fuchsia',
  'subscriptions': 'violet',
  'family': 'amber',
  'savings': 'emerald',
  'cc_payment': 'gray',
  'transfer': 'gray',
  'gifts': 'rose',
  'fees': 'red',
  'other': 'stone',
};

/// Custom categories borrow a token, steadily, from their id.
const _customRotation = [
  'teal',
  'indigo',
  'amber',
  'rose',
  'green',
  'violet',
  'sky',
  'orange',
];

String categoryTokenFor(String id, {String? token}) {
  if (token != null && _hues.containsKey(token)) return token;
  final known = defaultCategoryTokens[id];
  if (known != null) return known;
  var h = 0;
  for (final u in id.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return _customRotation[h % _customRotation.length];
}

/// The stroke colour for a token: deep in light mode, soft in dark mode.
Color categoryTint(String token, {required bool dark}) {
  final (hue, amount) = _hues[token] ?? _hues['gray']!;
  return HSLColor.fromAHSL(
    1,
    hue,
    (dark ? 0.46 : 0.44) * amount,
    dark ? 0.70 : 0.36,
  ).toColor();
}
