import 'dart:io';

import '../../core/router/router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/attachments.dart';
import '../../data/providers.dart';

double? parseNumber(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  return v == null || v < 0 ? null : v;
}

/// AED text to fils, or null when empty/invalid.
int? parseMinor(String s) {
  final v = parseNumber(s);
  return v == null ? null : (v * 100).round();
}

String formatDate(CalDate d) {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// "+4.2%" / "-1.0%".
String pctText(double p) =>
    '${p >= 0 ? '+' : '−'}${p.abs().toStringAsFixed(1)}%';

Future<CalDate?> pickDate(
  BuildContext context, {
  CalDate? initial,
  bool future = false,
}) async {
  final now = DateTime.now();
  final init = initial == null
      ? now
      : DateTime(initial.year, initial.month, initial.day);
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime(future ? now.year - 1 : 1990),
    lastDate: DateTime(future ? now.year + 30 : now.year + 1),
  );
  return d == null ? null : CalDate(d.year, d.month, d.day);
}

/// A photo from app-private storage, or a drawn placeholder for the demo
/// (`demo:n`) and the web build, where files do not exist.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.document = false,
  });
  final String path;
  final BoxFit fit;
  final bool document;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('demo:') || kIsWeb) {
      final n = int.tryParse(path.split(':').last) ?? 0;
      return CustomPaint(
        painter: _DemoPhotoPainter(n, document, context.pc.isDark),
        child: const SizedBox.expand(),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (_, _, _) => ColoredBox(
        color: context.pc.surfaceElevated,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: context.pc.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _DemoPhotoPainter extends CustomPainter {
  _DemoPhotoPainter(this.n, this.document, this.dark);
  final int n;
  final bool document, dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (document) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = dark ? const Color(0xFF2B2A27) : const Color(0xFFF1EEE6),
      );
      final ink = Paint()
        ..color = (dark ? const Color(0xFFB9B4A8) : const Color(0xFF6E6A60))
            .withValues(alpha: 0.55);
      final w = size.width, h = size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .12, h * .12, w * .5, h * .06),
          const Radius.circular(3),
        ),
        ink,
      );
      for (var i = 0; i < 7; i++) {
        final len = (i % 3 == 2) ? .5 : .76;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .12, h * (.28 + i * .075), w * len, h * .022),
            const Radius.circular(2),
          ),
          ink..color = ink.color.withValues(alpha: 0.35),
        );
      }
      canvas.drawCircle(
        Offset(w * .74, h * .8),
        w * .1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFC0392B).withValues(alpha: 0.45),
      );
      return;
    }
    // Warm, soft backdrop with a golden arc: reads as "a photo of a piece".
    final hue = [0.0, 0.12, 0.2, 0.06, 0.16][n % 5];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Color.lerp(
                    const Color(0xFF2A2420),
                    const Color(0xFF3A2F22),
                    hue * 3,
                  )!,
                  const Color(0xFF14110E),
                ]
              : [
                  Color.lerp(
                    const Color(0xFFF3E8D4),
                    const Color(0xFFE9D7B5),
                    hue * 3,
                  )!,
                  const Color(0xFFD8C39B),
                ],
        ).createShader(rect),
    );
    final c = Offset(size.width * (.5 + (n % 3 - 1) * .04), size.height * .52);
    final r = size.shortestSide * (.26 + (n % 4) * .02);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        c,
        r - i * r * .09,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (.2 - i * .05)
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6D87A), Color(0xFFB98A2A), Color(0xFFF0CB62)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    canvas.drawCircle(
      Offset(c.dx + r * .62, c.dy - r * .72),
      r * .09,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_DemoPhotoPainter old) =>
      old.n != n || old.document != document || old.dark != dark;
}

/// Thumbnails of an item's photos; tap one to open the full-screen viewer.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip(
    this.paths, {
    super.key,
    this.size = 92,
    this.document = false,
  });
  final List<String> paths;
  final double size;
  final bool document;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (_, i) => Semantics(
          button: true,
          label: 'Open photo ${i + 1} of ${paths.length}',
          child: Pressable(
            onTap: () => showPhotoViewer(context, paths, i, document: document),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: SizedBox(
                width: size,
                height: size,
                child: AttachmentImage(paths[i], document: document),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showPhotoViewer(
  BuildContext context,
  List<String> paths,
  int index, {
  bool document = false,
}) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: true,
    pageBuilder: (_, _, _) =>
        PhotoViewer(paths: paths, initial: index, document: document),
    transitionsBuilder: (_, a, _, child) =>
        FadeTransition(opacity: a, child: child),
  ),
);

/// Full-screen gallery: swipe between photos, pinch to zoom, tap to close.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.paths,
    this.initial = 0,
    this.document = false,
  });
  final List<String> paths;
  final int initial;
  final bool document;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        PageView.builder(
          controller: _page,
          itemCount: widget.paths.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: AttachmentImage(
                widget.paths[i],
                fit: BoxFit.contain,
                document: widget.document,
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Text(
                  '${_index + 1} / ${widget.paths.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: Space.md),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// The editable photo row of an add/edit sheet: existing and new photos with
/// a remove button, plus camera and gallery buttons. New photos are held as
/// temporary picker paths until Save copies them into private storage.
class PhotoPickerRow extends ConsumerWidget {
  const PhotoPickerRow({
    super.key,
    required this.existing,
    required this.added,
    required this.onAdd,
    required this.onRemoveExisting,
    required this.onRemoveAdded,
    this.document = false,
    this.cameraLabel = 'Take photo',
  });
  final List<String> existing, added;
  final ValueChanged<String> onAdd, onRemoveExisting, onRemoveAdded;
  final bool document;
  final String cameraLabel;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    PhotoSource source,
  ) async {
    try {
      final path = await ref.read(photoPickerProvider).pick(source);
      if (path != null) onAdd(path);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the camera or photos. Check the permission in Settings.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tile(String path, VoidCallback remove) => Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: SizedBox(
              width: 72,
              height: 72,
              child: AttachmentImage(path, document: document),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: 'Remove photo',
              child: GestureDetector(
                onTap: remove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: context.pc.textPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: context.pc.bg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final hasAny = existing.isNotEmpty || added.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAny)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md, top: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final p in existing) tile(p, () => onRemoveExisting(p)),
                  for (final p in added) tile(p, () => onRemoveAdded(p)),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: cameraLabel,
                icon: Icons.photo_camera_outlined,
                secondary: true,
                onPressed: () => _pick(context, ref, PhotoSource.camera),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: PrimaryButton(
                label: 'Gallery',
                icon: Icons.photo_library_outlined,
                secondary: true,
                onPressed: () => _pick(context, ref, PhotoSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        Text(
          'Kept on this phone only. Never uploaded.',
          style: context.tt.bodySmall!.copyWith(color: context.pc.textTertiary),
        ),
      ],
    );
  }
}

/// A small label above a form field group.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm),
    child: Text(text, style: context.tt.labelMedium),
  );
}

/// Back, or to Wealth when there is nothing to go back to (a deep link).
void leave(BuildContext context) {
  if (context.canPop()) {
    context.popOrHome();
  } else {
    context.go('/wealth');
  }
}

/// 12,345.678 style: thousands separators, up to [maxDecimals] decimals,
/// trailing zeros dropped.
String fmtNum(double v, {int maxDecimals = 3}) =>
    NumberFormat('#,##0.${'#' * maxDecimals}', 'en_US').format(v);
