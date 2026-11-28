import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/haptics.dart';
import '../../core/widgets/pressable.dart';
import '../../data/providers.dart';
import '../tour/tour_progress.dart';
import 'coach_copy.dart';
import 'coach_pack.dart';
import 'coach_progress.dart';

export 'coach_copy.dart';
export 'coach_progress.dart';

/// What a screen shares with its [CoachTarget]s and its help button.
class _CoachScope extends InheritedWidget {
  const _CoachScope({required this.host, required super.child});
  final _CoachHostState host;
  @override
  bool updateShouldNotify(_CoachScope old) => false;
}

/// Wraps a screen so it can run its first-visit walkthrough. The walkthrough
/// starts by itself once per screen (after the intro tour has been seen),
/// can be replayed from the screen's help button or from Settings, and is
/// skippable at any point.
class CoachHost extends ConsumerStatefulWidget {
  const CoachHost({
    super.key,
    required this.screen,
    required this.child,
    this.delay = const Duration(milliseconds: 700),
  });
  final CoachScreen screen;
  final Widget child;
  final Duration delay;

  /// Replays the walkthrough of the screen around [context], if it has one.
  static bool replay(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<_CoachScope>();
    if (s == null) return false;
    s.host._start(force: true);
    return true;
  }

  static bool isAvailable(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_CoachScope>() != null;

  @override
  ConsumerState<CoachHost> createState() => _CoachHostState();
}

class _CoachHostState extends ConsumerState<CoachHost> {
  final _keys = <String, GlobalKey>{};
  Timer? _timer;
  OverlayEntry? _entry;
  bool _scheduled = false;

  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  TipTab? get _tipTab {
    for (final t in TipTab.values) {
      if (t.key == widget.screen.key) return t;
    }
    return null;
  }

  bool get _visible =>
      mounted &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  void _consider() {
    if (_scheduled || _entry != null) return;
    final p = ref.read(coachProgressProvider);
    final tour = ref.read(tourProgressProvider);
    if (!p.loaded || p.isSeen(widget.screen)) return;
    // The intro tour goes first; never stack the two.
    if (!tour.loaded || !tour.tourSeen) return;
    if (!_visible) return;
    _scheduled = true;
    // The walkthrough replaces this tab's one-line tip.
    final tab = _tipTab;
    if (tab != null) {
      ref.read(tourProgressProvider.notifier).markTipSeen(tab);
    }
    _timer = Timer(widget.delay, () {
      _scheduled = false;
      if (_visible) _start();
    });
  }

  void _start({bool force = false}) {
    if (!mounted || _entry != null) return;
    final steps = <(CoachStep, GlobalKey)>[
      for (final s in coachStepsFor(
        widget.screen,
        ref.read(contentPacksProvider).pack('walkthrough'),
      ))
        if (_keys[s.id]?.currentContext != null) (s, _keys[s.id]!),
    ];
    if (steps.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    ref.read(coachProgressProvider.notifier).markSeen(widget.screen);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoachOverlay(
        steps: steps,
        onClosed: () {
          if (_entry == entry) _entry = null;
          entry.remove();
          entry.dispose();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consider();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    final e = _entry;
    _entry = null;
    if (e != null) {
      e.remove();
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(coachProgressProvider, (_, _) => _consider());
    ref.listen(tourProgressProvider, (_, _) => _consider());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consider();
    });
    return _CoachScope(host: this, child: widget.child);
  }
}

/// Marks a control a walkthrough step can point at. Outside a [CoachHost] it
/// does nothing.
class CoachTarget extends StatelessWidget {
  const CoachTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<_CoachScope>();
    if (s == null) return child;
    return KeyedSubtree(key: s.host.keyFor(id), child: child);
  }
}

/// The overlay: a dimmed screen with one lit window that glides between
/// targets, and a calm card that says what each one is.
class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.steps, required this.onClosed});
  final List<(CoachStep, GlobalKey)> steps;
  final VoidCallback onClosed;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with TickerProviderStateMixin {
  late final _enter = AnimationController(vsync: this, duration: Motion.base);
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  int _i = -1;
  Rect _from = Rect.zero;
  Rect _to = Rect.zero;
  bool _closing = false;
  bool _busy = false;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _enter.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _move.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Rect get _rect => Rect.lerp(_from, _to, Motion.curve.transform(_move.value))!;

  Future<void> _go(int next) async {
    if (_busy || !mounted) return;
    if (next >= widget.steps.length) return _close();
    _busy = true;
    final ctx = widget.steps[next].$2.currentContext;
    if (ctx == null) {
      _busy = false;
      return _go(next + 1);
    }
    if (Scrollable.maybeOf(ctx) != null) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: .3,
        duration: _reduced ? Duration.zero : const Duration(milliseconds: 320),
        curve: Motion.curve,
      );
    }
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || box.size.isEmpty) {
      _busy = false;
      return _go(next + 1);
    }
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final bounds = Rect.fromLTRB(
      8,
      pad.top + 4,
      screen.width - 8,
      screen.height - pad.bottom - 4,
    );
    final target = (box.localToGlobal(Offset.zero) & box.size)
        .inflate(8)
        .intersect(bounds);
    setState(() {
      final first = _i < 0;
      _from = first
          ? Rect.fromCenter(center: target.center, width: 0, height: 0)
          : _rect;
      _to = target;
      _i = next;
    });
    _busy = false;
    if (_reduced) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    if (!_reduced) await _enter.reverse();
    if (mounted) widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    if (_i < 0) return const SizedBox.shrink();
    final c = context.pc;
    final fg = c.isDark ? c.textPrimary : c.bg;
    final bg = c.isDark ? c.surfaceElevated : c.textPrimary;
    final step = widget.steps[_i].$1;
    final last = _i == widget.steps.length - 1;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    return FadeTransition(
      opacity: _enter,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Absorbs touches so the screen underneath cannot be used mid-tour.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: AnimatedBuilder(
                  animation: Listenable.merge([_move, _pulse]),
                  builder: (_, _) => CustomPaint(
                    painter: _ScrimPainter(
                      rect: _rect,
                      scrim: Colors.black.withValues(
                        alpha: c.isDark ? .72 : .6,
                      ),
                      ring: c.accent.withValues(
                        alpha: .55 + .35 * _pulse.value,
                      ),
                      spread: 2 + 3 * _pulse.value,
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _move,
              builder: (_, child) {
                final r = _rect;
                final below = _to.center.dy < size.height * .55;
                const cardH = 190.0;
                var top = below ? r.bottom + 14 : r.top - 14 - cardH;
                top = top.clamp(
                  pad.top + 8,
                  size.height - pad.bottom - cardH - 8,
                );
                return Positioned(
                  left: Space.gutter,
                  right: Space.gutter,
                  top: top,
                  child: child!,
                );
              },
              child: AnimatedSwitcher(
                duration: _reduced ? Duration.zero : Motion.base,
                switchInCurve: Motion.curve,
                transitionBuilder: (w, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .04),
                      end: Offset.zero,
                    ).animate(a),
                    child: w,
                  ),
                ),
                child: Semantics(
                  key: ValueKey(_i),
                  liveRegion: true,
                  container: true,
                  child: Container(
                    key: const Key('coach_card'),
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: context.tt.titleMedium!.copyWith(color: fg),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          step.body,
                          style: context.tt.bodyMedium!.copyWith(
                            color: fg.withValues(alpha: .78),
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Row(
                          children: [
                            for (var k = 0; k < widget.steps.length; k++)
                              AnimatedContainer(
                                duration: Motion.base,
                                curve: Motion.curve,
                                margin: const EdgeInsets.only(right: 5),
                                width: k == _i ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: k == _i
                                      ? c.accent
                                      : fg.withValues(alpha: .25),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            const Spacer(),
                            if (!last)
                              Pressable(
                                key: const Key('coach_skip'),
                                onTap: _close,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.md,
                                    vertical: Space.md,
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: context.tt.labelLarge!.copyWith(
                                      color: fg.withValues(alpha: .6),
                                    ),
                                  ),
                                ),
                              ),
                            Pressable(
                              key: const Key('coach_next'),
                              onTap: () {
                                Haptics.tap();
                                last ? _close() : _go(_i + 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.lg,
                                  vertical: Space.md,
                                ),
                                decoration: BoxDecoration(
                                  color: c.accent,
                                  borderRadius: BorderRadius.circular(
                                    Radii.pill,
                                  ),
                                ),
                                child: Text(
                                  last ? 'Got it' : 'Next',
                                  style: context.tt.labelLarge!.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter({
    required this.rect,
    required this.scrim,
    required this.ring,
    required this.spread,
  });
  final Rect rect;
  final Color scrim;
  final Color ring;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    final r = rect.isEmpty
        ? null
        : RRect.fromRectAndRadius(
            rect,
            Radius.circular(
              rect.shortestSide < 40 ? rect.shortestSide / 2 : 18,
            ),
          );
    final path = Path()..addRect(Offset.zero & size);
    if (r != null) path.addRRect(r);
    canvas.drawPath(
      path..fillType = PathFillType.evenOdd,
      Paint()..color = scrim,
    );
    if (r != null) {
      canvas.drawRRect(
        r.inflate(spread),
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter o) =>
      o.rect != rect ||
      o.scrim != scrim ||
      o.ring != ring ||
      o.spread != spread;
}
