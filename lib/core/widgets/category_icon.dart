import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../icons/category_painter.dart';
import '../icons/category_tint.dart';
import '../icons/glyphs.dart';
import '../theme/tokens.dart';

/// The glyph a category wears: a default's own, a custom category's pick, or
/// the generic tag when it has none (or one this version does not know).
Glyph glyphFor(SpendCategory category) {
  if (!category.custom) {
    final key = defaultGlyphKeys[category.id];
    final g = key == null ? null : glyphsByKey[key];
    if (g != null) return g;
  }
  return glyphsByKey[category.iconKey] ?? glyphsByKey[defaultGlyphKeys[category.id]] ?? genericGlyph;
}

/// True when [category] resolves to a real glyph rather than the fallback.
bool hasOwnGlyph(SpendCategory category) => glyphFor(category) != genericGlyph;

/// The one category icon, used everywhere a category appears.
///
/// A calm stroke glyph on a 24 unit grid, tinted from the category's colour
/// token and tuned for the current light or dark theme. [filled] adds a soft
/// tint inside the body (selected or emphasised states).
///
/// `CategoryIcon.well` sits the glyph on a quiet tinted tile, the way a list
/// row leads.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon(
    this.category, {
    super.key,
    this.size = 24,
    this.filled = false,
    this.color,
  }) : _well = false;

  /// The glyph on a soft rounded tile. [size] is the tile; the glyph is 56%.
  const CategoryIcon.well(
    this.category, {
    super.key,
    this.size = 32,
    this.filled = false,
    this.color,
  }) : _well = true;

  final SpendCategory category;
  final double size;
  final bool filled;

  /// Override the tint (rare: a disabled or inverted context).
  final Color? color;
  final bool _well;

  @override
  Widget build(BuildContext context) {
    final dark = context.pc.isDark;
    final tint = color ?? categoryTint(categoryTokenFor(category.id), dark: dark);
    final glyph = glyphFor(category);
    final paint = Semantics(
      label: category.label,
      image: true,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(_well ? size * 0.58 : size),
          painter: CategoryGlyphPainter(glyph, tint, filled: filled),
        ),
      ),
    );
    if (!_well) return SizedBox.square(dimension: size, child: paint);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: dark ? 0.16 : 0.11),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: paint,
    );
  }
}

/// A glyph by key, for the picker (no category yet).
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.size = 24, this.color, this.filled = false});
  final Glyph glyph;
  final double size;
  final Color? color;
  final bool filled;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: CategoryGlyphPainter(glyph, color ?? context.pc.textSecondary, filled: filled)),
  );
}
