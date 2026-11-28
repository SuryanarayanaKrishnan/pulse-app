import 'package:material_ui/material_ui.dart';

import '../../core/icons/glyphs.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// The glyphs a custom category can wear, as a calm grid. The chosen one sits
/// in an accent ring and its stroke fills in softly.
class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.columns = 6,
  });

  /// The key of the chosen glyph, or null for the generic tag.
  final String? selected;
  final ValueChanged<String> onChanged;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final g in customGlyphs)
          Semantics(
            button: true,
            selected: g.key == selected,
            label: g.label,
            child: GestureDetector(
              key: ValueKey('icon_${g.key}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(g.key),
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.curve,
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: g.key == selected
                      ? c.accent.withValues(alpha: 0.12)
                      : c.surfaceElevated,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: g.key == selected ? c.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: ExcludeSemantics(
                  child: GlyphIcon(
                    g,
                    size: 26,
                    filled: g.key == selected,
                    color: g.key == selected ? c.accent : c.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
