import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';

/// Length of one loop. Every tour moment is five seconds or less.
const kMomentLoop = Duration(milliseconds: 4800);

/// Where in the loop the picture is complete and holding. Used as the still
/// frame when the system asks for reduced motion.
const kSettled = 0.86;

/// Eased progress of [t] between [a] and [b], clamped to 0..1.
double seg(double t, double a, double b, [Curve curve = Curves.easeOutCubic]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// Fade in at the start of the loop, out at the end, so the loop never jumps.
double stageAlpha(double t) =>
    seg(t, 0, .05, Curves.linear) * (1 - seg(t, .92, .99, Curves.linear));

/// Runs [builder] with a looping 0..1 value, or holds the settled frame when
/// the platform asks for reduced motion.
class LoopingMoment extends StatefulWidget {
  const LoopingMoment({super.key, required this.builder});
  final Widget Function(BuildContext context, double t) builder;
  @override
  State<LoopingMoment> createState() => _LoopingMomentState();
}

class _LoopingMomentState extends State<LoopingMoment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: kMomentLoop,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _ctl.stop();
    } else if (!_ctl.isAnimating) {
      _ctl.repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctl,
    builder: (context, _) {
      final t = _reduced ? kSettled : _ctl.value;
      return Opacity(
        opacity: _reduced ? 1 : stageAlpha(t),
        child: widget.builder(context, t),
      );
    },
  );
}

/// Fade and a short rise.
class _Appear extends StatelessWidget {
  const _Appear(this.p, {required this.child, this.dy = 10, this.dx = 0});
  final double p;
  final double dy;
  final double dx;
  final Widget child;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: p.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(dx * (1 - p), dy * (1 - p)),
      child: child,
    ),
  );
}

/// The 300 x 300 stage every moment is drawn on. Scales down on small phones.
class _Stage extends StatelessWidget {
  const _Stage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => MediaQuery(
    // A picture, not text to read: it keeps its proportions at any text size.
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(width: 300, height: 320, child: child),
    ),
  );
}

BoxDecoration _panel(PulseColors c) => BoxDecoration(
  color: c.surface,
  borderRadius: BorderRadius.circular(Radii.lg),
  border: Border.all(color: c.border, width: 0.5),
);

String _n(num v) => Money.number(v);

// ---------------------------------------------------------------------------
// (a) Safe to spend today
// ---------------------------------------------------------------------------

/// Hero number settling as bills, card dues and goals come off.
class SafeToSpendMoment extends StatelessWidget {
  const SafeToSpendMoment({super.key, required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final p1 = seg(t, .08, .22);
    final p2 = seg(t, .24, .38);
    final p3 = seg(t, .40, .54);
    final pd = seg(t, .58, .74);
    final afterTake = 7240 - 2800 * p1 - 1150 * p2 - 500 * p3;
    final value = pd > 0 ? afterTake + (199 - 2790) * pd : afterTake;
    final color = Color.lerp(c.textPrimary, c.accent, pd)!;

    Widget row(String label, String amount, double p) => _Appear(
      p,
      dx: -10,
      dy: 0,
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(label, style: context.tt.bodyMedium)),
            Text(amount, style: PulseTheme.amount(c.textSecondary, size: 15)),
          ],
        ),
      ),
    );

    return _Stage(
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: _panel(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Safe to spend today', style: context.tt.bodyMedium),
            const SizedBox(height: Space.xs),
            Text(
              'AED ${_n(value.round())}',
              style: PulseTheme.amount(
                color,
                size: 44,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: 20,
              child: _Appear(
                pd,
                dy: 4,
                child: Text(
                  'AED 2,790 free · 14 days left',
                  style: context.tt.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Container(height: 0.5, color: c.border),
            const SizedBox(height: Space.xs),
            row('Bills', '−2,800', p1),
            row('Card dues', '−1,150', p2),
            row('Goals', '−500', p3),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// (b) The right-card alert
// ---------------------------------------------------------------------------

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.name,
    required this.tint,
    required this.last4,
  });
  final String name;
  final Color tint;
  final String last4;
  @override
  Widget build(BuildContext context) => Container(
    width: 208,
    height: 124,
    padding: const EdgeInsets.all(Space.lg),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Radii.lg - 4),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint, Color.lerp(tint, Colors.black, .35)!],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.contactless_outlined,
              size: 20,
              color: Colors.white.withValues(alpha: .85),
            ),
          ],
        ),
        const Spacer(),
        Text(name, style: context.tt.titleSmall!.copyWith(color: Colors.white)),
        Text(
          '•••• $last4',
          style: PulseTheme.amount(
            Colors.white.withValues(alpha: .75),
            size: 13,
            weight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// A tap at the till, a quiet alert, and the better card sliding in.
class RightCardMoment extends StatelessWidget {
  const RightCardMoment({super.key, required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final alert = seg(t, .06, .18);
    final money = seg(t, .22, .34);
    final swap = seg(t, .44, .62, Curves.easeInOutCubic);
    final tag = seg(t, .64, .76);
    // A single soft ring where the tap lands.
    final ring = seg(t, .02, .16, Curves.easeOut);
    return _Stage(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _Appear(
              alert,
              dy: -16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: Space.md,
                ),
                decoration: _panel(
                  c,
                ).copyWith(borderRadius: BorderRadius.circular(Radii.md + 2)),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: .14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.contactless_outlined,
                        size: 18,
                        color: c.accent,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supermarket · AED 186',
                            style: context.tt.titleSmall,
                          ),
                          Text(
                            'A better card was in your wallet',
                            style: context.tt.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 80,
            child: _Appear(
              money,
              child: Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: 'Earned',
                      value: '+AED 1.86',
                      color: c.positive,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: 'Missed',
                      value: 'AED 7.44',
                      color: c.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 46,
            top: 148 - 10 * ring,
            child: Opacity(
              opacity: 1 - swap,
              child: Transform.translate(
                offset: Offset(-60 * swap, 26 * swap),
                child: Transform.scale(
                  scale: 1 - .06 * swap,
                  child: const _MiniCard(
                    name: 'Everyday card',
                    tint: Color(0xFF6B7470),
                    last4: '4821',
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 46,
            top: 148 - 10 * ring,
            child: Opacity(
              opacity: swap,
              child: Transform.translate(
                offset: Offset(60 * (1 - swap), 0),
                child: _MiniCard(
                  name: 'Grocer Plus',
                  tint: c.accent,
                  last4: '9307',
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: _Appear(
                tag,
                dy: 6,
                child: Text(
                  'Next time: earn AED 9.30',
                  style: context.tt.labelLarge!.copyWith(color: c.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: context.tt.bodySmall),
      const SizedBox(height: 2),
      Text(value, style: PulseTheme.amount(color, size: 22)),
    ],
  );
}

// ---------------------------------------------------------------------------
// (c) Auto-capture
// ---------------------------------------------------------------------------

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.t,
    required this.line,
    required this.dot,
    required this.sources,
    required this.target,
  });
  final double t;
  final Color line;
  final Color dot;
  final List<Offset> sources;
  final Offset target;

  Path _path(Offset from, Offset to) {
    final mid = (from.dy + to.dy) / 2;
    return Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, mid, to.dx, mid, to.dx, to.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < sources.length; i++) {
      final path = _path(sources[i], target + Offset((i - 1) * 40.0, 0));
      canvas.drawPath(path, linePaint);
      final metric = path.computeMetrics().first;
      // Two small dots per source, each making one trip down the line.
      for (var k = 0; k < 2; k++) {
        final start = .12 + i * .13 + k * .22;
        final q = seg(t, start, start + .2, Curves.easeInOut);
        if (q <= 0 || q >= 1) continue;
        final pos = metric.getTangentForOffset(metric.length * q)!.position;
        final a = math.sin(q * math.pi);
        canvas.drawCircle(pos, 3.5, Paint()..color = dot.withValues(alpha: a));
      }
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) => old.t != t || old.dot != dot;
}

/// Bank texts, wallet taps and statements flowing into the ledger.
class AutoCaptureMoment extends StatelessWidget {
  const AutoCaptureMoment({super.key, required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget source(IconData icon, String label, double p) => _Appear(
      p,
      dy: -8,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: c.accent),
          ),
          const SizedBox(height: Space.xs),
          Text(label, style: context.tt.bodySmall),
        ],
      ),
    );

    Widget entry(
      IconData icon,
      String name,
      String sub,
      String amt,
      double p, {
      Color? amtColor,
    }) {
      return _Appear(
        p,
        dy: 8,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.textTertiary),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.tt.titleSmall, maxLines: 1),
                    Text(
                      sub,
                      style: context.tt.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                amt,
                style: PulseTheme.amount(amtColor ?? c.textPrimary, size: 15),
              ),
            ],
          ),
        ),
      );
    }

    return _Stage(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FlowPainter(
                t: t,
                line: c.border,
                dot: c.accent,
                sources: const [
                  Offset(50, 84),
                  Offset(150, 84),
                  Offset(250, 84),
                ],
                target: const Offset(150, 130),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                source(Icons.sms_outlined, 'Bank SMS', seg(t, .02, .1)),
                source(Icons.contactless_outlined, 'Wallet', seg(t, .06, .14)),
                source(
                  Icons.description_outlined,
                  'Statement',
                  seg(t, .10, .18),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.sm,
              ),
              decoration: _panel(c),
              child: Column(
                children: [
                  entry(
                    Icons.shopping_basket_outlined,
                    'Supermarket',
                    'Groceries · from SMS',
                    '−186',
                    seg(t, .30, .42),
                  ),
                  entry(
                    Icons.local_cafe_outlined,
                    'Coffee',
                    'Dining · from wallet',
                    '−18',
                    seg(t, .45, .57),
                  ),
                  entry(
                    Icons.payments_outlined,
                    'Salary',
                    'Income · from statement',
                    '+14,000',
                    seg(t, .60, .72),
                    amtColor: c.positive,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// (d) Net worth
// ---------------------------------------------------------------------------

/// Assets, gold and funds ticking into one number.
class NetWorthMoment extends StatelessWidget {
  const NetWorthMoment({super.key, required this.t});
  final double t;

  static const _parts = [
    (Icons.account_balance_wallet_outlined, 'Cash', 84200, .08),
    (Icons.diamond_outlined, 'Gold', 38600, .22),
    (Icons.pie_chart_outline_rounded, 'Funds', 126500, .36),
    (Icons.home_work_outlined, 'Property', 233000, .50),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    var total = 0.0;
    final tiles = <Widget>[];
    for (final (icon, name, amount, start) in _parts) {
      final appear = seg(t, start, start + .10);
      final tick = seg(t, start + .04, start + .18);
      total += amount * tick;
      // The tile's border warms to the accent while its value is landing.
      final glow = math.sin(tick * math.pi);
      tiles.add(
        _Appear(
          appear,
          dy: 12,
          child: Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: Color.lerp(c.border, c.accent, glow)!,
                width: 0.5 + glow * .5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: c.textSecondary),
                    const SizedBox(width: Space.sm),
                    Flexible(
                      child: Text(
                        name,
                        style: context.tt.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _n(amount),
                    style: PulseTheme.amount(c.textPrimary, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final done = seg(t, .70, .80);
    return _Stage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net worth', style: context.tt.bodyMedium),
          const SizedBox(height: Space.xs),
          Text(
            'AED ${_n(total.round())}',
            style: PulseTheme.amount(
              Color.lerp(c.textPrimary, c.accent, done)!,
              size: 40,
              weight: FontWeight.w700,
            ),
          ),
          SizedBox(
            height: 24,
            child: _Appear(
              done,
              dy: 4,
              child: Text(
                '+2.4% this month',
                style: context.tt.bodyMedium!.copyWith(color: c.positive),
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: Space.md,
              crossAxisSpacing: Space.md,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: tiles,
            ),
          ),
        ],
      ),
    );
  }
}
