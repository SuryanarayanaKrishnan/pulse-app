import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../engine/card_art.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

const _w = 340.0;
const _h = _w / 1.586;

/// A detailed card face drawn entirely in code from a [CardArtSpec]:
/// gradient, finish (brushed metal highlight, gloss sheen, or matte), a motif,
/// an EMV chip, the contactless mark, a vector network mark, the bank name,
/// tier, and an embossed number.
///
/// The face is laid out on a fixed 340 x 214 canvas and scaled to fit, so it
/// never overflows at any size. It ignores system text scaling on purpose:
/// it is a picture of a physical card.
class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.art,
    this.last4,
    this.name,
    this.compact = false,
    this.elevated = false,
  });
  final CardArtSpec art;

  /// Last four digits; null shows a fully masked number.
  final String? last4;

  /// Product name under the bank name.
  final String? name;

  /// Thumbnail: art only, no text.
  final bool compact;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final base = context.tt.bodyMedium!;
    final radius = BorderRadius.circular(compact ? 22 : 18);
    final face = SizedBox(
      width: _w,
      height: _h,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _FacePainter(art)),
            if (!compact)
              _Content(art: art, last4: last4, name: name, base: base),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: 1.586,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 3 : 14),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.noScaling),
          child: FittedBox(fit: BoxFit.fill, child: face),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.art,
    required this.last4,
    required this.name,
    required this.base,
  });
  final CardArtSpec art;
  final String? last4;
  final String? name;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    final fg = Color(art.text);
    final accent = Color(art.accent);
    final digits = last4 == null || last4!.isEmpty ? '••••' : last4!;
    final emboss = PulseTheme.amount(
      fg,
      size: 19,
      weight: FontWeight.w600,
    ).copyWith(letterSpacing: 2.2, height: 1);
    Widget number(Color c, Offset o) => Transform.translate(
      offset: o,
      child: Text(
        '••••  ••••  ••••  $digits',
        style: emboss.copyWith(color: c),
        maxLines: 1,
      ),
    );
    final light = fg.computeLuminance() < 0.4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Stack(
        children: [
          // Bank wordmark and product, top left.
          Positioned(
            left: 0,
            top: 0,
            right: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  art.bank,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.1,
                  ),
                ),
                if (name != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        color: fg.withValues(alpha: 0.78),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (art.contactless)
            Positioned(
              right: 0,
              top: 0,
              child: CustomPaint(
                size: const Size(22, 22),
                painter: _ContactlessPainter(fg.withValues(alpha: 0.85)),
              ),
            ),
          // EMV chip.
          Positioned(
            left: 0,
            top: 66,
            child: CustomPaint(
              size: const Size(46, 35),
              painter: _ChipPainter(art.chip),
            ),
          ),
          // Embossed number: a highlight below and a shadow above give relief.
          Positioned(
            left: 0,
            right: 0,
            top: 118,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  number(
                    (light ? Colors.white : Colors.black).withValues(
                      alpha: 0.28,
                    ),
                    const Offset(0.8, 0.9),
                  ),
                  number(
                    (light ? Colors.black : Colors.white).withValues(
                      alpha: 0.22,
                    ),
                    const Offset(-0.5, -0.6),
                  ),
                  number(fg, Offset.zero),
                ],
              ),
            ),
          ),
          // Tier, bottom left.
          if (art.tier.isNotEmpty)
            Positioned(
              left: 0,
              bottom: 2,
              right: 100,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      art.tier.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        color: fg.withValues(alpha: 0.92),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: NetworkMark(art.network, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Vector network marks. Visa is set as a heavy italic wordmark, Mastercard
/// as two overlapping discs, Amex as a blue tile.
class NetworkMark extends StatelessWidget {
  const NetworkMark(this.network, {super.key, required this.color});
  final CardNetworkMark network;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (network) {
      case CardNetworkMark.visa:
        return Text(
          'VISA',
          style: TextStyle(
            fontFamily: context.tt.bodyMedium!.fontFamily,
            color: color,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.6,
            height: 1,
          ),
        );
      case CardNetworkMark.mastercard:
        return CustomPaint(size: const Size(46, 28), painter: _McPainter());
      case CardNetworkMark.amex:
        return Container(
          width: 44,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF006FCF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'AMEX',
            style: TextStyle(
              fontFamily: context.tt.bodyMedium!.fontFamily,
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              height: 1,
            ),
          ),
        );
    }
  }
}

class _McPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final a = Offset(r, r);
    final b = Offset(size.width - r, r);
    canvas.drawCircle(a, r, Paint()..color = const Color(0xFFEB001B));
    canvas.drawCircle(b, r, Paint()..color = const Color(0xFFF79E1B));
    final overlap = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCircle(center: a, radius: r)),
      Path()..addOval(Rect.fromCircle(center: b, radius: r)),
    );
    canvas.drawPath(overlap, Paint()..color = const Color(0xFFFF5F00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ContactlessPainter extends CustomPainter {
  _ContactlessPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width * 0.12, size.height / 2);
    for (var i = 1; i <= 4; i++) {
      final r = size.height * 0.16 * i + 1;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -0.9,
        1.8,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ContactlessPainter old) => old.color != color;
}

class _ChipPainter extends CustomPainter {
  _ChipPainter(this.style);
  final ChipStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final (hi, lo, line) = switch (style) {
      ChipStyle.gold => (
        const Color(0xFFF1D58A),
        const Color(0xFFC09A3E),
        const Color(0xFF8A6A1F),
      ),
      ChipStyle.silver => (
        const Color(0xFFEDEFF2),
        const Color(0xFFA9AFB8),
        const Color(0xFF6E7580),
      ),
      ChipStyle.dark => (
        const Color(0xFF4A4A4A),
        const Color(0xFF222222),
        const Color(0xFF000000),
      ),
    };
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hi, lo],
        ).createShader(rect),
    );
    final l = Paint()
      ..color = line.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(rr.deflate(0.5), l);
    final w = size.width;
    final h = size.height;
    // Contact pads: a centre plate and the lines that separate it.
    canvas.drawLine(Offset(0, h * 0.33), Offset(w * 0.34, h * 0.33), l);
    canvas.drawLine(Offset(0, h * 0.67), Offset(w * 0.34, h * 0.67), l);
    canvas.drawLine(Offset(w, h * 0.33), Offset(w * 0.66, h * 0.33), l);
    canvas.drawLine(Offset(w, h * 0.67), Offset(w * 0.66, h * 0.67), l);
    canvas.drawLine(Offset(w * 0.34, h * 0.33), Offset(w * 0.34, h * 0.67), l);
    canvas.drawLine(Offset(w * 0.66, h * 0.33), Offset(w * 0.66, h * 0.67), l);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h * 0.33), l);
    canvas.drawLine(Offset(w * 0.5, h * 0.67), Offset(w * 0.5, h), l);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, h * 0.33, w * 0.32, h * 0.34),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _ChipPainter old) => old.style != style;
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.art);
  final CardArtSpec art;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stops = [for (final s in art.stops) Color(s)];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: stops.length == 1 ? [stops.first, stops.first] : stops,
        ).createShader(rect),
    );
    _motif(canvas, size);
    switch (art.finish) {
      case CardFinish.metal:
        _metal(canvas, size);
      case CardFinish.gloss:
        _gloss(canvas, size);
      case CardFinish.matte:
        _matte(canvas, size);
    }
  }

  void _motif(Canvas canvas, Size size) {
    final accent = Color(art.accent);
    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()..color = accent.withValues(alpha: 0.10);
    switch (art.motif) {
      case CardMotif.none:
        break;
      case CardMotif.waves:
        for (var i = 0; i < 6; i++) {
          final y = size.height * (0.52 + i * 0.1);
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 8) {
            path.lineTo(
              x,
              y + math.sin(x / size.width * math.pi * 2 + i * 0.6) * 12,
            );
          }
          canvas.drawPath(path, stroke);
        }
      case CardMotif.lines:
        for (var x = -size.height; x < size.width; x += 16) {
          canvas.drawLine(
            Offset(x, size.height),
            Offset(x + size.height, 0),
            stroke..strokeWidth = 0.8,
          );
        }
      case CardMotif.dots:
        for (var y = 14.0; y < size.height; y += 18) {
          for (
            var x = (y ~/ 18).isEven ? 14.0 : 23.0;
            x < size.width;
            x += 18
          ) {
            if (x > size.width * 0.45 || y > size.height * 0.55) {
              canvas.drawCircle(Offset(x, y), 1.6, fill);
            }
          }
        }
      case CardMotif.arcs:
        final c = Offset(size.width * 0.92, size.height * 1.05);
        for (var i = 1; i <= 6; i++) {
          canvas.drawCircle(c, 34.0 * i, stroke);
        }
      case CardMotif.grid:
        for (var x = 0.0; x < size.width; x += 28) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x, size.height),
            stroke..strokeWidth = 0.6,
          );
        }
        for (var y = 0.0; y < size.height; y += 28) {
          canvas.drawLine(
            Offset(0, y),
            Offset(size.width, y),
            stroke..strokeWidth = 0.6,
          );
        }
    }
  }

  void _metal(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Brushed grain: fine horizontal hairlines of varying strength.
    final rnd = math.Random(7);
    final grain = Paint()..strokeWidth = 0.6;
    for (var y = 0.0; y < size.height; y += 1.5) {
      final v = rnd.nextDouble();
      grain.color = (v > 0.5 ? Colors.white : Colors.black).withValues(
        alpha: 0.025 + v * 0.03,
      );
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grain);
    }
    // A soft diagonal highlight band, as light rolling across brushed metal.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -0.6),
          end: const Alignment(1, 0.6),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.25, 0.42, 0.62],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18),
          ],
        ).createShader(rect),
    );
  }

  void _gloss(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.8, -1.1),
          radius: 1.1,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.16)],
          stops: const [0.5, 1],
        ).createShader(rect),
    );
  }

  void _matte(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.12)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => old.art != art;
}

/// A plain art direction derived from a card's own gradient, for products
/// without bundled art.
CardArtSpec fallbackArt({
  required List<Color> gradient,
  required CardNetworkMark network,
  required String bank,
  String tier = '',
}) => CardArtSpec(
  stops: [for (final c in gradient) c.toARGB32()],
  network: network,
  bank: bank,
  tier: tier,
  accent: 0xFFFFFFFF,
);
