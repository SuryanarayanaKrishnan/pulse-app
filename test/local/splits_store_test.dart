import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/splits_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/splits_util.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late PulseDatabase db;
  late LocalSplitsStore store;
  setUp(() {
    db = PulseDatabase(NativeDatabase.memory());
    store = LocalSplitsStore(db);
  });
  tearDown(() => db.close());

  test('create group with contacts and typed names; you are first', () async {
    final g = await store.createGroup(
      name: ' Trip ',
      emoji: '✈️',
      members: const [
        NewGroupMember(name: 'Sara', phone: '+971552345678'),
        NewGroupMember(name: 'Omar'),
      ],
    );
    expect(g.name, 'Trip');
    expect(g.members.map((m) => m.name), ['You', 'Sara', 'Omar']);
    expect(g.members[1].phone, '+971552345678');
    expect((await store.groups()).single.id, g.id);
  });

  test('a blank name is rejected and nothing is saved', () async {
    await expectLater(store.createGroup(name: '  '), throwsArgumentError);
    expect(await store.groups(), isEmpty);
  });

  test('expense, settle, confirm and undo round-trip', () async {
    final g = await store.createGroup(
      name: 'Flat',
      members: const [NewGroupMember(name: 'Ali')],
    );
    final ali = g.members.last.id;
    await store.addExpense(
      g.id,
      SplitExpense(
        id: 'new1',
        title: 'Dinner',
        paidBy: 'me',
        amount: 100.5,
        participants: ['me', ali],
        date: DateTime(2026, 1, 1),
      ),
    );
    var got = await store.group(g.id);
    expect(got.expenses.single.amount, 100.5);
    expect(groupBalances(got)['me'], closeTo(50.25, 0.001));

    final s = await store.markPaid(g.id, from: ali, to: 'me', amount: 50.25);
    expect(s.status, SettlementStatus.awaitingConfirmation);
    await store.confirm(g.id, s.id);
    got = await store.group(g.id);
    expect(got.settlements.single.status, SettlementStatus.confirmed);
    await store.undo(g.id, s.id);
    expect((await store.group(g.id)).settlements, isEmpty);
  });

  test('a member can be added later', () async {
    final g = await store.createGroup(name: 'G');
    await store.addMember(g.id, name: 'Lina');
    expect((await store.group(g.id)).members.map((m) => m.name), [
      'You',
      'Lina',
    ]);
  });
}
