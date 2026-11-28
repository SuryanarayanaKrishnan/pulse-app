import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Layout invariants checked on whatever is on screen. Each returns
/// human-readable problems (empty = fine). These catch the class of bug that
/// "no exception was thrown" never will: text drawn on top of text, a card
/// glued to the next card, a sheet you can see through, a button too small to
/// hit.

class Seen {
  Seen(this.text, this.rect, this.element);
  final String text;
  final Rect rect;
  final Element element;
}

bool _hidden(Element e) {
  var hidden = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Offstage && w.offstage) hidden = true;
    if (w is Opacity && w.opacity == 0) hidden = true;
    if (w is Visibility && !w.visible) hidden = true;
    return !hidden;
  });
  return hidden;
}

bool _inHorizontalScroller(Element e) {
  var found = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Scrollable &&
        axisDirectionToAxis(w.axisDirection) == Axis.horizontal) {
      found = true;
    }
    if (w is PageView) found = true;
    return !found;
  });
  return found;
}

bool _hasAncestor(Element e, bool Function(Widget) test) {
  var found = false;
  e.visitAncestorElements((a) {
    if (test(a.widget)) found = true;
    return !found;
  });
  return found;
}

/// The root the audit looks at: the open sheet if there is one (what is
/// underneath is covered), else the whole screen.
Finder auditScope(WidgetTester tester) {
  final sheets = find.byType(BottomSheet);
  if (sheets.evaluate().isNotEmpty) return sheets.last;
  return find.byType(Navigator).first;
}

/// Every painted paragraph in [scope] that is on screen.
List<Seen> visibleParagraphs(WidgetTester tester, Finder scope) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final screen = Offset.zero & size;
  final out = <Seen>[];
  final els = find
      .descendant(of: scope, matching: find.byType(RichText))
      .evaluate();
  for (final e in els) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached || !ro.hasSize) continue;
    if (_hidden(e)) continue;
    final text = ro.text.toPlainText().trim();
    if (text.isEmpty) continue;
    // Through every transform above it, so a FittedBox that scales text down
    // is measured at its painted size.
    final r = MatrixUtils.transformRect(
      ro.getTransformTo(null),
      Offset.zero & ro.size,
    );
    if (r.width < 1 || r.height < 1) continue;
    if (!r.overlaps(screen)) continue;
    // Painted on top, not scrolled out or hidden under the tab bar: a tap at
    // its centre must reach it.
    final probe = r.intersect(screen).center;
    final hit = tester.hitTestOnBinding(probe);
    if (!hit.path.any((h) => identical(h.target, ro))) continue;
    out.add(Seen(text, r, e));
  }
  return out;
}

/// Text drawn on top of other text.
List<String> overlappingText(WidgetTester tester, {Finder? scope}) {
  final seen = visibleParagraphs(tester, scope ?? auditScope(tester));
  final problems = <String>[];
  for (var i = 0; i < seen.length; i++) {
    for (var j = i + 1; j < seen.length; j++) {
      final a = seen[i], b = seen[j];
      final inter = a.rect.intersect(b.rect);
      if (inter.width <= 2 || inter.height <= 3) continue;
      // Deliberate layering (art on a card face, chart labels, badges).
      bool layered(Element e) => _hasAncestor(
        e,
        (w) =>
            w.runtimeType.toString().contains('CreditCardVisual') ||
            w.runtimeType.toString().contains('Chart') ||
            w.runtimeType.toString().contains('Sankey'),
      );
      if (layered(a.element) && layered(b.element)) continue;
      // Pinned chrome (a footer button bar) over scrolling content is by design.
      bool scrolls(Element e) => _hasAncestor(e, (w) => w is Scrollable);
      if (scrolls(a.element) != scrolls(b.element)) continue;
      // Only where both are really painted: text scrolled half under a pinned
      // footer is not an overlap.
      final hit = tester.hitTestOnBinding(inter.center);
      bool reaches(Seen x) =>
          hit.path.any((h) => identical(h.target, x.element.renderObject));
      if (!reaches(a) && !reaches(b)) continue;
      problems.add(
        'text overlaps text: "${_clip(a.text)}" ${_fmt(a.rect)} vs "${_clip(b.text)}" ${_fmt(b.rect)}',
      );
    }
  }
  return problems;
}

/// The same sentence shown twice on one screen: a card rendered twice (the
/// duplicate Home card) reads as identical long text at two places.
List<String> duplicateBlocks(WidgetTester tester, {Finder? scope}) {
  final counts = <String, int>{};
  for (final s in visibleParagraphs(tester, scope ?? auditScope(tester))) {
    if (s.text.length < 45) continue;
    counts[s.text] = (counts[s.text] ?? 0) + 1;
  }
  return [
    for (final e in counts.entries)
      if (e.value > 1) 'same text shown ${e.value} times: "${_clip(e.key)}"',
  ];
}

/// Text that runs off the left/right edge of the screen (outside carousels).
List<String> textOffScreen(WidgetTester tester, {Finder? scope}) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final problems = <String>[];
  for (final s in visibleParagraphs(tester, scope ?? auditScope(tester))) {
    if (_inHorizontalScroller(s.element)) continue;
    if (s.rect.left < -1 || s.rect.right > size.width + 1) {
      problems.add(
        'text off screen: "${_clip(s.text)}" ${_fmt(s.rect)} in ${_chain(s.element)}',
      );
    }
  }
  return problems;
}

/// Tappable things smaller than a fingertip (Apple's minimum is 44 pt; 32 is
/// the floor we tolerate for dense inline controls).
List<String> tinyTapTargets(WidgetTester tester, {Finder? scope}) {
  final problems = <String>[];
  final els = find
      .descendant(
        of: scope ?? auditScope(tester),
        matching: find.byWidgetPredicate(
          (w) =>
              (w is InkWell && w.onTap != null) ||
              (w is GestureDetector && w.onTap != null),
        ),
      )
      .evaluate();
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final e in els) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
    if (_hidden(e)) continue;
    final r = ro.localToGlobal(Offset.zero) & ro.size;
    if (!r.overlaps(Offset.zero & size)) continue;
    if (_hasAncestor(e, (w) => w is TextField || w is EditableText)) continue;
    if (r.height < 30 && r.width < 30 && r.width > 0 && r.height > 0) {
      problems.add(
        'tap target ${r.width.round()}x${r.height.round()} at ${_fmt(r)}',
      );
    }
  }
  return problems;
}

/// Opaque rounded surfaces (cards) that touch a neighbour with no gap.
List<String> gluedCards(WidgetTester tester, {Finder? scope}) {
  final boxes = <(Rect, Element, bool)>[];
  final els = find
      .descendant(
        of: scope ?? auditScope(tester),
        matching: find.byType(DecoratedBox),
      )
      .evaluate();
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final e in els) {
    final w = e.widget as DecoratedBox;
    final d = w.decoration;
    if (d is! BoxDecoration) continue;
    if (d.borderRadius == null || d.color == null || d.color!.a < 0.9) continue;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
    if (_hidden(e)) continue;
    // Floating coach tips and carousels overlap by design.
    if (_inHorizontalScroller(e) ||
        _hasAncestor(e, (w) => w.runtimeType.toString().contains('Coach'))) {
      continue;
    }
    // Remember whether it scrolls: pinned chrome over scrolling content is fine.
    final scrolls = _hasAncestor(e, (w) => w is Scrollable);
    final r = ro.localToGlobal(Offset.zero) & ro.size;
    if (r.width < 120 || r.height < 40) continue;
    if (!r.overlaps(Offset.zero & size)) continue;
    boxes.add((r, e, scrolls));
  }
  final problems = <String>[];
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      if (boxes[i].$3 != boxes[j].$3) continue;
      final a = boxes[i].$1, b = boxes[j].$1;
      final xOverlap = math.min(a.right, b.right) - math.max(a.left, b.left);
      if (xOverlap < math.min(a.width, b.width) * 0.6) continue;
      // Vertical neighbours that touch or overlap each other but do not nest.
      final nested =
          (a.inflate(1).contains(b.topLeft) &&
              a.inflate(1).contains(b.bottomRight)) ||
          (b.inflate(1).contains(a.topLeft) &&
              b.inflate(1).contains(a.bottomRight));
      if (nested) continue;
      final gap = a.top < b.top ? b.top - a.bottom : a.top - b.bottom;
      if (gap < 1 && gap > -2) {
        problems.add('cards touch with no gap: ${_fmt(a)} / ${_fmt(b)}');
      } else if (gap <= -2) {
        problems.add('cards overlap: ${_fmt(a)} / ${_fmt(b)}');
      }
    }
  }
  return problems;
}

/// A bottom sheet whose background you can see through: some painted layer
/// under its content must be opaque and cover (almost) all of it.
List<String> seeThroughSheets(WidgetTester tester) {
  final problems = <String>[];
  for (final e in find.byType(BottomSheet).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize) continue;
    final sheet = ro.localToGlobal(Offset.zero) & ro.size;
    var covered = false;
    void walk(RenderObject o) {
      if (covered) return;
      if (o is RenderBox && o.hasSize && o.attached) {
        final r = o.localToGlobal(Offset.zero) & o.size;
        final fills =
            r.width >= sheet.width - 2 && r.height >= sheet.height * 0.9;
        if (fills) {
          if (o is RenderDecoratedBox) {
            final d = o.decoration;
            if (d is BoxDecoration && d.color != null && d.color!.a >= 0.99) {
              covered = true;
            }
          } else if (o is RenderPhysicalModel) {
            if (o.color.a >= 0.99) covered = true;
          } else if (o is RenderPhysicalShape) {
            if (o.color.a >= 0.99) covered = true;
          }
        }
      }
      o.visitChildren(walk);
    }

    ro.visitChildren(walk);
    if (!covered) {
      problems.add(
        'sheet ${_fmt(sheet)} has no opaque background (see-through)',
      );
    }
  }
  return problems;
}

/// The nearest few widget types above [e], to find which widget drew it.
String _chain(Element e) {
  final out = <String>[];
  e.visitAncestorElements((a) {
    out.add(a.widget.runtimeType.toString());
    return out.length < 9;
  });
  return out.join('<');
}

String _clip(String s) => s.length > 40 ? '${s.substring(0, 40)}…' : s;
String _fmt(Rect r) =>
    '[${r.left.round()},${r.top.round()} ${r.width.round()}x${r.height.round()}]';

/// All audits at once.
List<String> auditScreen(WidgetTester tester) => [
  ...overlappingText(tester),
  ...textOffScreen(tester),
  ...gluedCards(tester),
  ...duplicateBlocks(tester),
  ...seeThroughSheets(tester),
];
