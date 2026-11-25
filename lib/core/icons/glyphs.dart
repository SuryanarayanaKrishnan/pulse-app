import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// The Pulse category icon family: stroke glyphs on one 24 unit grid.
///
/// Rules every glyph follows, so the set reads as one hand:
/// * live area about 3..21 inside the 24 box (never past 2.4..21.6), nothing touches the edge;
/// * one stroke weight ([strokeWidth]) with round caps and round joins;
/// * boxes use a 2.5 unit corner radius, small parts 1.5;
/// * one idea per glyph, no interior detail finer than a stroke.
///
/// Each glyph is a few [GlyphShape]s. A shape marked `fill` is the body that
/// takes the soft tint in the filled style.
const double glyphGrid = 24;
const double strokeWidth = 1.75;

class GlyphShape {
  const GlyphShape(this.path, {this.fill = false});
  final Path path;
  final bool fill;
}

class Glyph {
  const Glyph(this.key, this.label, this.shapes);
  final String key;
  final String label;
  final List<GlyphShape> shapes;
}

// ---- tiny path vocabulary ----------------------------------------------------

/// A polyline from a flat list of x,y pairs.
Path _pl(List<double> v, {bool close = false}) {
  final p = Path()..moveTo(v[0], v[1]);
  for (var i = 2; i < v.length; i += 2) {
    p.lineTo(v[i], v[i + 1]);
  }
  if (close) p.close();
  return p;
}

Path _rr(double l, double t, double r, double b, [double rad = 2.5]) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

Path _circle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

/// A zero length stroke: renders as one round dot.
Path _dot(double x, double y) => Path()
  ..moveTo(x, y)
  ..lineTo(x + 0.01, y);

/// An arc on a circle, angles in degrees (0 = right, 90 = down).
Path _arc(double cx, double cy, double r, double start, double sweep) {
  final p = Path();
  p.arcTo(
    Rect.fromCircle(center: Offset(cx, cy), radius: r),
    start * math.pi / 180,
    sweep * math.pi / 180,
    true,
  );
  return p;
}

Path _rot(Path p, double deg) {
  final a = deg * math.pi / 180, c = math.cos(a), sn = math.sin(a);
  const cx = 12.0, cy = 12.0;
  final m = Float64List.fromList([
    c, sn, 0, 0, //
    -sn, c, 0, 0,
    0, 0, 1, 0,
    cx - c * cx + sn * cy, cy - sn * cx - c * cy, 0, 1,
  ]);
  return p.transform(m);
}

Path _p(void Function(Path p) f) {
  final p = Path();
  f(p);
  return p;
}

GlyphShape _s(Path p) => GlyphShape(p);
GlyphShape _f(Path p) => GlyphShape(p, fill: true);

// ---- the glyphs ----------------------------------------------------------------

final _groceries = Glyph('groceries', 'Groceries', [
  _f(_p((p) => p
    ..moveTo(4, 10)
    ..lineTo(20, 10)
    ..lineTo(18.6, 18.4)
    ..quadraticBezierTo(18.4, 20, 16.8, 20)
    ..lineTo(7.2, 20)
    ..quadraticBezierTo(5.6, 20, 5.4, 18.4)
    ..close())),
  _s(_pl([8.5, 10, 11, 4.8])),
  _s(_pl([15.5, 10, 13, 4.8])),
  _s(_pl([10, 13.2, 10, 16.4])),
  _s(_pl([14, 13.2, 14, 16.4])),
]);

final _dining = Glyph('dining', 'Dining', [
  // fork
  _s(_p((p) {
    p.moveTo(6.5, 4);
    p.lineTo(6.5, 8.8);
    p.arcTo(Rect.fromCircle(center: const Offset(9, 8.8), radius: 2.5), math.pi, -math.pi, false);
    p.lineTo(11.5, 4);
  })),
  _s(_pl([9, 4, 9, 20])),
  // knife
  _s(_p((p) {
    p.moveTo(16, 20);
    p.lineTo(16, 4);
    p.quadraticBezierTo(19.2, 5.2, 19.2, 9.2);
    p.quadraticBezierTo(19.2, 12, 16, 12.6);
  })),
]);

final _transport = Glyph('transport', 'Transport and fuel', [
  _f(_rr(5, 4, 14, 20, 2.5)),
  _s(_pl([7.8, 8.2, 11.2, 8.2])),
  _s(_pl([3.5, 20, 15.5, 20])),
  _s(_p((p) {
    p.moveTo(14, 9);
    p.lineTo(16.2, 9);
    p.quadraticBezierTo(18.2, 9, 18.2, 11);
    p.lineTo(18.2, 15.8);
    p.quadraticBezierTo(18.2, 17.4, 19.7, 17.4);
    p.quadraticBezierTo(21.2, 17.4, 21.2, 15.8);
    p.lineTo(21.2, 9.6);
    p.lineTo(18.8, 6.8);
  })),
]);

final _car = Glyph('car', 'Car', [
  _f(_p((p) => p
    ..moveTo(3.5, 16.5)
    ..lineTo(3.5, 12.5)
    ..lineTo(5.4, 8)
    ..quadraticBezierTo(5.9, 6.8, 7.2, 6.8)
    ..lineTo(16.8, 6.8)
    ..quadraticBezierTo(18.1, 6.8, 18.6, 8)
    ..lineTo(20.5, 12.5)
    ..lineTo(20.5, 16.5)
    ..close())),
  _s(_pl([3.5, 12.5, 20.5, 12.5])),
  _s(_pl([5.6, 16.5, 5.6, 18.6])),
  _s(_pl([18.4, 16.5, 18.4, 18.6])),
  _s(_dot(7.4, 15.2)),
  _s(_dot(16.6, 15.2)),
]);

final _homeLoan = Glyph('home_loan', 'Home loan', [
  _f(_p((p) => p
    ..moveTo(4, 10.6)
    ..lineTo(12, 4)
    ..lineTo(20, 10.6)
    ..lineTo(20, 18)
    ..quadraticBezierTo(20, 20, 18, 20)
    ..lineTo(6, 20)
    ..quadraticBezierTo(4, 20, 4, 18)
    ..close())),
  _s(_circle(12, 12.6, 1.9)),
  _s(_pl([12, 14.5, 12, 17])),
]);

final _rent = Glyph('rent', 'Rent and housing', [
  _f(_p((p) => p
    ..moveTo(4, 10.6)
    ..lineTo(12, 4)
    ..lineTo(20, 10.6)
    ..lineTo(20, 18)
    ..quadraticBezierTo(20, 20, 18, 20)
    ..lineTo(6, 20)
    ..quadraticBezierTo(4, 20, 4, 18)
    ..close())),
  _s(_p((p) => p
    ..moveTo(9.8, 20)
    ..lineTo(9.8, 15.2)
    ..quadraticBezierTo(9.8, 13.6, 11.4, 13.6)
    ..lineTo(12.6, 13.6)
    ..quadraticBezierTo(14.2, 13.6, 14.2, 15.2)
    ..lineTo(14.2, 20))),
]);

final _utilities = Glyph('utilities', 'Utilities', [
  _f(_pl([13.2, 3.5, 5.6, 13.6, 11, 13.6, 10.2, 20.5, 18.4, 10.2, 13, 10.2], close: true)),
]);

final _telecom = Glyph('telecom', 'Telecom and internet', [
  _s(_arc(12, 18.5, 4.2, -135, 90)),
  _s(_arc(12, 18.5, 8.2, -135, 90)),
  _s(_arc(12, 18.5, 12.2, -135, 90)),
  _s(_dot(12, 18.8)),
]);

final _fixed = Glyph('fixed', 'Fixed expenses', [
  _f(_rr(4, 5.5, 20, 20, 2.5)),
  _s(_pl([4, 10.2, 20, 10.2])),
  _s(_pl([8.5, 3.5, 8.5, 7])),
  _s(_pl([15.5, 3.5, 15.5, 7])),
  _s(_dot(8.6, 14.2)),
  _s(_dot(12, 14.2)),
  _s(_dot(15.4, 14.2)),
  _s(_dot(8.6, 17.2)),
  _s(_dot(12, 17.2)),
]);

final _education = Glyph('education', 'Education', [
  _f(_pl([12, 5, 2.8, 9.6, 12, 14.2, 21.2, 9.6], close: true)),
  _s(_p((p) => p
    ..moveTo(6.4, 11.8)
    ..lineTo(6.4, 16)
    ..quadraticBezierTo(12, 19.6, 17.6, 16)
    ..lineTo(17.6, 11.8))),
  _s(_pl([21.2, 9.6, 21.2, 15])),
]);

final _health = Glyph('health', 'Health', [
  _f(_p((p) => p
    ..moveTo(12, 19.8)
    ..cubicTo(6, 15.6, 3.5, 12.8, 3.5, 9.2)
    ..cubicTo(3.5, 6.6, 5.5, 4.8, 7.9, 4.8)
    ..cubicTo(9.6, 4.8, 11.1, 5.7, 12, 7.1)
    ..cubicTo(12.9, 5.7, 14.4, 4.8, 16.1, 4.8)
    ..cubicTo(18.5, 4.8, 20.5, 6.6, 20.5, 9.2)
    ..cubicTo(20.5, 12.8, 18, 15.6, 12, 19.8)
    ..close())),
  _s(_pl([8, 11.8, 10.4, 11.8, 11.5, 9.6, 12.8, 13.8, 13.8, 11.8, 16, 11.8])),
]);

final _shopping = Glyph('shopping', 'Shopping', [
  _f(_p((p) => p
    ..moveTo(5, 8)
    ..lineTo(19, 8)
    ..lineTo(18.2, 18.4)
    ..quadraticBezierTo(18.1, 20, 16.5, 20)
    ..lineTo(7.5, 20)
    ..quadraticBezierTo(5.9, 20, 5.8, 18.4)
    ..close())),
  _s(_p((p) => p
    ..moveTo(9, 8)
    ..lineTo(9, 7)
    ..arcTo(Rect.fromCircle(center: const Offset(12, 7), radius: 3), math.pi, math.pi, false)
    ..lineTo(15, 8))),
]);

final _entertainment = Glyph('entertainment', 'Entertainment', [
  _f(_rr(3.5, 5.5, 20.5, 18.5, 2.5)),
  _s(_pl([10.2, 9.6, 14.6, 12, 10.2, 14.4], close: true)),
]);

final _travel = Glyph('travel', 'Travel', [
  _f(_p((p) => p
    ..moveTo(12, 3.5)
    ..quadraticBezierTo(13.6, 3.5, 13.6, 5.2)
    ..lineTo(13.6, 10)
    ..lineTo(20.5, 14.2)
    ..lineTo(20.5, 16)
    ..lineTo(13.6, 13.8)
    ..lineTo(13.6, 18)
    ..lineTo(15.8, 19.6)
    ..lineTo(15.8, 21)
    ..lineTo(12, 20)
    ..lineTo(8.2, 21)
    ..lineTo(8.2, 19.6)
    ..lineTo(10.4, 18)
    ..lineTo(10.4, 13.8)
    ..lineTo(3.5, 16)
    ..lineTo(3.5, 14.2)
    ..lineTo(10.4, 10)
    ..lineTo(10.4, 5.2)
    ..quadraticBezierTo(10.4, 3.5, 12, 3.5)
    ..close())),
]);

final _subscriptions = Glyph('subscriptions', 'Subscriptions', [
  _s(_arc(12, 12, 7.2, -165, 150)),
  _s(_arc(12, 12, 7.2, 15, 150)),
  _s(_pl([19, 5.8, 19, 10.1, 14.7, 10.1])),
  _s(_pl([5, 18.2, 5, 13.9, 9.3, 13.9])),
]);

final _income = Glyph('income', 'Salary and income', [
  _f(_rr(3, 6.5, 21, 17.5, 2.5)),
  _s(_circle(12, 12, 2.6)),
  _s(_dot(6.6, 12)),
  _s(_dot(17.4, 12)),
]);

final _incomeOther = Glyph('income_other', 'Other income', [
  _f(_circle(12, 12, 8.5)),
  _s(_pl([12, 8.2, 12, 15.8])),
  _s(_pl([8.2, 12, 15.8, 12])),
]);

final _transfer = Glyph('transfer', 'Transfers', [
  _s(_pl([4.5, 8.5, 19.5, 8.5])),
  _s(_pl([16, 5, 19.5, 8.5, 16, 12])),
  _s(_pl([19.5, 15.5, 4.5, 15.5])),
  _s(_pl([8, 12, 4.5, 15.5, 8, 19])),
]);

final _savings = Glyph('savings', 'Savings and investments', [
  _s(_pl([12, 20.5, 12, 11.5])),
  _f(_p((p) => p
    ..moveTo(12, 14.4)
    ..cubicTo(7.6, 14.4, 5, 12, 5, 8.2)
    ..cubicTo(9.4, 8.2, 12, 10.4, 12, 14.4)
    ..close())),
  _f(_p((p) => p
    ..moveTo(12, 11.4)
    ..cubicTo(12, 7.4, 14.8, 4.4, 19, 4.4)
    ..cubicTo(19, 8.6, 16.2, 11.4, 12, 11.4)
    ..close())),
]);

final _gifts = Glyph('gifts', 'Gifts and charity', [
  _f(_rr(4.5, 10.5, 19.5, 20.5, 2)),
  _s(_rr(3.5, 7.5, 20.5, 10.5, 1.5)),
  _s(_pl([12, 7.5, 12, 20.5])),
  _s(_p((p) => p
    ..moveTo(12, 7.5)
    ..cubicTo(9.6, 7.5, 8, 6.8, 8, 5.4)
    ..cubicTo(8, 4.2, 9.2, 3.6, 10.2, 3.9)
    ..cubicTo(11.5, 4.3, 12, 5.8, 12, 7.5))),
  _s(_p((p) => p
    ..moveTo(12, 7.5)
    ..cubicTo(14.4, 7.5, 16, 6.8, 16, 5.4)
    ..cubicTo(16, 4.2, 14.8, 3.6, 13.8, 3.9)
    ..cubicTo(12.5, 4.3, 12, 5.8, 12, 7.5))),
]);

final _family = Glyph('family', 'Family', [
  _s(_circle(9, 8.2, 2.9)),
  _s(_p((p) => p
    ..moveTo(3.6, 19.8)
    ..lineTo(3.6, 18.8)
    ..arcTo(Rect.fromCircle(center: const Offset(9, 18.8), radius: 5.4), math.pi, math.pi, false)
    ..lineTo(14.4, 19.8))),
  _s(_circle(17, 9.4, 2.2)),
  _s(_p((p) => p
    ..moveTo(16.6, 14.1)
    ..cubicTo(19.2, 13.9, 20.8, 15.6, 20.8, 17.6)
    ..lineTo(20.8, 18.6))),
]);

final _fees = Glyph('fees', 'Fees and interest', [
  _f(_p((p) => p
    ..moveTo(6, 3.8)
    ..lineTo(18, 3.8)
    ..lineTo(18, 20.4)
    ..lineTo(15.75, 18.8)
    ..lineTo(13.9, 20.4)
    ..lineTo(12, 18.8)
    ..lineTo(10.1, 20.4)
    ..lineTo(8.25, 18.8)
    ..lineTo(6, 20.4)
    ..close())),
  _s(_pl([9.4, 8.6, 14.6, 8.6])),
  _s(_pl([9.4, 12.4, 14.6, 12.4])),
]);

final _other = Glyph('other', 'Other', [
  _f(_circle(12, 12, 8.8)),
  _s(_dot(8, 12)),
  _s(_dot(12, 12)),
  _s(_dot(16, 12)),
]);

/// The fallback: a plain tag, for a category with no (or an unknown) glyph.
final _generic = Glyph('generic', 'Category', [
  _f(_p((p) => p
    ..moveTo(4, 5.5)
    ..quadraticBezierTo(4, 4, 5.5, 4)
    ..lineTo(11.6, 4)
    ..quadraticBezierTo(12.6, 4, 13.3, 4.7)
    ..lineTo(19.8, 11.2)
    ..quadraticBezierTo(20.8, 12.2, 19.8, 13.2)
    ..lineTo(13.2, 19.8)
    ..quadraticBezierTo(12.2, 20.8, 11.2, 19.8)
    ..lineTo(4.7, 13.3)
    ..quadraticBezierTo(4, 12.6, 4, 11.6)
    ..close())),
  _s(_dot(8.4, 8.4)),
]);

// ---- extras for custom categories -------------------------------------------

final _coffee = Glyph('coffee', 'Coffee', [
  _f(_p((p) => p
    ..moveTo(5, 9.5)
    ..lineTo(16, 9.5)
    ..lineTo(16, 14.5)
    ..quadraticBezierTo(16, 19, 11.5, 19)
    ..lineTo(9.5, 19)
    ..quadraticBezierTo(5, 19, 5, 14.5)
    ..close())),
  _s(_p((p) => p
    ..moveTo(16, 11)
    ..lineTo(17.4, 11)
    ..quadraticBezierTo(19.5, 11, 19.5, 13.2)
    ..quadraticBezierTo(19.5, 15.4, 17.4, 15.4)
    ..lineTo(16, 15.4))),
  _s(_pl([8.5, 3.8, 8.5, 6.2])),
  _s(_pl([12.5, 3.8, 12.5, 6.2])),
]);

final _paw = Glyph('paw', 'Pets', [
  _f(_p((p) => p
    ..moveTo(12, 11.4)
    ..cubicTo(9.2, 11.4, 6.8, 14.2, 6.8, 16.6)
    ..cubicTo(6.8, 18.4, 8.2, 19.4, 9.8, 19.4)
    ..cubicTo(10.8, 19.4, 11.3, 19, 12, 19)
    ..cubicTo(12.7, 19, 13.2, 19.4, 14.2, 19.4)
    ..cubicTo(15.8, 19.4, 17.2, 18.4, 17.2, 16.6)
    ..cubicTo(17.2, 14.2, 14.8, 11.4, 12, 11.4)
    ..close())),
  _s(_dot(5.6, 10.6)),
  _s(_dot(9.4, 6.6)),
  _s(_dot(14.6, 6.6)),
  _s(_dot(18.4, 10.6)),
]);

final _dumbbell = Glyph('dumbbell', 'Fitness', [
  _s(_pl([8, 12, 16, 12])),
  _f(_rr(4.8, 7.5, 8, 16.5, 1.5)),
  _f(_rr(16, 7.5, 19.2, 16.5, 1.5)),
  _s(_pl([3, 10.2, 3, 13.8])),
  _s(_pl([21, 10.2, 21, 13.8])),
]);

final _book = Glyph('book', 'Books', [
  _f(_p((p) => p
    ..moveTo(12, 6.6)
    ..cubicTo(10.4, 5, 7.8, 4.6, 4.5, 4.8)
    ..lineTo(4.5, 17.8)
    ..cubicTo(7.8, 17.6, 10.4, 18, 12, 19.6)
    ..cubicTo(13.6, 18, 16.2, 17.6, 19.5, 17.8)
    ..lineTo(19.5, 4.8)
    ..cubicTo(16.2, 4.6, 13.6, 5, 12, 6.6)
    ..close())),
  _s(_pl([12, 6.6, 12, 19.6])),
]);

final _music = Glyph('music', 'Music', [
  _s(_pl([9, 17.5, 9, 5.8, 18, 4, 18, 15.6])),
  _f(_circle(6.6, 17.6, 2.4)),
  _f(_circle(15.6, 15.8, 2.4)),
]);

final _camera = Glyph('camera', 'Photography', [
  _f(_p((p) => p
    ..moveTo(4, 8.5)
    ..quadraticBezierTo(4, 7, 5.5, 7)
    ..lineTo(8, 7)
    ..lineTo(9.4, 5)
    ..lineTo(14.6, 5)
    ..lineTo(16, 7)
    ..lineTo(18.5, 7)
    ..quadraticBezierTo(20, 7, 20, 8.5)
    ..lineTo(20, 17.5)
    ..quadraticBezierTo(20, 19, 18.5, 19)
    ..lineTo(5.5, 19)
    ..quadraticBezierTo(4, 19, 4, 17.5)
    ..close())),
  _s(_circle(12, 12.6, 3.2)),
]);

final _gamepad = Glyph('gamepad', 'Games', [
  _f(_p((p) => p
    ..moveTo(7.5, 7.5)
    ..lineTo(16.5, 7.5)
    ..quadraticBezierTo(20.2, 7.5, 20.8, 12.6)
    ..lineTo(21, 15)
    ..quadraticBezierTo(21.2, 17.6, 18.8, 17.6)
    ..quadraticBezierTo(17.4, 17.6, 16.6, 16.4)
    ..lineTo(15.6, 15)
    ..lineTo(8.4, 15)
    ..lineTo(7.4, 16.4)
    ..quadraticBezierTo(6.6, 17.6, 5.2, 17.6)
    ..quadraticBezierTo(2.8, 17.6, 3, 15)
    ..lineTo(3.2, 12.6)
    ..quadraticBezierTo(3.8, 7.5, 7.5, 7.5)
    ..close())),
  _s(_pl([8, 10.4, 8, 13.2])),
  _s(_pl([6.6, 11.8, 9.4, 11.8])),
  _s(_dot(15.6, 10.8)),
  _s(_dot(17.6, 12.8)),
]);

final _shirt = Glyph('shirt', 'Clothing', [
  _f(_p((p) => p
    ..moveTo(8.6, 4.5)
    ..lineTo(3.5, 7.4)
    ..lineTo(5.4, 11.2)
    ..lineTo(7.6, 10.2)
    ..lineTo(7.6, 19.5)
    ..lineTo(16.4, 19.5)
    ..lineTo(16.4, 10.2)
    ..lineTo(18.6, 11.2)
    ..lineTo(20.5, 7.4)
    ..lineTo(15.4, 4.5)
    ..arcTo(Rect.fromCircle(center: const Offset(12, 4.5), radius: 3.4), 0, math.pi, false)
    ..close())),
]);

final _bike = Glyph('bike', 'Cycling', [
  _s(_circle(6.2, 16, 3.4)),
  _s(_circle(17.8, 16, 3.4)),
  _s(_pl([6.2, 16, 10, 8.5, 15.6, 8.5, 17.8, 16])),
  _s(_pl([10, 8.5, 13, 16, 6.2, 16])),
  _s(_pl([8.6, 6, 11.2, 6])),
]);

final _bus = Glyph('bus', 'Public transport', [
  _f(_rr(4.5, 4, 19.5, 17.5, 2.5)),
  _s(_pl([4.5, 11, 19.5, 11])),
  _s(_dot(8.2, 14.2)),
  _s(_dot(15.8, 14.2)),
  _s(_pl([7, 17.5, 7, 20])),
  _s(_pl([17, 17.5, 17, 20])),
]);

final _phone = Glyph('phone', 'Phone', [
  _f(_rr(7, 3.5, 17, 20.5, 2.5)),
  _s(_pl([10.6, 17.6, 13.4, 17.6])),
]);

final _laptop = Glyph('laptop', 'Computing', [
  _f(_rr(5.5, 5.5, 18.5, 15.5, 2)),
  _s(_pl([3, 19, 21, 19])),
]);

final _wrench = Glyph('wrench', 'Repairs', [
  _f(_p((p) => p
    ..moveTo(14.4, 4.6)
    ..cubicTo(12, 5, 10.6, 7.4, 11.4, 9.6)
    ..lineTo(4.4, 16.6)
    ..quadraticBezierTo(3.2, 17.8, 4.4, 19)
    ..lineTo(5, 19.6)
    ..quadraticBezierTo(6.2, 20.8, 7.4, 19.6)
    ..lineTo(14.4, 12.6)
    ..cubicTo(16.6, 13.4, 19, 12, 19.4, 9.6)
    ..lineTo(16.6, 9.8)
    ..lineTo(14.2, 7.4)
    ..close())),
]);

final _leaf = Glyph('leaf', 'Garden', [
  _f(_p((p) => p
    ..moveTo(5, 19)
    ..cubicTo(3.8, 10.4, 9, 5, 19.5, 4.5)
    ..cubicTo(20, 14.5, 14.6, 19.6, 5, 19)
    ..close())),
  _s(_pl([5, 19, 12, 12])),
]);

final _umbrella = Glyph('umbrella', 'Insurance', [
  _f(_p((p) => p
    ..moveTo(3.5, 12)
    ..arcTo(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5), math.pi, math.pi, false)
    ..close())),
  _s(_p((p) => p
    ..moveTo(12, 12)
    ..lineTo(12, 18)
    ..quadraticBezierTo(12, 20, 14, 20)
    ..quadraticBezierTo(16, 20, 16, 18.2))),
]);

final _sun = Glyph('sun', 'Leisure', [
  _f(_circle(12, 12, 3.6)),
  _s(_pl([12, 3.8, 12, 5.6])),
  _s(_pl([12, 18.4, 12, 20.2])),
  _s(_pl([3.8, 12, 5.6, 12])),
  _s(_pl([18.4, 12, 20.2, 12])),
  _s(_pl([6.2, 6.2, 7.5, 7.5])),
  _s(_pl([16.5, 16.5, 17.8, 17.8])),
  _s(_pl([17.8, 6.2, 16.5, 7.5])),
  _s(_pl([7.5, 16.5, 6.2, 17.8])),
]);

final _pill = Glyph('pill', 'Medicine', [
  _f(_rot(_rr(9, 3.5, 15, 20.5, 3), 45)),
  _s(_rot(_pl([9, 12, 15, 12]), 45)),
]);

final _palette = Glyph('palette', 'Hobbies', [
  _f(_p((p) => p
    ..moveTo(12, 4)
    ..cubicTo(7.6, 4, 4, 7.4, 4, 11.8)
    ..cubicTo(4, 16.2, 7.6, 19.8, 12, 19.8)
    ..cubicTo(13.4, 19.8, 14, 19, 14, 18.2)
    ..cubicTo(14, 17, 13, 16.8, 13, 15.6)
    ..cubicTo(13, 14.8, 13.7, 14.2, 14.6, 14.2)
    ..lineTo(16.6, 14.2)
    ..cubicTo(18.6, 14.2, 20, 13, 20, 11.2)
    ..cubicTo(20, 7.2, 16.4, 4, 12, 4)
    ..close())),
  _s(_dot(8, 11)),
  _s(_dot(10.4, 7.8)),
  _s(_dot(14.4, 7.8)),
]);

final _star = Glyph('star', 'Favourites', [
  _f(_pl([12, 4, 14.4, 9.2, 20, 9.9, 15.9, 13.8, 17, 19.4, 12, 16.6, 7, 19.4, 8.1, 13.8, 4, 9.9, 9.6, 9.2], close: true)),
]);

final _chart = Glyph('chart', 'Investing', [
  _s(_pl([3.5, 17.5, 9, 12, 12.4, 15.2, 20, 7.5])),
  _s(_pl([15, 7.5, 20, 7.5, 20, 12.5])),
]);

final _coins = Glyph('coins', 'Cash', [
  _f(_p((p) => p
    ..addOval(Rect.fromCenter(center: const Offset(12, 7.5), width: 14, height: 5.4)))),
  _s(_p((p) => p
    ..moveTo(5, 7.5)
    ..lineTo(5, 12)
    ..arcTo(Rect.fromCenter(center: const Offset(12, 12), width: 14, height: 5.4), math.pi, -math.pi, false)
    ..lineTo(19, 7.5))),
  _s(_p((p) => p
    ..moveTo(5, 12)
    ..lineTo(5, 16.5)
    ..arcTo(Rect.fromCenter(center: const Offset(12, 16.5), width: 14, height: 5.4), math.pi, -math.pi, false)
    ..lineTo(19, 12))),
]);

final _landmark = Glyph('landmark', 'Bank', [
  _f(_pl([3.5, 9, 12, 4, 20.5, 9], close: true)),
  _s(_pl([6.5, 11.5, 6.5, 17])),
  _s(_pl([12, 11.5, 12, 17])),
  _s(_pl([17.5, 11.5, 17.5, 17])),
  _s(_pl([3.5, 20, 20.5, 20])),
]);

final _wallet = Glyph('wallet', 'Wallet', [
  _f(_rr(3.5, 6.5, 20.5, 19, 2.5)),
  _s(_p((p) => p
    ..moveTo(3.5, 9.5)
    ..lineTo(3.5, 6.5)
    ..quadraticBezierTo(3.5, 4.8, 5.2, 4.8)
    ..lineTo(16.5, 4.8))),
  _s(_dot(16.6, 12.8)),
]);

final _percent = Glyph('percent', 'Interest', [
  _s(_pl([18, 5.5, 6, 18.5])),
  _s(_circle(7.6, 7.6, 2.4)),
  _s(_circle(16.4, 16.4, 2.4)),
]);

/// Glyphs a user can pick for a custom category, in picker order.
final List<Glyph> customGlyphs = [
  _coffee, _paw, _dumbbell, _book, _music, _camera, //
  _gamepad, _shirt, _bike, _bus, _phone, _laptop,
  _wrench, _leaf, _umbrella, _sun, _pill, _palette,
  _star, _chart, _coins, _landmark, _wallet, _percent,
];

/// The default categories' glyphs plus the fallback.
final List<Glyph> defaultGlyphs = [
  _groceries, _dining, _transport, _car, _homeLoan, _rent, _utilities, //
  _telecom, _fixed, _education, _health, _shopping, _entertainment,
  _travel, _subscriptions, _income, _incomeOther, _transfer, _savings,
  _gifts, _family, _fees, _other, _generic,
];

final Map<String, Glyph> glyphsByKey = {
  for (final g in [...defaultGlyphs, ...customGlyphs]) g.key: g,
};

/// The fallback glyph.
Glyph get genericGlyph => _generic;

/// Which glyph each default category id wears.
const defaultGlyphKeys = <String, String>{
  'salary': 'income',
  'income': 'income',
  'other_income': 'income_other',
  'groceries': 'groceries',
  'dining': 'dining',
  'transport': 'transport',
  'car_loan': 'car',
  'home_loan': 'home_loan',
  'rent': 'rent',
  'utilities': 'utilities',
  'telecom': 'telecom',
  'fixed_expenses': 'fixed',
  'education': 'education',
  'health': 'health',
  'shopping': 'shopping',
  'travel': 'travel',
  'entertainment': 'entertainment',
  'subscriptions': 'subscriptions',
  'family': 'family',
  'savings': 'savings',
  'cc_payment': 'transfer',
  'transfer': 'transfer',
  'gifts': 'gifts',
  'charity': 'gifts',
  'fees': 'fees',
  'other': 'other',
};
