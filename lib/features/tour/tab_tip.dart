import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import 'tour_progress.dart';

/// The one line of copy for each tab's first-visit tip.
const tabTipCopy = {
  TipTab.home: 'Tap your number to see exactly how it is worked out.',
  TipTab.budget: 'Recurring bills and Household are one tap under the title.',
  TipTab.cards: 'Tap the bolt before you pay and we name the best card.',
  TipTab.splits: 'Add an expense in a few taps. Settling up is one more.',
  TipTab.wealth: 'Add gold, funds, property or loans. It all counts here.',
};

/// Which tips have a target on screen, and which one (at most one) is showing.
@immutable
class TipState {
  const TipState({this.targets = const {}, this.shown});
  final Map<TipTab, int> targets;
  final TipTab? shown;
  bool hasTarget(TipTab t) => (targets[t] ?? 0) > 0;
}

class TipController extends Notifier<TipState> {
  @override
  TipState build() => const TipState();

  void register(TipTab t) => state = TipState(
    targets: {...state.targets, t: (state.targets[t] ?? 0) + 1},
    shown: state.shown,
  );

  void unregister(TipTab t) {
    final n = (state.targets[t] ?? 0) - 1;
    final m = {...state.targets};
    if (n <= 0) {
      m.remove(t);
    } else {
      m[t] = n;
    }
    state = TipState(targets: m, shown: state.shown);
  }

  void show(TipTab t) => state = TipState(targets: state.targets, shown: t);
  void hide() => state = TipState(targets: state.targets);
}

final tipControllerProvider = NotifierProvider<TipController, TipState>(
  TipController.new,
);

/// Marks the one most useful thing on a tab. It only registers that the thing
/// is on screen; the tip itself is shown by [TipDock] in the app shell, so it
/// never floats over content. Touching the marked thing dismisses the tip and
/// is never blocked.
class TabTip extends ConsumerStatefulWidget {
  const TabTip({super.key, required this.tab, required this.child});
  final TipTab tab;
  final Widget child;

  @override
  ConsumerState<TabTip> createState() => _TabTipState();
}

class _TabTipState extends ConsumerState<TabTip> {
  late final TipController _ctl = ref.read(tipControllerProvider.notifier);
  late final TipTab _tab = widget.tab;

  @override
  void initState() {
    super.initState();
    // Providers must not change while the tree is building.
    Future.microtask(() {
      if (mounted) _ctl.register(_tab);
    });
  }

  @override
  void dispose() {
    final c = _ctl;
    final t = _tab;
    Future.microtask(() {
      try {
        c.unregister(t);
      } catch (_) {
        // The scope is already gone.
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) {
      if (ref.read(tipControllerProvider).shown == _tab) _ctl.hide();
    },
    child: widget.child,
  );
}

/// Hosts the app body and, when a tip is due, a slim card between the body
/// and the tab bar. The card takes its own space (the body shrinks to make
/// room), so it can never cover content, and it points at its tab.
///
/// One tip at a time: only the tab in front can show its tip, and the others
/// wait until that tab is opened (this session or a later one).
class TipDock extends ConsumerStatefulWidget {
  const TipDock({
    super.key,
    required this.current,
    required this.child,
    this.bottomInset = 0,
    this.delay = const Duration(milliseconds: 900),
    this.visibleFor = const Duration(seconds: 10),
  });

  /// The tab in front (its index is its slot in the tab bar).
  final TipTab current;
  final Widget child;

  /// Height of the tab bar drawn over the bottom of the body.
  final double bottomInset;
  final Duration delay;
  final Duration visibleFor;

  @override
  ConsumerState<TipDock> createState() => _TipDockState();
}

class _TipDockState extends ConsumerState<TipDock> {
  Timer? _wait;
  Timer? _hide;
  TipTab? _waitingFor;

  bool _eligible(TipTab t) {
    final p = ref.read(tourProgressProvider);
    return p.loaded &&
        !p.tipSeen(t) &&
        ref.read(tipControllerProvider).hasTarget(t);
  }

  void _sync() {
    if (!mounted) return;
    final shown = ref.read(tipControllerProvider).shown;
    if (shown != null && shown != widget.current) {
      _clear();
      return;
    }
    if (shown == null) {
      _hide?.cancel();
      if (_waitingFor != null && _waitingFor != widget.current) {
        _wait?.cancel();
        _waitingFor = null;
      }
      if (_waitingFor == null && _eligible(widget.current)) {
        final t = widget.current;
        _waitingFor = t;
        _wait = Timer(widget.delay, () {
          _waitingFor = null;
          if (!mounted || t != widget.current || !_eligible(t)) return;
          ref.read(tourProgressProvider.notifier).markTipSeen(t);
          ref.read(tipControllerProvider.notifier).show(t);
          _hide = Timer(widget.visibleFor, _dismiss);
        });
      }
    }
  }

  void _clear() {
    _hide?.cancel();
    ref.read(tipControllerProvider.notifier).hide();
  }

  void _dismiss() {
    if (mounted) _clear();
  }

  @override
  void didUpdateWidget(TipDock old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _wait?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tipControllerProvider);
    ref.watch(tourProgressProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    final reduced = MediaQuery.disableAnimationsOf(context);
    final shown = state.shown;
    final dock = SizedBox(
      width: double.infinity,
      child: shown == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TipCard(
                  key: ValueKey(shown),
                  text: tabTipCopy[shown]!,
                  slot: TipTab.values.indexOf(shown),
                  slots: TipTab.values.length,
                  onDismiss: _clear,
                ),
                SizedBox(height: widget.bottomInset),
              ],
            ),
    );
    return Column(
      children: [
        Expanded(child: widget.child),
        if (reduced)
          dock
        else
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.curve,
            alignment: Alignment.bottomCenter,
            child: dock,
          ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    super.key,
    required this.text,
    required this.slot,
    required this.slots,
    required this.onDismiss,
  });
  final String text;
  final int slot, slots;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final bg = c.isDark ? c.surfaceElevated : c.textPrimary;
    final fg = c.isDark ? c.textPrimary : c.bg;
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        container: true,
        label: 'Tip',
        child: GestureDetector(
          key: const Key('tab_tip'),
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final cx = box.maxWidth * (slot + .5) / slots;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                        vertical: Space.sm,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              text,
                              style: context.tt.bodyMedium!.copyWith(color: fg),
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Icon(
                            Icons.close_rounded,
                            size: 16,
                            semanticLabel: 'Dismiss tip',
                            color: fg.withValues(alpha: .6),
                          ),
                        ],
                      ),
                    ),
                    // Points down at this tab in the bar below.
                    SizedBox(
                      height: 7,
                      width: double.infinity,
                      child: CustomPaint(painter: _Nub(bg, cx - 7)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Nub extends CustomPainter {
  _Nub(this.color, this.left);
  final Color color;
  final double left;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(left, 0)
      ..lineTo(left + 7, size.height)
      ..lineTo(left + 14, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Nub old) => old.color != color || old.left != left;
}
