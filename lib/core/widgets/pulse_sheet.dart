import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Opens a themed modal bottom sheet.
Future<T?> showPulseSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  bool full = false,

  /// Open above the whole app, tab bar included. On by default: a sheet on
  /// the tab's own navigator sits under the floating tab bar, which then
  /// hides its bottom buttons. Pass false only for something meant to stay
  /// inside a tab.
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      curve: Curves.easeOutQuart,
      reverseDuration: Duration(milliseconds: 240),
    ),
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
        color: c.isDark ? c.surface : c.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.lg),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
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
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(bottom: Space.lg),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Text(title, style: context.tt.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: Space.xs),
              Text(subtitle!, style: context.tt.bodyMedium),
            ],
            const SizedBox(height: Space.xl),
            child,
          ],
        ),
      ),
    );
  }
}
