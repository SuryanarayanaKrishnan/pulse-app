import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Opens a themed modal bottom sheet.
Future<T?> showPulseSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  bool full = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    constraints: BoxConstraints(
      maxWidth: 560,
      maxHeight: MediaQuery.sizeOf(context).height * (full ? 0.94 : 0.88),
    ),
    builder: builder,
  );
}

/// Standard bottom sheet chrome: grabber, title, keyboard-aware padding.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
        border: Border.all(color: c.glassBorder),
      ),
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        MediaQuery.viewInsetsOf(context).bottom + Space.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: Space.lg),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(title, style: context.tt.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: context.tt.bodyMedium),
            ],
            const SizedBox(height: Space.lg),
            child,
          ],
        ),
      ),
    );
  }
}
