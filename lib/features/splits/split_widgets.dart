import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../../data/phone.dart';
import '../../data/providers.dart';
import 'contacts.dart';

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
    .showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );

/// Initial in a neutral circle; a small accent dot marks people on Pulse.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.size = 32, this.name});
  final Member? member;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final n = name ?? member?.name ?? '?';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Text(
              n.isEmpty ? '?' : n[0].toUpperCase(),
              style: context.tt.titleSmall!.copyWith(fontSize: size * 0.42),
            ),
          ),
          if (member?.onPulse ?? false)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> confirmReceived(
  BuildContext context,
  WidgetRef ref,
  SplitGroup g,
  SettlementRecord s,
) async {
  try {
    await ref.read(repositoryProvider).confirmSettlement(g.id, s.id);
    Haptics.success();
    ref.invalidate(splitGroupsProvider);
    if (context.mounted) {
      _toast(
        context,
        'Confirmed. ${g.member(s.from)?.name ?? 'They'} are settled up.',
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) _toast(context, e.message);
  }
}

Future<void> showAaniSheet(
  BuildContext context, {
  required SplitGroup group,
  required Member payee,
  required double amount,
}) => showPulseSheet<void>(
  context,
  builder: (_) => AaniSettleSheet(group: group, payee: payee, amount: amount),
);

/// Settle a debt over Aani. Aani has no third-party API, so the user pays in
/// their bank app with the details below, then tells us; the payee confirms.
class AaniSettleSheet extends ConsumerStatefulWidget {
  const AaniSettleSheet({
    super.key,
    required this.group,
    required this.payee,
    required this.amount,
  });
  final SplitGroup group;
  final Member payee;
  final double amount;

  @override
  ConsumerState<AaniSettleSheet> createState() => _AaniSettleSheetState();
}

class _AaniSettleSheetState extends ConsumerState<AaniSettleSheet> {
  bool _busy = false;

  String get _amountText => widget.amount.toStringAsFixed(2);

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    Haptics.light();
    if (mounted) _toast(context, '$what copied');
  }

  Future<void> _share() async {
    final p = widget.payee;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Aani payment to ${p.name}: AED $_amountText'
            '${p.phone == null ? '' : ' to ${formatPhone(p.phone!)}'}'
            ' (${widget.group.name})',
      ),
    );
  }

  Future<void> _paid() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .markSettlementPaid(
            widget.group.id,
            from: 'me',
            to: widget.payee.id,
            amount: widget.amount,
          );
      Haptics.success();
      ref.invalidate(splitGroupsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Marked as paid. ${widget.payee.name} will confirm.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final p = widget.payee;
    Widget copyButton(String text, String what) => Semantics(
      button: true,
      label: 'Copy $what',
      child: Pressable(
        onTap: () => _copy(text, what),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.copy_rounded, size: 20, color: c.accent),
        ),
      ),
    );
    return SheetScaffold(
      title: 'Settle with Aani',
      subtitle:
          'Pay ${p.name} from your bank app. Aani transfers arrive in seconds.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              ListRow(
                title: 'Amount',
                subtitle: Money.aed(widget.amount),
                titleStyle: context.tt.bodySmall,
                trailing: copyButton(_amountText, 'Amount'),
              ),
              ListRow(
                title: '${p.name}’s mobile',
                titleStyle: context.tt.bodySmall,
                subtitle: p.phone == null
                    ? 'Not saved. Ask ${p.name} for the number on their Aani account.'
                    : formatPhone(p.phone!),
                trailing: p.phone == null
                    ? null
                    : copyButton(p.phone!, 'Number'),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          for (final (i, step) in [
            'Open your bank app and choose Aani',
            'Send to the mobile number, with the amount above',
            'Come back and tap I’ve paid',
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}', style: context.tt.bodySmall),
                  ),
                  Expanded(child: Text(step, style: context.tt.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: Space.lg),
          PrimaryButton(label: 'I’ve paid', loading: _busy, onPressed: _paid),
          const SizedBox(height: Space.sm),
          PrimaryButton(
            label: 'Share details',
            secondary: true,
            icon: Icons.ios_share_rounded,
            onPressed: _share,
          ),
        ],
      ),
    );
  }
}

/// Pick group members from the address book and see who is already on Pulse.
class ContactPickerSheet extends ConsumerStatefulWidget {
  const ContactPickerSheet({super.key, required this.group});
  final SplitGroup group;
  @override
  ConsumerState<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends ConsumerState<ContactPickerSheet> {
  ContactsAccess? _access;
  List<DeviceContact> _contacts = const [];
  Set<String> _onPulse = const {};
  final _selected = <String, DeviceContact>{};
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final src = ref.read(contactsSourceProvider);
    try {
      final access = await src.requestAccess();
      if (access == ContactsAccess.denied) {
        if (mounted) setState(() => _access = access);
        return;
      }
      final list = await src.load();
      final existing = {for (final m in widget.group.members) ?m.phone};
      final fresh = [
        for (final c in list)
          if (!existing.contains(c.primaryPhone)) c,
      ];
      // Only SHA-256 hashes of E.164 numbers leave the device.
      final byHash = {
        for (final c in fresh)
          for (final p in c.phones) phoneHash(p): p,
      };
      final matched = await ref
          .read(repositoryProvider)
          .matchContacts(byHash.keys.toList())
          .catchError((_) => <String>{});
      if (!mounted) return;
      setState(() {
        _access = access;
        _contacts = fresh;
        _onPulse = {for (final h in matched) ?byHash[h]};
      });
    } catch (_) {
      if (mounted) setState(() => _access = ContactsAccess.denied);
    }
  }

  bool _isOnPulse(DeviceContact c) => c.phones.any(_onPulse.contains);

  Future<void> _add() async {
    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);
    try {
      for (final c in _selected.values) {
        await repo.addMember(
          widget.group.id,
          name: c.name.split(' ').first,
          phone: c.primaryPhone,
        );
      }
      Haptics.success();
      ref.invalidate(splitGroupsProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final q = _search.text.trim().toLowerCase();
    final shown =
        [
          for (final x in _contacts)
            if (q.isEmpty || x.name.toLowerCase().contains(q)) x,
        ]..sort((a, b) {
          final pa = _isOnPulse(a) ? 0 : 1, pb = _isOnPulse(b) ? 0 : 1;
          return pa != pb ? pa - pb : a.name.compareTo(b.name);
        });
    return SheetScaffold(
      title: 'Add people',
      subtitle:
          'From your contacts. To show who is on Pulse, only a one-way '
          'fingerprint of each number is checked.',
      child: switch (_access) {
        null => const Padding(
          padding: EdgeInsets.all(Space.xxl),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        ContactsAccess.denied => EmptyState(
          icon: Icons.contacts_outlined,
          title: 'Contacts are off',
          message: 'Allow contacts access in Settings to add people quickly.',
          action: TextAction(
            'Try again',
            onTap: () {
              setState(() => _access = null);
              _load();
            },
          ),
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: Icon(Icons.search_rounded, color: c.textTertiary),
              ),
            ),
            const SizedBox(height: Space.sm),
            RowGroup(
              padding: EdgeInsets.zero,
              indent: ListRow.leadingInset,
              children: [
                for (final x in shown)
                  ListRow(
                    dense: true,
                    leading: MemberAvatar(
                      Member('', x.name, c.accent, onPulse: _isOnPulse(x)),
                    ),
                    title: x.name,
                    subtitle: _isOnPulse(x)
                        ? 'On Pulse · ${formatPhone(x.primaryPhone!)}'
                        : formatPhone(x.primaryPhone!),
                    trailing: AnimatedSwitcher(
                      duration: Motion.fast,
                      child: Icon(
                        _selected.containsKey(x.primaryPhone)
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        key: ValueKey(_selected.containsKey(x.primaryPhone)),
                        color: _selected.containsKey(x.primaryPhone)
                            ? c.accent
                            : c.textTertiary,
                      ),
                    ),
                    onTap: () {
                      Haptics.tap();
                      setState(() {
                        final k = x.primaryPhone!;
                        _selected.containsKey(k)
                            ? _selected.remove(k)
                            : _selected[k] = x;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
            PrimaryButton(
              label: _selected.isEmpty
                  ? 'Add people'
                  : 'Add ${_selected.length} ${_selected.length == 1 ? 'person' : 'people'}',
              loading: _busy,
              onPressed: _selected.isEmpty ? null : _add,
            ),
          ],
        ),
      },
    );
  }
}
