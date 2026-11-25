import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/splits_store.dart';
import '../../data/models.dart';
import '../../data/phone.dart';
import '../../data/providers.dart';
import 'split_widgets.dart';
import 'splits_errors.dart';

const _emojis = ['👥', '🏠', '✈️', '🍽️', '🎉', '🛒'];

/// Opens the create-group sheet; resolves to the new group, or null.
Future<SplitGroup?> showCreateGroupSheet(BuildContext context) =>
    showPulseSheet<SplitGroup>(
      context,
      full: true,
      builder: (_) => const CreateGroupSheet(),
    );

/// Name a group, pick an emoji and add people (contacts or typed names).
/// Saved on the phone; works with no backend.
class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});
  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _name = TextEditingController();
  final _person = TextEditingController();
  final _people = <NewGroupMember>[];
  String _emoji = _emojis.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _person.dispose();
    super.dispose();
  }

  void _addTyped() {
    final n = _person.text.trim();
    if (n.isEmpty) return;
    setState(() {
      _people.add(NewGroupMember(name: n));
      _person.clear();
    });
  }

  Future<void> _create() async {
    _addTyped();
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the group a name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final g = await ref
          .read(repositoryProvider)
          .createSplitGroup(name: name, emoji: _emoji, members: _people);
      ref
          .read(analyticsProvider)
          .track(
            AnalyticsEvent.splitGroupCreated(
              members: _people.isEmpty
                  ? 'none'
                  : (_people.length <= 3 ? 'few' : 'many'),
            ),
          );
      Haptics.success();
      ref.invalidate(splitGroupsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(g);
      messenger?.showSnackBar(SnackBar(content: Text('Created ${g.name}.')));
    } catch (e, st) {
      final msg = reportSplitsError(
        ref,
        mounted ? context : null,
        SplitsAction.createGroup,
        e,
        st,
      );
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SheetScaffold(
      title: 'New group',
      subtitle: 'Split bills with friends. Saved on this phone.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('group-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Group name (Dubai trip, Flat 12...)',
            ),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final e in _emojis)
                Pill(
                  e,
                  selected: e == _emoji,
                  onTap: () => setState(() => _emoji = e),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Text('People', style: context.tt.bodySmall),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('group-person'),
                  controller: _person,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTyped(),
                  decoration: const InputDecoration(hintText: 'Add a name'),
                ),
              ),
              const SizedBox(width: Space.sm),
              IconButton(
                key: const Key('group-person-add'),
                tooltip: 'Add name',
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: _addTyped,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextAction(
              'Choose from contacts',
              onTap: () => showPulseSheet<void>(
                context,
                full: true,
                builder: (_) => ContactPickerSheet(
                  exclude: {for (final p in _people) ?p.phone},
                  onPicked: (picked) => setState(() => _people.addAll(picked)),
                ),
              ),
            ),
          ),
          if (_people.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final p in _people)
                  Pill(
                    p.phone == null
                        ? p.name
                        : '${p.name} · ${formatPhone(p.phone!)}',
                    selected: true,
                    icon: Icons.close_rounded,
                    onTap: () => setState(() => _people.remove(p)),
                  ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Space.md),
            Text(
              _error!,
              key: const Key('group-error'),
              style: context.tt.bodySmall!.copyWith(color: c.negative),
            ),
          ],
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Create group',
            loading: _busy,
            onPressed: _create,
          ),
        ],
      ),
    );
  }
}
