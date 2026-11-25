import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PointMode;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../engine/card_art.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'card_tilt.dart';

const _w = 340.0;
const _h = _w / 1.586; // ISO/IEC 7810 ID-1: 85.60 x 53.98 mm.
const _r = 14.0; // 3.18 mm corner radius, a touch generous like Wallet.

/// A realistic card face drawn entirely in code from a [CardArtSpec].
///
/// Layers, bottom to top: the material (brushed metal grain and banding,
/// pearlised clear-coat, soft-touch noise or black gloss), a motif, the
/// printed and embossed content (EMV chip, contactless, number, name,
/// valid-thru, tier, network mark), a moving specular highlight and
/// hologram that follow device tilt, and a bevelled edge.
///
/// Everything except the highlight sits in one [RepaintBoundary], so the
/// heavy painting is rasterised once; the highlight is a single gradient
/// fill that repaints from a listenable without rebuilding anything. No
/// per-frame shader loops, so a stack of faces stays smooth.
///
/// The face is laid out on a fixed 340 x 214 canvas and scaled to fit, so
/// it never overflows at any size, and ignores system text scaling on
/// purpose: it is a picture of a physical card.
class CardFace extends StatefulWidget {
  const CardFace({
    super.key,
    required this.art,
    this.last4,
    this.name,
    this.holder,
    this.expiry,
    this.compact = false,
    this.elevated = false,
    this.tilt,
  });
  final CardArtSpec art;

  /// Last four digits; null shows a fully masked number.
  final String? last4;

  /// Product name under the bank name.
  final String? name;

  /// Cardholder name as embossed; a generic placeholder when null.
  final String? holder;

  /// `MM/YY`; masked when null.
  final String? expiry;

  /// Thumbnail: art only, no text, no motion.
  final bool compact;
  final bool elevated;

  /// Override for the highlight position (e.g. a pager offset). Defaults to
  /// device tilt, and to a still pose under tests or reduced motion.
  final ValueListenable<Offset>? tilt;

  @override
  State<CardFace> createState() => _CardFaceState();
}

class _CardFaceState extends State<CardFace> {
  bool _attached = false;

  bool get _live => !widget.compact && widget.tilt == null;

  void _sync(bool reduce) {
    final want = _live && !reduce;
    if (want == _attached) return;
    _attached = want;
    want ? CardTilt.instance.attach() : CardTilt.instance.detach();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  @override
  void didUpdateWidget(CardFace old) {
    super.didUpdateWidget(old);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_attached && !_live) {
      _attached = false;
      CardTilt.instance.detach();
    }
    _sync(reduce);
  }

  @override
  void dispose() {
    if (_attached) CardTilt.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.art;
    final compact = widget.compact;
    final base = context.tt.bodyMedium!;
    final radius = BorderRadius.circular(compact ? 22 : _r);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tilt = reduce
        ? ValueNotifier(CardTilt.rest)
        : (widget.tilt ?? CardTilt.instance.value);
    final face = SizedBox(
      width: _w,
      height: _h,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Heavy, static: painted once and cached by the boundary.
            RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _FacePainter(art, compact ? 22 : _r)),
                  if (!compact)
                    _Content(
                      art: art,
                      last4: widget.last4,
                      name: widget.name,
                      holder: widget.holder,
                      expiry: widget.expiry,
                      base: base,
                    ),
                ],
              ),
            ),
            if (!compact)
              IgnorePointer(
                child: CustomPaint(painter: _SpecularPainter(art, tilt, _r)),
              ),
            CustomPaint(painter: _EdgePainter(compact ? 22 : _r)),
          ],
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: 1.586,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 3 : _r),
          boxShadow: widget.elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: -2,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5),
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

// ---------------------------------------------------------------- content

class _Content extends StatelessWidget {
  const _Content({
    required this.art,
    required this.last4,
    required this.name,
    required this.holder,
    required this.expiry,
    required this.base,
  });
  final CardArtSpec art;
  final String? last4;
  final String? name;
  final String? holder;
  final String? expiry;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    final fg = Color(art.text);
    final lightText = fg.computeLuminance() > 0.4;
    final k = art.emboss;
    final digits = last4 == null || last4!.isEmpty ? '••••' : last4!;

    // Raised (embossed) lettering: light from the top left, so a highlight
    // on the upper-left edge and a soft shadow lower right.
    Widget raised(String text, TextStyle style, {double blur = 0.6}) {
      final shade = (lightText ? Colors.black : const Color(0xFF3A3A3A))
          .withValues(alpha: (lightText ? 0.55 : 0.32) * k);
      final hi = (lightText ? Colors.white : Colors.white).withValues(
        alpha: (lightText ? 0.28 : 0.55) * k,
      );
      Widget t(Color c, Offset o, {double b = 0}) => Transform.translate(
        offset: o,
        child: b == 0
            ? Text(text, style: style.copyWith(color: c), maxLines: 1)
            : ImageFiltered(
                imageFilter: _blur(b),
                child: Text(text, style: style.copyWith(color: c), maxLines: 1),
              ),
      );
      return Stack(
        children: [
          t(shade, const Offset(0.7, 1.0), b: blur),
          t(hi, const Offset(-0.55, -0.7)),
          Text(
            text,
            maxLines: 1,
            style: style.copyWith(
              foreground: Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(fg, Colors.white, lightText ? 0.18 : 0.0)!,
                    Color.lerp(fg, Colors.black, lightText ? 0.12 : 0.18)!,
                  ],
                ).createShader(const Rect.fromLTWH(0, 0, 300, 24)),
            ),
          ),
        ],
      );
    }

    final numStyle = PulseTheme.amount(
      fg,
      size: 19.5,
      weight: FontWeight.w600,
    ).copyWith(letterSpacing: 2.4, height: 1, color: null);
    final smallCaps = base.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.0,
      height: 1,
    );
    final dim = fg.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 19, 22, 17),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bank wordmark and product, top left.
          Positioned(
            left: 0,
            top: 0,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  art.bank,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(
                    color: fg,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: (lightText ? Colors.black : Colors.white)
                            .withValues(alpha: 0.28 * k),
                        offset: const Offset(0, 0.8),
                        blurRadius: 0.4,
                      ),
                    ],
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
                        color: dim,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Tier, top right, small.
          if (art.tier.isNotEmpty)
            Positioned(
              right: 0,
              top: 2,
              width: 94,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  art.tier.toUpperCase(),
                  maxLines: 1,
                  style: smallCaps.copyWith(
                    color: Color.lerp(fg, Color(art.accent), 0.45),
                    fontSize: 8.5,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          // EMV chip with the contactless symbol beside it.
          Positioned(
            left: 0,
            top: 56,
            child: CustomPaint(
              size: const Size(46, 35),
              painter: _ChipPainter(art.chip),
            ),
          ),
          if (art.contactless)
            Positioned(
              left: 60,
              top: 58,
              child: CustomPaint(
                size: const Size(26, 30),
                painter: _ContactlessPainter(fg.withValues(alpha: 0.88)),
              ),
            ),
          // Number.
          Positioned(
            left: 0,
            right: 0,
            top: 104,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: raised('••••  ••••  ••••  $digits', numStyle),
            ),
          ),
          // Valid thru and cardholder, bottom left.
          Positioned(
            left: 0,
            bottom: 0,
            right: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'VALID\nTHRU',
                      style: base.copyWith(
                        color: dim,
                        fontSize: 5.5,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    raised(
                      expiry ?? '••/••',
                      smallCaps.copyWith(fontSize: 11.5, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                raised(
                  (holder ?? 'CARDHOLDER').toUpperCase(),
                  smallCaps.copyWith(
                    fontSize: 11.5,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: -2,
            child: NetworkMark(art.network, color: fg),
          ),
        ],
      ),
    );
  }
}

ImageFilter _blur(double s) => ImageFilter.blur(sigmaX: s, sigmaY: s);

// ---------------------------------------------------------- network marks

/// Vector network marks drawn in code (no issuer or network artwork): Visa as
/// a heavy italic wordmark, Mastercard as the two overlapped discs in their
/// brand colours, American Express as the blue tile with its two-line name.
class NetworkMark extends StatelessWidget {
  const NetworkMark(this.network, {super.key, required this.color});
  final CardNetworkMark network;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (network) {
      case CardNetworkMark.visa:
        final style = TextStyle(
          fontFamily: context.tt.bodyMedium!.fontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: -1.0,
          height: 1,
        );
        return Transform(
          transform: Matrix4.skewX(-0.12),
          alignment: Alignment.bottomRight,
          child: Stack(
            children: [
              // A thin outline thickens the strokes toward the real mark.
              Text(
                'VISA',
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.1
                    ..color = color,
                ),
              ),
              Text('VISA', style: style.copyWith(color: color)),
            ],
          ),
        );
      case CardNetworkMark.mastercard:
        return CustomPaint(size: const Size(50, 31), painter: _McPainter());
      case CardNetworkMark.amex:
        return CustomPaint(
          size: const Size(36, 36),
          painter: _AmexPainter(context.tt.bodyMedium!.fontFamily),
        );
    }
  }
}

class _McPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Two discs of equal diameter overlapping by about 38 percent.
    final d = size.height;
    final r = d / 2;
    final a = Offset(r, r);
    final b = Offset(size.width - r, r);
    Paint disc(Color c, Offset o) => Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [Color.lerp(c, Colors.white, 0.16)!, c],
      ).createShader(Rect.fromCircle(center: o, radius: r));
    canvas.drawCircle(a, r, disc(const Color(0xFFEB001B), a));
    canvas.drawCircle(b, r, disc(const Color(0xFFF79E1B), b));
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

class _AmexPainter extends CustomPainter {
  _AmexPainter(this.family);
  final String? family;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3.5),
    );
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF016FD0));
    canvas.drawRRect(
      rr.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    void line(String t, double y) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: family,
            color: Colors.white,
            fontSize: 6.2,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, y));
    }

    line('AMERICAN', size.height / 2 - 7.5);
    line('EXPRESS', size.height / 2 + 0.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// -------------------------------------------------------- chip, contactless

class _ContactlessPainter extends CustomPainter {
  _ContactlessPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    // Four waves opening to the right, from a common point, as the symbol.
    final c = Offset(size.width * 0.02, size.height / 2);
    for (var i = 1; i <= 4; i++) {
      final r = 4.2 * i + 0.5;
      final sweep = 0.62 + i * 0.1;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -sweep,
        sweep * 2,
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
    final (c0, c1, c2, c3, line) = switch (style) {
      ChipStyle.gold => (
        const Color(0xFFF6E3A1),
        const Color(0xFFD9B55B),
        const Color(0xFFB88C2E),
        const Color(0xFFEBCB77),
        const Color(0xFF7A5A14),
      ),
      ChipStyle.silver => (
        const Color(0xFFF4F6F8),
        const Color(0xFFC3C8CF),
        const Color(0xFF8F96A0),
        const Color(0xFFDDE1E6),
        const Color(0xFF5B626C),
      ),
      ChipStyle.dark => (
        const Color(0xFF5A5A5E),
        const Color(0xFF38383B),
        const Color(0xFF1E1E20),
        const Color(0xFF47474A),
        const Color(0xFF000000),
      ),
    };
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6.5));
    // Metallic body: diagonal gradient with a bright mid band.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c0, c1, c3, c2, c1],
          stops: const [0, 0.28, 0.5, 0.78, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(rr);
    final cut = Paint()
      ..color = line.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;
    final glint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    // C1..C8 contact layout: a centre plate with side pads separated by
    // etched channels. Drawn twice, dark then a 0.7px highlight, to read as
    // etched into the plate.
    final top = h * 0.30, bot = h * 0.70;
    final l = w * 0.31, r = w * 0.69;
    Path channels() {
      final path = Path()
        // Left and right channels reaching the plate.
        ..moveTo(0, top)
        ..lineTo(l - 3, top)
        ..quadraticBezierTo(l, top, l, top + 3)
        ..lineTo(l, bot - 3)
        ..quadraticBezierTo(l, bot, l - 3, bot)
        ..lineTo(0, bot)
        ..moveTo(w, top)
        ..lineTo(r + 3, top)
        ..quadraticBezierTo(r, top, r, top + 3)
        ..lineTo(r, bot - 3)
        ..quadraticBezierTo(r, bot, r + 3, bot)
        ..lineTo(w, bot)
        // Vertical separators above and below the plate.
        ..moveTo(w * 0.5, 0)
        ..lineTo(w * 0.5, top)
        ..moveTo(w * 0.5, bot)
        ..lineTo(w * 0.5, h)
        // Mid-height splits on the side pads.
        ..moveTo(0, h * 0.5)
        ..lineTo(l, h * 0.5)
        ..moveTo(w, h * 0.5)
        ..lineTo(r, h * 0.5);
      return path;
    }

    final p = channels();
    canvas.drawPath(p.shift(const Offset(0.6, 0.7)), glint);
    canvas.drawPath(p, cut);
    // The centre plate, slightly brighter with a soft inner shade.
    final plate = RRect.fromRectAndRadius(
      Rect.fromLTRB(l + 0.5, top + 0.5, r - 0.5, bot - 0.5),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(plate.outerRect),
    );
    canvas.restore();
    // Bevel: bright top-left edge, darker bottom-right.
    canvas.drawRRect(
      rr.deflate(0.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.7),
            line.withValues(alpha: 0.75),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _ChipPainter old) => old.style != style;
}

// ------------------------------------------------------------ material

class _FacePainter extends CustomPainter {
  _FacePainter(this.art, this.radius);
  final CardArtSpec art;
  final double radius;

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
    switch (art.resolvedMaterial) {
      case CardMaterial.brushed:
        _brushed(canvas, size);
      case CardMaterial.pearl:
        _pearl(canvas, size, deep: false);
      case CardMaterial.blackGloss:
        _pearl(canvas, size, deep: true);
      case CardMaterial.softTouch:
        _softTouch(canvas, size);
      case CardMaterial.auto:
        break;
    }
  }

  void _motif(Canvas canvas, Size size) {
    final accent = Color(art.accent);
    final metal = art.resolvedMaterial == CardMaterial.brushed;
    // Printed motifs sit under the clear coat; on metal they are etched, so a
    // hairline highlight rides beside each stroke.
    final stroke = Paint()
      ..color = accent.withValues(alpha: metal ? 0.20 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final etch = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final fill = Paint()..color = accent.withValues(alpha: 0.10);
    void draw(Path p) {
      canvas.drawPath(p, stroke);
      if (metal) canvas.drawPath(p.shift(const Offset(0.7, 0.8)), etch);
    }

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
          draw(path);
        }
      case CardMotif.lines:
        for (var x = -size.height; x < size.width; x += 16) {
          draw(
            Path()
              ..moveTo(x, size.height)
              ..lineTo(x + size.height, 0),
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
          draw(Path()..addOval(Rect.fromCircle(center: c, radius: 34.0 * i)));
        }
      case CardMotif.grid:
        for (var x = 0.0; x < size.width; x += 28) {
          draw(
            Path()
              ..moveTo(x, 0)
              ..lineTo(x, size.height),
          );
        }
        for (var y = 0.0; y < size.height; y += 28) {
          draw(
            Path()
              ..moveTo(0, y)
              ..lineTo(size.width, y),
          );
        }
    }
  }

  /// Brushed or turned metal: a banded sheen (metal reflects a few distinct
  /// bands, not a smooth ramp), fine horizontal grain made of many short
  /// hairlines, and a darker lower edge.
  void _brushed(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -0.5),
          end: const Alignment(1, 0.5),
          colors: [
            Colors.white.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.13),
            Colors.black.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.07),
            Colors.black.withValues(alpha: 0.16),
          ],
          stops: const [0, 0.22, 0.44, 0.62, 0.8, 1],
        ).createShader(rect),
    );
    final rnd = math.Random(11);
    final g = art.grain;
    final p = Paint()
      ..strokeWidth = 0.45
      ..strokeCap = StrokeCap.butt;
    final n = (900 * (0.4 + g)).round();
    for (var i = 0; i < n; i++) {
      final y = rnd.nextDouble() * size.height;
      final len = 30 + rnd.nextDouble() * 150;
      final x = rnd.nextDouble() * (size.width + 60) - 60;
      final bright = rnd.nextBool();
      p.color = (bright ? Colors.white : Colors.black).withValues(
        alpha: (0.03 + rnd.nextDouble() * 0.07) * (0.5 + g),
      );
      canvas.drawLine(Offset(x, y), Offset(x + len, y), p);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.22),
          ],
        ).createShader(rect),
    );
  }

  /// Pearlised or black gloss with a clear coat: a broad soft glow at the
  /// upper left, a crisp diagonal reflection edge, and a shaded bottom.
  void _pearl(Canvas canvas, Size size, {required bool deep}) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.75, -1.1),
          radius: 1.2,
          colors: [
            Colors.white.withValues(alpha: deep ? 0.16 : 0.26),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    // Clear-coat reflection: a large lighter polygon with a soft hard edge.
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.62, 0)
      ..lineTo(size.width * 0.18, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: deep ? 0.10 : 0.09),
            Colors.white.withValues(alpha: 0.015),
          ],
        ).createShader(rect),
    );
    canvas.drawLine(
      Offset(size.width * 0.62, 0),
      Offset(size.width * 0.18, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: deep ? 0.07 : 0.10)
        ..strokeWidth = 0.7,
    );
    if (!deep) {
      // Pearl: a faint cool-to-warm shift across the surface.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFF8FE6FF).withValues(alpha: 0.07),
              Colors.transparent,
              const Color(0xFFFFC9E6).withValues(alpha: 0.07),
            ],
          ).createShader(rect),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: deep ? 0.30 : 0.18),
          ],
          stops: const [0.45, 1],
        ).createShader(rect),
    );
  }

  /// Soft-touch laminate: no reflections, a fine stipple, and a gentle vignette.
  void _softTouch(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          radius: 1.1,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.black.withValues(alpha: 0.14),
          ],
        ).createShader(rect),
    );
    final rnd = math.Random(5);
    final n = (2600 * (0.3 + art.grain)).round();
    final p = Paint()
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      p.color = (rnd.nextBool() ? Colors.white : Colors.black).withValues(
        alpha: 0.02 + rnd.nextDouble() * 0.045,
      );
      canvas.drawPoints(PointMode.points, [
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
      ], p);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter old) => old.art != art;
}

// ---------------------------------------------------- specular (dynamic)

/// The only layer that moves: one or two gradient fills positioned from the
/// tilt, plus the hologram. Repaints from [tilt] without rebuilding.
class _SpecularPainter extends CustomPainter {
  _SpecularPainter(this.art, this.tilt, this.radius) : super(repaint: tilt);
  final CardArtSpec art;
  final ValueListenable<Offset> tilt;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tilt.value;
    final k = art.specular;
    final rect = Offset.zero & size;
    if (k > 0) {
      switch (art.resolvedMaterial) {
        case CardMaterial.brushed:
          // Anisotropic: a near-vertical streak perpendicular to the grain,
          // sliding sideways with tilt, with a narrower hot core.
          final c = 0.5 + t.dx * 0.55;
          canvas.drawRect(
            rect,
            Paint()
              ..shader = LinearGradient(
                begin: const Alignment(-1, -0.35),
                end: const Alignment(1, 0.35),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.30 * k),
                  Colors.white.withValues(alpha: 0.10 * k),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: [
                  (c - 0.26).clamp(0.0, 1.0),
                  c.clamp(0.0, 1.0),
                  (c + 0.1).clamp(0.0, 1.0),
                  (c + 0.34).clamp(0.0, 1.0),
                ],
              ).createShader(rect),
          );
        case CardMaterial.pearl:
        case CardMaterial.blackGloss:
          final deep = art.resolvedMaterial == CardMaterial.blackGloss;
          canvas.drawRect(
            rect,
            Paint()
              ..shader = RadialGradient(
                center: Alignment(t.dx * 1.1, -0.4 + t.dy * 0.9),
                radius: 0.85,
                colors: [
                  Colors.white.withValues(alpha: (deep ? 0.20 : 0.26) * k),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(rect),
          );
          // A sharp clear-coat streak that travels with the tilt.
          final x = size.width * (0.5 + t.dx * 0.5);
          canvas.drawPath(
            Path()
              ..moveTo(x - 20, 0)
              ..lineTo(x + 6, 0)
              ..lineTo(x - 54, size.height)
              ..lineTo(x - 80, size.height)
              ..close(),
            Paint()..color = Colors.white.withValues(alpha: 0.07 * k),
          );
        case CardMaterial.softTouch:
        case CardMaterial.auto:
          canvas.drawRect(
            rect,
            Paint()
              ..shader = RadialGradient(
                center: Alignment(t.dx, t.dy - 0.2),
                radius: 1.0,
                colors: [
                  Colors.white.withValues(alpha: 0.10 * k),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(rect),
          );
      }
    }
    if (art.hologram && art.resolvedMaterial != CardMaterial.brushed) {
      _hologram(canvas, size, t);
    }
  }

  void _hologram(Canvas canvas, Size size, Offset t) {
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 22 - 30, 19 + 58, 30, 22),
      const Radius.circular(4),
    );
    final s = (t.dx + 1) / 2;
    canvas.save();
    canvas.clipRRect(box);
    canvas.drawRRect(
      box,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + s, -1),
          end: Alignment(1 + s, 1),
          colors: const [
            Color(0xFFB9C7F2),
            Color(0xFFF2C9E6),
            Color(0xFFFFEBB0),
            Color(0xFFA8EEDB),
            Color(0xFFB9C7F2),
          ],
          stops: const [0, 0.25, 0.5, 0.75, 1],
          tileMode: TileMode.mirror,
        ).createShader(box.outerRect),
    );
    // A dove-like globe: two crossing arcs and a ring, in a translucent line.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final c = box.outerRect.center;
    canvas.drawCircle(c, 6.5, line);
    canvas.drawArc(
      Rect.fromCenter(center: c, width: 13, height: 6),
      0,
      math.pi * 2,
      false,
      line,
    );
    canvas.drawArc(
      Rect.fromCenter(center: c, width: 6, height: 13),
      0,
      math.pi * 2,
      false,
      line,
    );
    canvas.restore();
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _SpecularPainter old) =>
      old.art != art || old.tilt != tilt;
}

/// Bevelled edge: a bright rim at the top left fading to a dark rim at the
/// bottom right, as light catching a cut card edge.
class _EdgePainter extends CustomPainter {
  _EdgePainter(this.radius);
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rr.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.50),
            Colors.white.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.38),
          ],
          stops: const [0, 0.35, 0.7, 1],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rr.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => old.radius != radius;
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
