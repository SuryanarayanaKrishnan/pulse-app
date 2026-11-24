import 'package:material_ui/material_ui.dart';

import 'glyphs.dart';

/// Paints one [Glyph] on the 24 unit grid, scaled to the box.
///
/// The stroke is [strokeWidth] grid units, so the weight stays in proportion
/// at every size. [filled] adds a soft tint inside the glyph's body.
class CategoryGlyphPainter extends CustomPainter {
  const CategoryGlyphPainter(this.glyph, this.color, {this.filled = false});
  final Glyph glyph;
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / glyphGrid;
    canvas.save();
    canvas.translate((size.width - glyphGrid * k) / 2, (size.height - glyphGrid * k) / 2);
    canvas.scale(k);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = color.withValues(alpha: 0.2);
    for (final s in glyph.shapes) {
      if (filled && s.fill) canvas.drawPath(s.path, fill);
      canvas.drawPath(s.path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CategoryGlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.filled != filled;
}
