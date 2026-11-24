import 'package:material_ui/material_ui.dart';

import '../../core/household/household_models.dart';
import '../../core/theme/tokens.dart';
import '../../data/household_service.dart';
import '../../data/models.dart';

/// "Mine", "Omar's", "Shared": a stored (local) owner as words.
String ownerLabel(JointData j, String localOwner) {
  if (localOwner == Owner.me) return 'Mine';
  if (localOwner == Owner.shared) return 'Shared';
  return "${j.nameOf(localOwner)}'s";
}

/// Same, for an absolute owner (a member id or `shared`) as seen by [j].me.
String absOwnerLabel(JointData j, String abs) =>
    ownerLabel(j, Owner.local(abs, j.me));

/// One-line description of an item's sharing, e.g. "Shared" or
/// "Mine · Private".
String sharingCaption(JointData j, String localOwner, bool isPrivate) =>
    isPrivate ? '${ownerLabel(j, localOwner)} · Private' : ownerLabel(j, localOwner);

/// The category for an id, falling back to a named stand-in.
SpendCategory categoryFor(Iterable<SpendCategory> all, String id) =>
    all.where((c) => c.id == id).firstOrNull ?? SpendCategory(id, id.isEmpty ? 'Other' : id);

/// A round initial for a member. [me] gets the accent fill.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.name, {super.key, this.me = false, this.size = 32, this.shared = false});
  final String name;
  final bool me, shared;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: me ? c.accent : c.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: shared
          ? Icon(Icons.people_alt_outlined, size: size * 0.52, color: c.textPrimary)
          : Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: context.tt.labelLarge!.copyWith(
                color: me ? c.onAccent : c.textPrimary,
                fontSize: size * 0.42,
              ),
            ),
    );
  }
}

/// A member's avatar by absolute owner.
Widget ownerAvatar(JointData j, String abs, {double size = 32}) => abs == Owner.shared
    ? MemberAvatar('', shared: true, size: size)
    : MemberAvatar(j.nameOf(abs), me: abs == j.me, size: size);

/// A quiet pill naming who an item belongs to.
class OwnerChip extends StatelessWidget {
  const OwnerChip(this.label, {super.key, this.isPrivate = false});
  final String label;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate) ...[
            Icon(Icons.lock_outline_rounded, size: 11, color: c.textSecondary),
            const SizedBox(width: 3),
          ],
          Text(label, style: context.tt.labelSmall!.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// How one of my Wealth rows is shared ("Shared", "Mine · Private"), or null
/// when it is plain mine.
String? lineCaption(JointData j, String id) {
  final l = j.lines.where((l) => l.id == id && (l.owner == j.me || l.owner == Owner.shared || j.members.any((m) => m.id == l.owner))).firstOrNull;
  if (l == null) return null;
  final local = Owner.local(l.owner, j.me);
  if (local == Owner.me && !l.isPrivate) return null;
  return sharingCaption(j, local, l.isPrivate);
}
