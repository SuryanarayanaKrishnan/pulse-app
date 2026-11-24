import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

void backupToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// A quiet boxed note. [warning] uses the amber caution colour (never red:
/// a backup problem is not an emergency).
class Callout extends StatelessWidget {
  const Callout({
    super.key,
    required this.icon,
    required this.text,
    this.title,
    this.warning = false,
  });
  final IconData icon;
  final String? title;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final tone = warning ? c.warning : c.accent;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: c.isDark ? 0.12 : 0.09),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: context.tt.titleMedium),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: context.tt.bodyMedium!.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 12 recovery words, numbered, two columns.
class PhraseGrid extends StatelessWidget {
  const PhraseGrid(this.words, {super.key});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final half = (words.length / 2).ceil();
    Widget col(int from, int to) => Expanded(
      child: Column(
        children: [
          for (var i = from; i < to; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: context.tt.bodySmall!.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                  Text(words[i], style: context.tt.titleMedium),
                ],
              ),
            ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [col(0, half), col(half, words.length)],
      ),
    );
  }
}

/// A tappable choice with a radio mark.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
    this.icon,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final String? badge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, color: selected ? c.accent : c.textSecondary),
                const SizedBox(width: Space.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title, style: context.tt.titleMedium),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: Space.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              badge!,
                              style: context.tt.labelMedium!.copyWith(
                                color: c.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: context.tt.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? c.accent : c.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page scaffold shared by the backup and restore flows: back arrow, a big
/// title, scrolling body and a pinned action area.
class FlowPage extends StatelessWidget {
  const FlowPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions = const [],
    this.onBack,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: onBack,
              ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  0,
                  Space.gutter,
                  Space.xl,
                ),
                children: [
                  Text(title, style: context.tt.displayMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      subtitle!,
                      style: context.tt.bodyLarge!.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.xl),
                  ...children,
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
