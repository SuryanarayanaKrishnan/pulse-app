import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../../features/coach/coach.dart';
import 'pressable.dart';

/// Large title with an optional quiet line above it and trailing actions.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.sm,
      Space.sm,
      Space.lg,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(
                  subtitle!.toUpperCase(),
                  style: context.tt.labelMedium!.copyWith(
                    color: context.tabAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.tt.displayMedium!.copyWith(
                    color: context.tabInk(),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: Space.sm),
              // The friendly underline motif: a short accent pill.
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: context.tabAccent,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ],
          ),
        ),
        ...?trailing,
        if (CoachHost.isAvailable(context))
          RoundIconButton(
            key: const Key('coach_help'),
            icon: Icons.help_outline_rounded,
            label: 'Show me around',
            onTap: () => CoachHost.replay(context),
          ),
      ],
    ),
  );
}

/// Header action: a bare accent glyph with a 44pt target. No chrome.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: context.tabAccent, size: 26),
      ),
    ),
  );
}
