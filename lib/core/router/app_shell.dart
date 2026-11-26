import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/rewards/reward_moment.dart';
import '../../features/tour/tab_tip.dart';
import '../../features/tour/tour_progress.dart';
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
    // A capture arrived (SMS, wallet tap, Shortcut): refresh and celebrate.
    ref.listen(captureOutcomesProvider, (_, next) {
      final o = next.value;
      if (o != null) onCaptured(context, ref, o);
    });
    // Back from Budget, Cards, Splits or Wealth goes to Home first; only Home
    // lets the system close the app.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        extendBody: true,
        body: TipDock(
          current: TipTab.values[shell.currentIndex],
          bottomInset: 56 + MediaQuery.viewPaddingOf(context).bottom,
          child: shell,
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: c.bg.withValues(alpha: 0.82),
                border: Border(top: BorderSide(color: c.border, width: 0.5)),
              ),
              child: SafeArea(
                top: false,
                // The bar is a fixed 56 high: cap how far large text can grow
                // its labels so they never overflow it.
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.0,
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: _NavItem(
                              index: i,
                              icon: shell.currentIndex == i
                                  ? _items[i].$1
                                  : _items[i].$2,
                              label: _items[i].$3,
                              selected: shell.currentIndex == i,
                              onTap: () {
                                if (i != shell.currentIndex) {
                                  Haptics.tap();
                                  ref.read(analyticsProvider).screen(_names[i]);
                                }
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
        ),
      ),
    );
  }
}

class AppShellItems {
  const AppShellItems._();
  static const items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.donut_large_rounded, Icons.donut_large_rounded, 'Budget'),
    (Icons.credit_card_rounded, Icons.credit_card_outlined, 'Cards'),
    (Icons.people_rounded, Icons.people_outline_rounded, 'Splits'),
    (Icons.show_chart_rounded, Icons.show_chart_rounded, 'Wealth'),
  ];
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final color = selected
        ? c.tabAccent(PulseTab.values[index])
        : c.textTertiary;
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
            AnimatedSwitcher(
              duration: Motion.fast,
              child: Icon(icon, key: ValueKey(icon), size: 24, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: context.tt.labelSmall!.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
