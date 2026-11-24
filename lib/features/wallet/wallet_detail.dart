import 'package:material_ui/material_ui.dart';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Opens the detail pager over the stack. The tapped card flies into place
/// (shared element); the page behind fades. Reduced motion: no animation.
Future<void> openWalletDetail(
  BuildContext context, {
  required int count,
  required int initial,
  required Widget Function(BuildContext, int) faceBuilder,
  required Object Function(int) heroTag,
  required String Function(int) title,
  required List<Widget> Function(BuildContext, int) sections,
}) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 460),
      reverseTransitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 340),
      pageBuilder: (_, _, _) => WalletDetailPager(
        count: count,
        initial: initial,
        faceBuilder: faceBuilder,
        heroTag: heroTag,
        title: title,
        sections: sections,
      ),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: anim,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        ),
        child: child,
      ),
    ),
  );
}

class WalletDetailPager extends StatefulWidget {
  const WalletDetailPager({
    super.key,
    required this.count,
    required this.initial,
    required this.faceBuilder,
    required this.heroTag,
    required this.title,
    required this.sections,
  });
  final int count;
  final int initial;
  final Widget Function(BuildContext, int) faceBuilder;
  final Object Function(int) heroTag;
  final String Function(int) title;
  final List<Widget> Function(BuildContext, int) sections;

  @override
  State<WalletDetailPager> createState() => _WalletDetailPagerState();
}

class _WalletDetailPagerState extends State<WalletDetailPager> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  /// How far the page has been pulled down past its top.
  double _pull = 0;
  bool _closing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      setState(() => _pull += -n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        _pull > 0 &&
        (n.scrollDelta ?? 0) > 0) {
      setState(() => _pull = (_pull - n.scrollDelta!).clamp(0, 400));
    } else if (n is ScrollEndNotification ||
        (n is UserScrollNotification && n.direction == ScrollDirection.idle)) {
      if (_pull > 90) {
        _close();
      } else if (_pull != 0) {
        setState(() => _pull = 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final t = (_pull / 300).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: c.bg.withValues(alpha: 1 - t * 0.6),
      body: SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: _pull == 0 ? Motion.base : Duration.zero,
          curve: Motion.curve,
          transform: Matrix4.translationValues(0, _pull * 0.6, 0),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: c.accent,
                        size: 28,
                      ),
                      onPressed: _close,
                    ),
                    Expanded(
                      child: Semantics(
                        label: '${_index + 1} of ${widget.count}',
                        child: _Dots(count: widget.count, index: _index),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  // Cards can be dragged with a mouse or trackpad too.
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: widget.count,
                      onPageChanged: (i) {
                        Haptics.tap();
                        setState(() => _index = i);
                      },
                      itemBuilder: (context, i) => ListView(
                        key: PageStorageKey('wallet-detail-$i'),
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: Space.xxxl),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.gutter,
                              Space.sm,
                              Space.gutter,
                              0,
                            ),
                            child: Hero(
                              tag: widget.heroTag(i),
                              child: widget.faceBuilder(context, i),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.gutter,
                              Space.xl,
                              Space.gutter,
                              0,
                            ),
                            child: Text(
                              widget.title(i),
                              style: context.tt.headlineSmall,
                            ),
                          ),
                          ...widget.sections(context, i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? c.textPrimary : c.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
