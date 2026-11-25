import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum AnnotateTool { pen, blur }

@immutable
sealed class Mark {
  const Mark();
}

/// Freehand stroke. Points are 0..1 of the screenshot so they scale to any size.
class PenMark extends Mark {
  const PenMark(this.color, this.points);
  final Color color;
  final List<Offset> points;
}

/// A box that hides what is under it. Normalised like [PenMark].
class BlurMark extends Mark {
  const BlurMark(this.rect);
  final Rect rect;
}

/// Annotation state, kept apart from the widgets so it is easy to test.
class AnnotationController extends ChangeNotifier {
  AnnotateTool tool = AnnotateTool.pen;
  Color penColor = penColors.first;
  bool maskAll = false;
  final _marks = <Mark>[];
  Mark? _live;

  static const penColors = [Color(0xFFE5484D), Color(0xFFF5C04A)];

  List<Mark> get marks => List.unmodifiable(_marks);
  Mark? get live => _live;
  bool get hasMarks => _marks.isNotEmpty;
  int get penCount => _marks.whereType<PenMark>().length;
  int get blurCount => _marks.whereType<BlurMark>().length;

  void setTool(AnnotateTool t) {
    tool = t;
    notifyListeners();
  }

  void setColor(Color c) {
    penColor = c;
    tool = AnnotateTool.pen;
    notifyListeners();
  }

  void setMaskAll(bool v) {
    maskAll = v;
    notifyListeners();
  }

  Offset _clamp(Offset o) => Offset(o.dx.clamp(0.0, 1.0), o.dy.clamp(0.0, 1.0));

  Offset? _origin;

  void begin(Offset p) {
    final n = _clamp(p);
    _origin = n;
    _live = tool == AnnotateTool.pen
        ? PenMark(penColor, [n])
        : BlurMark(Rect.fromPoints(n, n));
    notifyListeners();
  }

  void extend(Offset p) {
    final n = _clamp(p);
    final cur = _live;
    if (cur is PenMark) {
      _live = PenMark(cur.color, [...cur.points, n]);
    } else if (cur is BlurMark && _origin != null) {
      _live = BlurMark(Rect.fromPoints(_origin!, n));
    }
    notifyListeners();
  }

  void end() {
    final cur = _live;
    _live = null;
    if (cur is PenMark && cur.points.length >= 2) _marks.add(cur);
    if (cur is BlurMark && cur.rect.width > 0.01 && cur.rect.height > 0.01) _marks.add(cur);
    notifyListeners();
  }

  void undo() {
    if (_marks.isEmpty) return;
    _marks.removeLast();
    notifyListeners();
  }

  void clear() {
    _marks.clear();
    _live = null;
    notifyListeners();
  }
}

/// A coarse, unreadable copy of [src]: each cell of about [cell] pixels is
/// one flat colour. Drawn back with no smoothing it hides text.
Future<ui.Image> pixelate(ui.Image src, {int cell = 22}) async {
  final w = (src.width / cell).ceil().clamp(1, src.width);
  final h = (src.height / cell).ceil().clamp(1, src.height);
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawImageRect(
    src,
    Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  return rec.endRecording().toImage(w, h);
}

/// Paints the screenshot with its marks. Used on screen and for the export.
class AnnotationPainter extends CustomPainter {
  AnnotationPainter({
    required this.image,
    required this.coarse,
    required this.controller,
  }) : super(repaint: controller);

  final ui.Image? image;

  /// Output of [pixelate]; blur boxes and "mask all" need it.
  final ui.Image? coarse;
  final AnnotationController controller;

  static final _blocky = Paint()..filterQuality = FilterQuality.none;

  void _drawCoarse(Canvas canvas, Size size, Rect dst) {
    final c = coarse;
    if (c == null) {
      // Not ready yet: never show the original through a blur box.
      canvas.drawRect(dst, Paint()..color = const Color(0xFF8A8F8C));
      return;
    }
    canvas.drawImageRect(
      c,
      Rect.fromLTWH(0, 0, c.width.toDouble(), c.height.toDouble()),
      dst,
      _blocky,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final img = image;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        full,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    if (controller.maskAll) _drawCoarse(canvas, size, full);
    final all = [...controller.marks, if (controller.live != null) controller.live!];
    for (final m in all) {
      if (m is BlurMark) {
        final r = Rect.fromLTRB(
          m.rect.left * size.width,
          m.rect.top * size.height,
          m.rect.right * size.width,
          m.rect.bottom * size.height,
        );
        canvas.save();
        canvas.clipRect(r);
        _drawCoarse(canvas, size, full);
        canvas.restore();
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x66FFFFFF),
        );
      } else if (m is PenMark) {
        final paint = Paint()
          ..color = m.color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = size.width * 0.011;
        final path = Path();
        for (var i = 0; i < m.points.length; i++) {
          final p = Offset(m.points[i].dx * size.width, m.points[i].dy * size.height);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
        if (m.points.length == 1) {
          canvas.drawCircle(
            Offset(m.points.first.dx * size.width, m.points.first.dy * size.height),
            paint.strokeWidth / 2,
            paint..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(AnnotationPainter old) =>
      old.image != image || old.coarse != coarse || old.controller != controller;
}

/// Renders the annotated screenshot to PNG at the screenshot's own size.
Future<Uint8List?> renderAnnotatedPng({
  required ui.Image image,
  required ui.Image? coarse,
  required AnnotationController controller,
}) async {
  final size = Size(image.width.toDouble(), image.height.toDouble());
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  AnnotationPainter(image: image, coarse: coarse, controller: controller).paint(canvas, size);
  final out = await rec.endRecording().toImage(image.width, image.height);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
