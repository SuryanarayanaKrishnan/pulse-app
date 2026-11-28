import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/painting.dart' show Color;

import '../models.dart';
import 'database.dart';
import 'ids.dart';

/// A person typed or picked while creating a group.
class NewGroupMember {
  const NewGroupMember({required this.name, this.phone});
  final String name;

  /// E.164, when picked from contacts.
  final String? phone;
}

const _palette = [
  Color(0xFF5BC2A8),
  Color(0xFF7C8CF8),
  Color(0xFFF2A65A),
  Color(0xFFE56B8A),
  Color(0xFF6BB5E8),
  Color(0xFFB48CE6),
];

/// Insertion order within one timestamp.
const _rowid = CustomExpression<int>('rowid');

int _minor(double v) => (v * 100).round();
double _major(int v) => v / 100;

/// The splits ledger on the on-device database: groups, members, expenses and
/// settlements work with no backend. Rows carry `synced_at` so a later sync
/// can push exactly what the server has not seen.
class LocalSplitsStore {
  LocalSplitsStore(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final PulseDatabase db;
  final DateTime Function() _clock;

  Future<bool> hasGroup(String id) async =>
      (await (db.select(db.splitGroups)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .getSingleOrNull()) !=
      null;

  Future<List<SplitGroup>> groups() async {
    final gs =
        await (db.select(db.splitGroups)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (_) => OrderingTerm.desc(_rowid),
              ]))
            .get();
    final out = <SplitGroup>[];
    for (final g in gs) {
      out.add(await _load(g));
    }
    return out;
  }

  Future<SplitGroup> group(String id) async {
    final g = await (db.select(
      db.splitGroups,
    )..where((t) => t.id.equals(id))).getSingle();
    return _load(g);
  }

  Future<SplitGroup> _load(SplitGroupRow g) async {
    final members =
        await (db.select(db.splitMembers)
              ..where((t) => t.groupId.equals(g.id))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (_) => OrderingTerm.asc(_rowid),
              ]))
            .get();
    final expenses =
        await (db.select(db.splitExpenses)
              ..where((t) => t.groupId.equals(g.id))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    final settlements =
        await (db.select(db.splitSettlements)
              ..where((t) => t.groupId.equals(g.id))
              ..orderBy([(t) => OrderingTerm.asc(t.date)]))
            .get();
    // "me" first, then in the order people were added.
    final ms = [
      for (final m in members)
        if (m.id == 'me') m,
      for (final m in members)
        if (m.id != 'me') m,
    ];
    return SplitGroup(
      id: g.id,
      name: g.name,
      emoji: g.emoji,
      members: [for (final m in ms) _member(m)],
      expenses: [for (final e in expenses) _expense(e)],
      settlements: [for (final s in settlements) _settlement(s)],
    );
  }

  Member _member(SplitMemberRow m) => Member(
    m.id,
    m.name,
    Color(m.colorValue),
    phone: m.phone,
    onPulse: m.onPulse,
    ibanTail: m.ibanTail,
  );

  SplitExpense _expense(SplitExpenseRow e) => SplitExpense(
    id: e.id,
    title: e.title,
    paidBy: e.paidBy,
    amount: _major(e.amountMinor),
    participants: [
      for (final p in jsonDecode(e.participants) as List) p as String,
    ],
    date: e.date,
    transactionId: e.transactionId,
    shares: e.shares == null
        ? null
        : {
            for (final en in (jsonDecode(e.shares!) as Map).entries)
              en.key as String: _major((en.value as num).toInt()),
          },
  );

  SettlementRecord _settlement(SplitSettlementRow s) => SettlementRecord(
    id: s.id,
    from: s.fromMember,
    to: s.toMember,
    amount: _major(s.amountMinor),
    date: s.date,
    status: s.status == 'awaitingConfirmation'
        ? SettlementStatus.awaitingConfirmation
        : SettlementStatus.confirmed,
    method: s.method,
  );

  /// Creates a group with you as `me` plus [members], in one transaction.
  Future<SplitGroup> createGroup({
    required String name,
    String emoji = '👥',
    List<NewGroupMember> members = const [],
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Give the group a name.');
    final id = newId('g');
    final now = _clock();
    await db.transaction(() async {
      await db
          .into(db.splitGroups)
          .insert(
            SplitGroupsCompanion.insert(
              id: id,
              name: clean,
              emoji: Value(emoji),
              createdAt: Value(now),
            ),
          );
      await db
          .into(db.splitMembers)
          .insert(
            SplitMembersCompanion.insert(
              groupId: id,
              id: 'me',
              name: 'You',
              colorValue: _palette.first.toARGB32(),
              onPulse: const Value(true),
              createdAt: Value(now),
            ),
          );
      for (final m in members) {
        await _insertMember(id, m.name, m.phone, now);
      }
    });
    return group(id);
  }

  Future<Member> _insertMember(
    String groupId,
    String name,
    String? phone,
    DateTime now,
  ) async {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('A member needs a name.');
    final count = await (db.select(
      db.splitMembers,
    )..where((t) => t.groupId.equals(groupId))).get();
    final color = _palette[count.length % _palette.length];
    final id = newId('m');
    await db
        .into(db.splitMembers)
        .insert(
          SplitMembersCompanion.insert(
            groupId: groupId,
            id: id,
            name: n,
            colorValue: color.toARGB32(),
            phone: Value(phone),
            createdAt: Value(now),
          ),
        );
    return Member(id, n, color, phone: phone);
  }

  Future<Member> addMember(
    String groupId, {
    required String name,
    String? phone,
  }) => _insertMember(groupId, name, phone, _clock());

  Future<SplitExpense> addExpense(String groupId, SplitExpense e) async {
    final id = e.id.startsWith('new') || e.id.isEmpty ? newId('e') : e.id;
    await db
        .into(db.splitExpenses)
        .insert(
          SplitExpensesCompanion.insert(
            id: id,
            groupId: groupId,
            title: e.title,
            paidBy: e.paidBy,
            amountMinor: _minor(e.amount),
            participants: jsonEncode(e.participants),
            shares: Value(
              e.shares == null
                  ? null
                  : jsonEncode({
                      for (final en in e.shares!.entries)
                        en.key: _minor(en.value),
                    }),
            ),
            date: e.date,
            transactionId: Value(e.transactionId),
          ),
        );
    return SplitExpense(
      id: id,
      title: e.title,
      paidBy: e.paidBy,
      amount: _major(_minor(e.amount)),
      participants: e.participants,
      date: e.date,
      shares: e.shares,
      transactionId: e.transactionId,
    );
  }

  Future<SettlementRecord> markPaid(
    String groupId, {
    required String from,
    required String to,
    required double amount,
  }) async {
    final rec = SettlementRecord(
      id: newId('s'),
      from: from,
      to: to,
      amount: _major(_minor(amount)),
      date: _clock(),
      status: SettlementStatus.awaitingConfirmation,
    );
    await db
        .into(db.splitSettlements)
        .insert(
          SplitSettlementsCompanion.insert(
            id: rec.id,
            groupId: groupId,
            fromMember: from,
            toMember: to,
            amountMinor: _minor(amount),
            date: rec.date,
            status: const Value('awaitingConfirmation'),
          ),
        );
    return rec;
  }

  Future<SettlementRecord> confirm(String groupId, String settlementId) async {
    await (db.update(db.splitSettlements)
          ..where((t) => t.id.equals(settlementId) & t.groupId.equals(groupId)))
        .write(const SplitSettlementsCompanion(status: Value('confirmed')));
    final row = await (db.select(
      db.splitSettlements,
    )..where((t) => t.id.equals(settlementId))).getSingle();
    return _settlement(row);
  }

  Future<void> undo(String groupId, String settlementId) => (db.delete(
    db.splitSettlements,
  )..where((t) => t.id.equals(settlementId) & t.groupId.equals(groupId))).go();
}
