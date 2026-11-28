import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/kv_store.dart';
import '../../capture/providers.dart';
import '../../data/phone.dart';

/// Someone you passed the household code to who has not joined yet.
///
/// Pulse cannot know whether the message was read: the code travels through
/// WhatsApp, Messages or whatever you shared it with, never through our
/// servers (it carries the household key). So this is a note on this phone,
/// and it is honest about that: "waiting to join".
class PendingInvite {
  const PendingInvite({
    required this.id,
    required this.name,
    required this.relation,
    required this.createdAt,
    this.phone,
  });

  final String id;
  final String name;
  final String relation;

  /// E.164, when a number was given.
  final String? phone;
  final DateTime createdAt;

  /// Same person: same number, or (with no number on either side) the same
  /// name ignoring case and spacing.
  bool isSamePerson({required String name, String? phone}) {
    if (this.phone != null && phone != null) return this.phone == phone;
    if (this.phone != null || phone != null) return false;
    return _norm(this.name) == _norm(name);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'relation': relation,
    'phone': phone,
    'at': createdAt.toUtc().toIso8601String(),
  };

  static PendingInvite? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'], at = DateTime.tryParse('${j['at']}');
    if (id is! String || name is! String || at == null) return null;
    return PendingInvite(
      id: id,
      name: name,
      relation: j['relation'] is String ? j['relation'] as String : 'Other',
      phone: j['phone'] is String ? j['phone'] as String : null,
      createdAt: at,
    );
  }
}

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Whether an invite is already answered by a member who has joined (the
/// first name matches, ignoring case).
bool hasJoined(PendingInvite p, Iterable<String> memberNames) {
  final first = _norm(p.name).split(' ').first;
  return memberNames.any((m) => _norm(m).split(' ').first == first);
}

class InviteResult {
  const InviteResult(this.invite, {required this.alreadyPending});
  final PendingInvite invite;

  /// True when this person was already invited: nothing new was added.
  final bool alreadyPending;
}

/// The pending invites of this phone, kept in the small key-value store.
class PendingInvites {
  PendingInvites(this._kv, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _key = 'family.pending_invites';
  final KvStore _kv;
  final DateTime Function() _clock;

  Future<List<PendingInvite>> all() async {
    final raw = await _kv.read(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final e in list) ?PendingInvite.fromJson(e)];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _save(List<PendingInvite> l) =>
      _kv.write(_key, jsonEncode([for (final p in l) p.toJson()]));

  /// Notes an invite. Inviting the same person again changes nothing and says
  /// so, so the screen can offer to share the code again instead of adding a
  /// second row.
  Future<InviteResult> add({
    required String name,
    required String relation,
    String? phoneInput,
  }) async {
    final phone = phoneInput == null || phoneInput.trim().isEmpty
        ? null
        : toE164(phoneInput);
    final list = await all();
    final same = list
        .where((p) => p.isSamePerson(name: name, phone: phone))
        .firstOrNull;
    if (same != null) return InviteResult(same, alreadyPending: true);
    final now = _clock().toUtc();
    final p = PendingInvite(
      id: '${now.microsecondsSinceEpoch}',
      name: name.trim(),
      relation: relation,
      phone: phone,
      createdAt: now,
    );
    await _save([...list, p]);
    return InviteResult(p, alreadyPending: false);
  }

  Future<void> cancel(String id) async => _save([
    for (final p in await all())
      if (p.id != id) p,
  ]);

  /// Drops the invites that [memberNames] have answered.
  Future<void> dropJoined(Iterable<String> memberNames) async {
    final list = await all();
    final keep = [
      for (final p in list)
        if (!hasJoined(p, memberNames)) p,
    ];
    if (keep.length != list.length) await _save(keep);
  }
}

final pendingInvitesProvider = Provider<PendingInvites>(
  (ref) => PendingInvites(ref.watch(kvStoreProvider)),
);
