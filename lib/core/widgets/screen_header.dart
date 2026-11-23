import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Large screen title row with optional trailing widgets.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.lg,
      Space.gutter,
      Space.sm,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(subtitle!, style: context.tt.bodyMedium),
              Text(title, style: context.tt.displayMedium),
            ],
          ),
        ),
        ...?trailing,
      ],
    ),
  );
}

/// Circular icon button used in headers.
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
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surfaceElevated,
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, color: c.textPrimary, size: 22),
        ),
      ),
    );
  }
}
