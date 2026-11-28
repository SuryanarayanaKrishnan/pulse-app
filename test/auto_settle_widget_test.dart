import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/split_settle.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/repository.dart';
import 'package:pulse/features/splits/auto_settle.dart';

class _Repo implements PulseRepository {
  _Repo() {
    group = SplitGroup(
      id: 'g1',
      name: 'Synthetic trip',
      emoji: 'x',
      members: const [
        Member('me', 'You', Colors.teal),
        Member('t', 'Tariq Example', Colors.teal, phone: '+971500000001'),
      ],
      // Tariq's share is 50.00, paid by me.
      expenses: [
        SplitExpense(
          id: 'e1',
          title: 'Synthetic dinner',
          paidBy: 'me',
          amount: 100,
          participants: const ['me', 't'],
          date: DateTime(2026, 1, 1),
        ),
      ],
    );
  }
  late SplitGroup group;

  @override
  Future<List<SplitGroup>> splitGroups() async => [group];
  @override
  Future<SettlementRecord> markSettlementPaid(
    String groupId, {
    required String from,
    required String to,
    required double amount,
  }) async {
    final r = SettlementRecord(
      id: 's${group.settlements.length + 1}',
      from: from,
      to: to,
      amount: amount,
      date: DateTime(2026, 1, 2),
      status: SettlementStatus.awaitingConfirmation,
    );
    group = SplitGroup(
      id: group.id,
      name: group.name,
      emoji: group.emoji,
      members: group.members,
      expenses: group.expenses,
      settlements: [...group.settlements, r],
    );
    return r;
  }

  @override
  Future<SettlementRecord> confirmSettlement(String g, String id) async {
    final r = group.settlements
        .firstWhere((x) => x.id == id)
        .copyWith(status: SettlementStatus.confirmed);
    group = SplitGroup(
      id: group.id,
      name: group.name,
      emoji: group.emoji,
      members: group.members,
      expenses: group.expenses,
      settlements: [for (final x in group.settlements) x.id == id ? r : x],
    );
    return r;
  }

  @override
  Future<void> undoSettlement(String g, String id) async {
    group = SplitGroup(
      id: group.id,
      name: group.name,
      emoji: group.emoji,
      members: group.members,
      expenses: group.expenses,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Rec implements Analytics {
  final names = <String>[];
  @override
  void track(AnalyticsEvent e) => names.add(e.name);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<AutoSettleService> _pump(
  WidgetTester t,
  _Repo repo,
  _Rec rec,
  MemoryKvStore kv,
) async {
  await t.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: AutoSettleHost.messengerKey,
      home: const Scaffold(body: SizedBox()),
    ),
  );
  return AutoSettleService(
    repo: repo,
    analytics: rec,
    kv: kv,
    messenger: () => AutoSettleHost.messengerKey.currentState,
  );
}

/// Two pumps: the first starts the show animation, the second finishes it.
Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('confident match settles, shows Undo, and Undo reverts', (
    t,
  ) async {
    final repo = _Repo(), rec = _Rec();
    final svc = await _pump(t, repo, rec, MemoryKvStore());
    await t.runAsync(
      () => svc.handle(
        const Counterparty(
          name: 'Someone',
          direction: Direction.credit,
          phone: '0500000001',
        ),
        2000,
      ),
    );
    await _settle(t);
    expect(find.textContaining('paid you back'), findsOneWidget);
    expect(find.textContaining('30.00 still open'), findsOneWidget);
    expect(repo.group.settlements, hasLength(1));
    expect(rec.names, ['split_auto_settled', 'first_split_settled']);

    await t.tap(find.text('Undo'));
    await _settle(t);
    expect(repo.group.settlements, isEmpty);
    expect(rec.names, [
      'split_auto_settled',
      'first_split_settled',
      'split_settle_undone',
    ]);
  });

  testWidgets('unsure match asks once, remembers yes, then auto-settles', (
    t,
  ) async {
    final repo = _Repo(), rec = _Rec(), kv = MemoryKvStore();
    final svc = await _pump(t, repo, rec, kv);
    const fuzzy = Counterparty(
      name: 'TARIQ EXAMPLES',
      direction: Direction.credit,
    );
    await t.runAsync(() => svc.handle(fuzzy, 1000));
    await _settle(t);
    expect(find.textContaining('remember your answer'), findsOneWidget);
    expect(repo.group.settlements, isEmpty);
    expect(rec.names, ['split_settle_asked']);

    await t.runAsync(() async {
      await t.tap(find.text('Yes, settle'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await _settle(t);
    expect(repo.group.settlements, hasLength(1));

    // Same payer again: no prompt this time, straight to settled.
    await t.runAsync(() => svc.handle(fuzzy, 1000));
    await _settle(t);
    expect(find.textContaining('remember your answer'), findsNothing);
    expect(rec.names.where((n) => n == 'split_settle_asked'), hasLength(1));
    expect(rec.names.where((n) => n == 'split_auto_settled'), hasLength(2));
  });

  testWidgets('answering no is remembered and never asks again', (t) async {
    final repo = _Repo(), rec = _Rec(), kv = MemoryKvStore();
    final svc = await _pump(t, repo, rec, kv);
    const fuzzy = Counterparty(
      name: 'TARIQ EXAMPLES',
      direction: Direction.credit,
    );
    await t.runAsync(() => svc.handle(fuzzy, 1000));
    await _settle(t);
    await t.runAsync(() async {
      await t.tap(find.text('Not this'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await _settle(t);
    await t.runAsync(() => svc.handle(fuzzy, 1000));
    await _settle(t);
    expect(find.textContaining('remember your answer'), findsNothing);
    expect(repo.group.settlements, isEmpty);
    expect(rec.names, ['split_settle_asked']);
  });
}
