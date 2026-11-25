import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/tokens.dart';
import '../core/widgets/widgets.dart';
import 'annotate.dart';
import 'report.dart';
import 'transport.dart';

/// The calm sheet testers see after a shake (or from Settings): the
/// screenshot with a few marking tools, a note, and a plain list of exactly
/// what will be attached.
class BugReportSheet extends StatefulWidget {
  const BugReportSheet({
    super.key,
    required this.device,
    required this.logLines,
    required this.local,
    this.screenshot,
    this.issue,
    this.onSent,
    this.now,
  });

  final ui.Image? screenshot;
  final DeviceSnapshot device;
  final List<String> logLines;
  final BugReportTransport local;

  /// Null or unavailable: reports go through the share sheet only.
  final BugReportTransport? issue;
  final void Function(DeliveryMethod method)? onSent;
  final DateTime Function()? now;

  @override
  State<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<BugReportSheet> {
  final _note = TextEditingController();
  final _ann = AnnotationController();
  BugCategory _category = BugCategory.bug;
  bool _includeShot = true;
  bool _annotating = false;
  bool _showLog = false;
  bool _busy = false;
  String? _message;
  ui.Image? _coarse;

  bool get _hasShot => widget.screenshot != null;
  bool get _shotOn => _hasShot && _includeShot;
  bool get _issueReady => widget.issue?.available ?? false;

  @override
  void initState() {
    super.initState();
    _ann.addListener(() => setState(() {}));
    final s = widget.screenshot;
    if (s != null) {
      pixelate(s).then((c) {
        if (mounted) setState(() => _coarse = c);
      }).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _ann.dispose();
    _coarse?.dispose();
    super.dispose();
  }

  Future<BugReport> _buildReport() async {
    Uint8List? png;
    final s = widget.screenshot;
    if (_shotOn && s != null) {
      png = await renderAnnotatedPng(image: s, coarse: _coarse, controller: _ann);
    }
    return BugReport(
      category: _category,
      note: _note.text,
      device: widget.device,
      logLines: widget.logLines,
      createdAt: (widget.now ?? DateTime.now)(),
      screenshotPng: png,
    );
  }

  Future<void> _deliver({required bool viaIssue}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final report = await _buildReport();
    var outcome = await (viaIssue ? widget.issue! : widget.local).send(report);
    if (!outcome.ok && viaIssue) {
      if (mounted) setState(() => _message = 'Could not reach the report service. Opening the share sheet instead.');
      outcome = await widget.local.send(report);
    }
    if (!mounted) return;
    if (outcome.ok) {
      widget.onSent?.call(outcome.method);
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(
        content: Text(outcome.method == DeliveryMethod.issue ? 'Thanks, your report was sent' : 'Thanks for the report'),
      ));
    } else {
      setState(() {
        _busy = false;
        _message = 'Something went wrong. Try again in a moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_annotating) return _annotateView(context);
    final c = context.pc;
    return SheetScaffold(
      title: 'Report a bug',
      subtitle: 'Thank you. This goes only where you send it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.sm,
            children: [
              for (final cat in BugCategory.values)
                ChoiceChip(
                  key: Key('bug-category-${cat.name}'),
                  label: Text(cat.label),
                  selected: _category == cat,
                  onSelected: (_) => setState(() => _category = cat),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          TextField(
            key: const Key('bug-note'),
            controller: _note,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What happened, or what could be better? Please leave out names, amounts and account numbers.',
            ),
          ),
          const SizedBox(height: Space.md),
          _shotSection(context),
          const SizedBox(height: Space.lg),
          _preview(context),
          if (_message != null) ...[
            const SizedBox(height: Space.md),
            Text(_message!, key: const Key('bug-message'), style: context.tt.bodyMedium?.copyWith(color: c.warning)),
          ],
          const SizedBox(height: Space.lg),
          if (_issueReady) ...[
            PrimaryButton(
              key: const Key('bug-send'),
              label: 'Send report',
              icon: Icons.send_rounded,
              loading: _busy,
              onPressed: () => _deliver(viaIssue: true),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              key: const Key('bug-share'),
              label: 'Share instead',
              secondary: true,
              onPressed: _busy ? null : () => _deliver(viaIssue: false),
            ),
          ] else ...[
            PrimaryButton(
              key: const Key('bug-share'),
              label: 'Share report',
              icon: Icons.ios_share_rounded,
              loading: _busy,
              onPressed: () => _deliver(viaIssue: false),
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Opens the share sheet so you can send it by Messages, email or any app you like.',
              style: context.tt.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shotSection(BuildContext context) {
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _switchRow(
          key: const Key('bug-include-screenshot'),
          title: 'Include screenshot',
          subtitle: _hasShot ? null : 'A screenshot could not be taken here.',
          value: _shotOn,
          onChanged: _hasShot ? (v) => setState(() => _includeShot = v) : null,
        ),
        if (_shotOn) ...[
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.visibility_off_outlined, size: 18, color: c.textSecondary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'The screenshot may show balances or names. Cover anything private before you send.',
                    style: context.tt.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: _canvas(interactive: false),
            ),
          ),
          const SizedBox(height: Space.md),
          PrimaryButton(
            key: const Key('bug-annotate'),
            label: _ann.hasMarks ? 'Edit marks' : 'Draw or hide something',
            icon: Icons.draw_outlined,
            secondary: true,
            onPressed: () => setState(() => _annotating = true),
          ),
          _switchRow(
            key: const Key('bug-mask-all'),
            title: 'Mask all text in screenshot',
            subtitle: 'Hides numbers and words by pixelating the whole picture.',
            value: _ann.maskAll,
            onChanged: _ann.setMaskAll,
          ),
        ],
      ],
    );
  }

  Widget _switchRow({
    required Key key,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.tt.titleMedium),
                if (subtitle != null)
                  Text(subtitle, style: context.tt.bodySmall?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Switch(key: key, value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _canvas({required bool interactive}) {
    final s = widget.screenshot!;
    final aspect = s.width / s.height;
    return AspectRatio(
      aspectRatio: aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: context.pc.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: LayoutBuilder(
            builder: (context, box) {
              Offset norm(Offset p) => Offset(p.dx / box.maxWidth, p.dy / box.maxHeight);
              final paint = CustomPaint(
                key: const Key('bug-canvas'),
                size: Size.infinite,
                painter: AnnotationPainter(image: s, coarse: _coarse, controller: _ann),
              );
              if (!interactive) return paint;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _ann.begin(norm(d.localPosition)),
                onPanUpdate: (d) => _ann.extend(norm(d.localPosition)),
                onPanEnd: (_) => _ann.end(),
                child: paint,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _annotateView(BuildContext context) {
    final c = context.pc;
    final maxH = MediaQuery.sizeOf(context).height * 0.5;
    return SheetScaffold(
      title: 'Mark the screenshot',
      subtitle: 'Draw to point something out. Use the box to hide anything private.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: ConstrainedBox(constraints: BoxConstraints(maxHeight: maxH), child: _canvas(interactive: true))),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                key: const Key('bug-tool-pen'),
                avatar: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Pen'),
                selected: _ann.tool == AnnotateTool.pen,
                onSelected: (_) => _ann.setTool(AnnotateTool.pen),
              ),
              ChoiceChip(
                key: const Key('bug-tool-blur'),
                avatar: const Icon(Icons.blur_on_rounded, size: 16),
                label: const Text('Hide box'),
                selected: _ann.tool == AnnotateTool.blur,
                onSelected: (_) => _ann.setTool(AnnotateTool.blur),
              ),
              for (var i = 0; i < AnnotationController.penColors.length; i++)
                Semantics(
                  label: 'Pen colour ${i + 1}',
                  button: true,
                  child: GestureDetector(
                    key: Key('bug-color-$i'),
                    onTap: () => _ann.setColor(AnnotationController.penColors[i]),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AnnotationController.penColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: _ann.penColor == AnnotationController.penColors[i] && _ann.tool == AnnotateTool.pen ? 3 : 1,
                          color: _ann.penColor == AnnotationController.penColors[i] && _ann.tool == AnnotateTool.pen ? c.textPrimary : c.border,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              TextButton.icon(
                key: const Key('bug-undo'),
                onPressed: _ann.hasMarks ? _ann.undo : null,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Undo'),
              ),
              TextButton(
                key: const Key('bug-clear'),
                onPressed: _ann.hasMarks ? _ann.clear : null,
                child: const Text('Clear'),
              ),
              const Spacer(),
              PrimaryButton(
                key: const Key('bug-annotate-done'),
                label: 'Done',
                expand: false,
                onPressed: () => setState(() => _annotating = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final c = context.pc;
    final d = widget.device;
    Widget item(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.tt.bodyMedium)),
        ],
      ),
    );
    final marks = _ann.penCount + _ann.blurCount;
    final shot = !_hasShot
        ? 'No screenshot'
        : !_includeShot
        ? 'Screenshot left out'
        : [
            'Screenshot',
            if (_ann.maskAll) 'all text masked',
            if (marks > 0) '$marks ${marks == 1 ? 'mark' : 'marks'}',
          ].join(', ');
    return Container(
      key: const Key('bug-preview'),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.isDark ? c.surface : c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What will be attached', style: context.tt.titleMedium),
          const SizedBox(height: Space.sm),
          item(Icons.smartphone_rounded, 'Pulse ${d.appVersion} (${d.build}), ${d.platform} ${d.osVersion}'),
          item(Icons.layers_outlined, 'Screen ${d.route}, ${d.locale}, ${d.theme} theme'),
          item(Icons.image_outlined, shot),
          item(
            Icons.list_alt_rounded,
            'Activity log, ${widget.logLines.length} ${widget.logLines.length == 1 ? 'line' : 'lines'}: screens, event names and errors only. Numbers, amounts, names and contacts are removed.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('bug-toggle-log'),
              onPressed: () => setState(() => _showLog = !_showLog),
              child: Text(_showLog ? 'Hide log' : 'View log'),
            ),
          ),
          if (_showLog)
            Container(
              key: const Key('bug-log-view'),
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(color: c.surfaceElevated, borderRadius: BorderRadius.circular(Radii.sm)),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.logLines.isEmpty ? 'Nothing logged yet.' : widget.logLines.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.35),
                ),
              ),
            ),
          const SizedBox(height: Space.xs),
          Text(
            'Your note and the details above are all that is sent.',
            style: context.tt.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
