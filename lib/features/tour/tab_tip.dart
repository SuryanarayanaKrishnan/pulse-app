import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import 'tour_progress.dart';

/// The one line of copy for each tab's first-visit tip.
const tabTipCopy = {
  TipTab.home: 'Tap your number to see exactly how it is worked out.',
  TipTab.budget: 'Swipe the categories. The ones closest to their limit lead.',
  TipTab.cards: 'Tap the bolt before you pay and we name the best card.',
  TipTab.splits: 'Add an expense in a few taps. Settling up is one more.',
  TipTab.wealth: 'Add gold, funds, property or loans. It all counts here.',
};

/// Marks the one most useful thing on a tab. The first time the tab is open
/// and this widget is on screen, a small tip floats beside it, once.
///
/// It never blocks: the tip is a floating overlay, touches outside it go
/// straight through, touching the marked thing dismisses it, and it fades on
/// its own after [visibleFor]. Seen state is persisted, see
/// [TourProgressController].
class TabTip extends ConsumerStatefulWidget {
  const TabTip({
    super.key,
    required this.tab,
    required this.child,
    this.alignEnd = false,
    this.delay = const Duration(milliseconds: 900),
    this.visibleFor = const Duration(seconds: 8),
  });
  final TipTab tab;
  final Widget child;

  /// Anchor the tip to the target's trailing edge (for header buttons).
  final bool alignEnd;
  final Duration delay;
  final Duration visibleFor;

  @override
  ConsumerState<TabTip> createState() => _TabTipState();
}

class _TabTipState extends ConsumerState<TabTip> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _poll;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      tourProgressProvider,
      (_, s) => _consider(s),
      fireImmediately: true,
    );
  }

  void _consider(TourProgress s) {
    if (!s.loaded || s.tipSeen(widget.tab)) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (_entry != null) return;
    // Wait for the screen to settle, then keep trying until this tab is the
    // one in front (a reset can happen while Settings is on top).
    _poll ??= Timer(widget.delay, _tryPresent);
  }

  bool get _tabInFront {
    final router = GoRouter.maybeOf(context);
    if (router == null) return true;
    return router.routerDelegate.currentConfiguration.uri.path ==
        widget.tab.path;
  }

  void _tryPresent() {
    _poll = null;
    if (!mounted || _entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null ||
        !TickerMode.valuesOf(context).enabled ||
        !_tabInFront) {
      _poll = Timer(const Duration(seconds: 1), _tryPresent);
      return;
    }
    ref.read(tourProgressProvider.notifier).markTipSeen(widget.tab);
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: widget.alignEnd
              ? Alignment.bottomRight
              : Alignment.bottomLeft,
          followerAnchor: widget.alignEnd
              ? Alignment.topRight
              : Alignment.topLeft,
          offset: const Offset(0, 6),
          child: _TipBubble(
            text: tabTipCopy[widget.tab]!,
            alignEnd: widget.alignEnd,
            onDismiss: _dismiss,
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    _hide = Timer(widget.visibleFor, _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _dismiss(),
      child: widget.child,
    ),
  );
}

class _TipBubble extends StatelessWidget {
  const _TipBubble({
    required this.text,
    required this.alignEnd,
    required this.onDismiss,
  });
  final String text;
  final bool alignEnd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final bubbleColor = c.isDark ? c.surfaceElevated : c.textPrimary;
    final fg = c.isDark ? c.textPrimary : c.bg;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: reduced ? Duration.zero : Motion.slow,
      curve: Motion.curve,
      builder: (_, p, child) => Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, (1 - p) * 6),
          child: child,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          liveRegion: true,
          container: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: Padding(
              padding: EdgeInsets.only(
                left: alignEnd ? 0 : Space.gutter,
                right: alignEnd ? Space.sm : 0,
              ),
              child: Column(
                crossAxisAlignment: alignEnd
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Space.lg),
                    child: CustomPaint(
                      size: const Size(14, 7),
                      painter: _Nub(bubbleColor),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 256),
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.md,
                      Space.lg,
                      Space.md,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(Radii.md),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: c.isDark ? .35 : .14,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            text,
                            style: context.tt.bodyMedium!.copyWith(color: fg),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            semanticLabel: 'Dismiss tip',
                            color: fg.withValues(alpha: .6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Nub extends CustomPainter {
  _Nub(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Nub old) => old.color != color;
}
