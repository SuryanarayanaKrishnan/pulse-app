import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../analytics/analytics.dart';

import '../theme/tokens.dart';
import '../widgets/haptics.dart';

/// Bottom-nav shell: Home, Budget, Cards, Splits, Wealth.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _names = ['/home', '/budget', '/cards', '/splits', '/wealth'];

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).screen(_names[widget.shell.currentIndex]);
  }

  static const _items = AppShellItems.items;

  StatefulNavigationShell get shell => widget.shell;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: c.bg.withValues(alpha: 0.78),
              border: Border(top: BorderSide(color: c.glassBorder)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: _NavItem(
                          icon: shell.currentIndex == i
                              ? _items[i].$1
                              : _items[i].$2,
                          label: _items[i].$3,
                          selected: shell.currentIndex == i,
                          onTap: () {
                            Haptics.tap();
                            if (i != shell.currentIndex)
                              ref.read(analyticsProvider).screen(_names[i]);
                            shell.goBranch(
                              i,
                              initialLocation: i == shell.currentIndex,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShellItems {
  const AppShellItems._();
  static const items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded, 'Budget'),
    (Icons.credit_card_rounded, Icons.credit_card_outlined, 'Cards'),
    (Icons.group_rounded, Icons.group_outlined, 'Splits'),
    (Icons.trending_up_rounded, Icons.trending_up_rounded, 'Wealth'),
  ];
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? c.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 260),
                child: Icon(
                  icon,
                  size: 24,
                  color: selected ? c.accent : c.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: context.tt.labelSmall!.copyWith(
                color: selected ? c.textPrimary : c.textTertiary,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
