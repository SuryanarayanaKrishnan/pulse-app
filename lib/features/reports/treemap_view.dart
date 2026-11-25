import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/treemap.dart';
import '../../core/theme/tokens.dart';

/// One tile's content: what to call it and what it is worth.
class TreemapEntry {
  const TreemapEntry(this.id, this.label, this.value, this.valueLabel);
  final String id, label, valueLabel;
  final double value;
}

/// A treemap drawn with a custom painter. Tiles are shaded from the accent
/// down to the neutral surface by rank, so it stays in the calm palette.
/// Tap a tile to select it; [onSelect] reports the id.
class TreemapView extends StatelessWidget {
  const TreemapView({
    super.key,
    required this.entries,
    required this.selectedId,
    required this.onSelect,
    this.height = 280,
  });
  final List<TreemapEntry> entries;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, height);
        final tiles = layoutTreemap([for (final e in entries) TreemapInput(e.id, e.value)], size.width, size.height);
        final byId = {for (final e in entries) e.id: e};
        return Semantics(
          container: true,
          label: 'Spending treemap',
          child: GestureDetector(
            key: const Key('treemap'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              for (final t in tiles) {
                if (d.localPosition.dx >= t.left &&
                    d.localPosition.dx <= t.right &&
                    d.localPosition.dy >= t.top &&
                    d.localPosition.dy <= t.bottom) {
                  HapticFeedback.selectionClick();
                  onSelect(t.id);
                  return;
                }
              }
            },
            child: CustomPaint(
              size: size,
              painter: TreemapPainter(
                tiles: tiles,
                entries: byId,
                selectedId: selectedId,
                accent: c.accent,
                base: c.surfaceElevated,
                bg: c.isDark ? c.bg : c.surface,
                textColor: c.textPrimary,
                dark: c.isDark,
                labelStyle: context.tt.labelMedium!,
                valueStyle: context.tt.bodySmall!,
              ),
            ),
          ),
        );
      },
    );
  }
}

class TreemapPainter extends CustomPainter {
  TreemapPainter({
    required this.tiles,
    required this.entries,
    required this.selectedId,
    required this.accent,
    required this.base,
    required this.bg,
    required this.textColor,
    required this.dark,
    required this.labelStyle,
    required this.valueStyle,
  });
  final List<TreemapTile> tiles;
  final Map<String, TreemapEntry> entries;
  final String? selectedId;
  final Color accent, base, bg, textColor;
  final bool dark;
  final TextStyle labelStyle, valueStyle;

  static const gap = 2.0;

  /// Tile fill for rank [i] of [n]: accent for the biggest, fading to the
  /// neutral surface.
  Color fill(int i, int n) {
    final t = n <= 1 ? 0.0 : i / (n - 1);
    return Color.lerp(accent.withValues(alpha: dark ? 0.78 : 0.9), base, t * 0.85)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, t) in tiles.indexed) {
      final rect = Rect.fromLTWH(t.left, t.top, t.width, t.height).deflate(gap / 2);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.sm));
      final color = fill(i, tiles.length);
      canvas.drawRRect(rr, Paint()..color = color);
      if (t.id == selectedId) {
        canvas.drawRRect(
          rr.deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = dark ? Colors.white : Colors.black.withValues(alpha: 0.75),
        );
      }
      final e = entries[t.id];
      if (e == null || rect.width < 54 || rect.height < 34) continue;
      final fg = ThemeData.estimateBrightnessForColor(Color.alphaBlend(color, bg)) == Brightness.dark
          ? Colors.white
          : const Color(0xFF101413);
      void text(String s, TextStyle st, double dy) {
        final tp = TextPainter(
          text: TextSpan(text: s, style: st.copyWith(color: fg)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: rect.width - 12);
        tp.paint(canvas, Offset(rect.left + 8, rect.top + dy));
      }

      text(e.label, labelStyle.copyWith(fontWeight: FontWeight.w600), 8);
      if (rect.height >= 52) text(e.valueLabel, valueStyle, 26);
    }
  }

  @override
  bool shouldRepaint(TreemapPainter old) =>
      old.tiles != tiles || old.selectedId != selectedId || old.accent != accent || old.dark != dark;
}
