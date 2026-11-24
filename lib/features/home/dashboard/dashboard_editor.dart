import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import 'dashboard_controller.dart';
import 'dashboard_layout.dart';

/// The dashboard chips: tap to switch. In Customise mode a "New" chip joins.
class DashboardChips extends ConsumerWidget {
  const DashboardChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(dashboardProvider);
    final ctl = ref.read(dashboardProvider.notifier);
    final l = s.layout;
    if (l.dashboards.length < 2 && !s.editing) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: screenPad,
          children: [
            for (final d in l.dashboards) ...[
              Pill(
                d.name,
                selected: d.id == l.activeId,
                onTap: () => ctl.select(d.id),
              ),
              const SizedBox(width: Space.sm),
            ],
            if (s.editing && l.canAddDashboard)
              Pill(
                'New',
                icon: Icons.add_rounded,
                onTap: () async {
                  final name = await showNameSheet(
                    context,
                    title: 'New dashboard',
                    initial: '',
                    action: 'Create',
                  );
                  if (name != null) ctl.addDashboard(name);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Customise mode: reorder, resize, remove and add the active dashboard's
/// widgets. Changes apply and save as you make them.
class DashboardEditor extends ConsumerWidget {
  const DashboardEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final s = ref.watch(dashboardProvider);
    final ctl = ref.read(dashboardProvider.notifier);
    final d = s.layout.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            Space.md,
          ),
          child: Text(
            'Hold and drag to reorder. Tap a size to switch it.',
            style: context.tt.bodyMedium,
          ),
        ),
        if (d.widgets.isEmpty)
          Padding(
            padding: screenPad,
            child: SurfaceCard(
              child: Text(
                'Nothing here yet. Add a widget below.',
                style: context.tt.bodyMedium,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: screenPad,
            buildDefaultDragHandles: false,
            itemCount: d.widgets.length,
            onReorderStart: (_) => Haptics.tap(),
            onReorderEnd: (_) => Haptics.light(),
            onReorderItem: ctl.reorder,
            proxyDecorator: (child, _, animation) => AnimatedBuilder(
              animation: animation,
              builder: (_, _) => Material(
                color: Colors.transparent,
                elevation: 6 * Curves.easeOut.transform(animation.value),
                shadowColor: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(Radii.lg),
                child: child,
              ),
            ),
            itemBuilder: (context, i) {
              final w = d.widgets[i];
              return Padding(
                key: ValueKey(w.kind),
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: _EditTile(
                  index: i,
                  widget: w,
                  onResize: () {
                    Haptics.tap();
                    ctl.resize(
                      w.kind,
                      w.size == WidgetSize.regular
                          ? WidgetSize.compact
                          : WidgetSize.regular,
                    );
                  },
                  onRemove: () {
                    Haptics.light();
                    ctl.remove(w.kind);
                  },
                ),
              );
            },
          ),
        if (d.available.isNotEmpty) ...[
          const SectionHeader('Add a widget'),
          RowGroup(
            children: [
              for (final k in d.available)
                ListRow(
                  dense: true,
                  title: k.label,
                  trailing: Icon(
                    Icons.add_circle_outline_rounded,
                    color: c.accent,
                    size: 22,
                  ),
                  onTap: () {
                    Haptics.tap();
                    ctl.add(k);
                  },
                ),
            ],
          ),
        ],
        const SectionHeader('This dashboard'),
        RowGroup(
          children: [
            ListRow(
              dense: true,
              title: 'Rename',
              subtitle: d.name,
              chevron: true,
              onTap: () async {
                final name = await showNameSheet(
                  context,
                  title: 'Rename dashboard',
                  initial: d.name,
                  action: 'Save',
                );
                if (name != null) ctl.renameActive(name);
              },
            ),
            if (s.layout.canDeleteDashboard)
              ListRow(
                dense: true,
                title: 'Delete dashboard',
                titleStyle: context.tt.bodyLarge!.copyWith(color: c.negative),
                onTap: () {
                  Haptics.medium();
                  ctl.deleteActive();
                },
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.index,
    required this.widget,
    required this.onResize,
    required this.onRemove,
  });
  final int index;
  final DashWidget widget;
  final VoidCallback onResize, onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final compact = widget.size == WidgetSize.compact;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: Space.xs, right: Space.xs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: 'Reorder ${widget.kind.label}',
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: c.textTertiary,
                  size: 22,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              widget.kind.label,
              style: context.tt.bodyLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            button: true,
            label:
                '${widget.kind.label} size, ${widget.size.name}. Tap to change',
            child: Pressable(
              onTap: onResize,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  compact ? 'Compact' : 'Regular',
                  style: context.tt.labelMedium,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove ${widget.kind.label}',
            child: Pressable(
              onTap: onRemove,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: c.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for a dashboard name. Returns the cleaned name, or null if dismissed.
Future<String?> showNameSheet(
  BuildContext context, {
  required String title,
  required String initial,
  required String action,
}) => showPulseSheet<String>(
  context,
  useRootNavigator: true,
  builder: (_) => _NameSheet(title: title, initial: initial, action: action),
);

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.title,
    required this.initial,
    required this.action,
  });
  final String title, initial, action;
  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _done() {
    if (_c.text.trim().isEmpty) return;
    Navigator.of(context).pop(_c.text);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: widget.title,
    subtitle: 'Like "Everyday" or "Month end". It stays on this phone.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            LengthLimitingTextInputFormatter(DashboardLayout.maxNameLength),
          ],
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (_) => _done(),
        ),
        const SizedBox(height: Space.lg),
        PrimaryButton(label: widget.action, onPressed: _done),
      ],
    ),
  );
}
