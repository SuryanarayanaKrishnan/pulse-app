import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/features/family/family_screen.dart';
import 'package:pulse/features/family/pending_invites.dart';

void main() {
  late PendingInvites store;
  setUp(() => store = PendingInvites(MemoryKvStore()));

  test('inviting the same phone twice adds one row', () async {
    final a = await store.add(
      name: 'Animulla',
      relation: 'Other',
      phoneInput: '050 123 4567',
    );
    final b = await store.add(
      name: 'Animulla K',
      relation: 'Other',
      phoneInput: '+971501234567',
    );
    expect(a.alreadyPending, isFalse);
    expect(b.alreadyPending, isTrue);
    expect(b.invite.id, a.invite.id);
    expect(await store.all(), hasLength(1));
    expect((await store.all()).single.phone, '+971501234567');
  });

  test('without a phone the same name counts as the same person', () async {
    await store.add(name: 'Noor', relation: 'Child');
    final again = await store.add(name: '  noor ', relation: 'Child');
    expect(again.alreadyPending, isTrue);
    expect(await store.all(), hasLength(1));
    final other = await store.add(name: 'Sara', relation: 'Partner');
    expect(other.alreadyPending, isFalse);
    expect(await store.all(), hasLength(2));
  });

  test(
    'cancel removes the invite and the person can be invited again',
    () async {
      final a = await store.add(
        name: 'Khalid',
        relation: 'Partner',
        phoneInput: '0551112222',
      );
      await store.cancel(a.invite.id);
      expect(await store.all(), isEmpty);
      final b = await store.add(
        name: 'Khalid',
        relation: 'Partner',
        phoneInput: '0551112222',
      );
      expect(b.alreadyPending, isFalse);
    },
  );

  test(
    'an invite is dropped once a member with that first name joined',
    () async {
      await store.add(name: 'Khalid Ali', relation: 'Partner');
      await store.add(name: 'Noor', relation: 'Child');
      await store.dropJoined(['Sara', 'khalid']);
      expect((await store.all()).map((p) => p.name), ['Noor']);
    },
  );

  test('survives a restart and ignores a corrupt store', () async {
    final kv = MemoryKvStore();
    await PendingInvites(kv).add(name: 'Omar', relation: 'Sibling');
    expect(await PendingInvites(kv).all(), hasLength(1));
    await kv.write('family.pending_invites', '{not json');
    expect(await PendingInvites(kv).all(), isEmpty);
  });

  test('the message carries the code and how to join', () {
    final m = inviteMessage(name: 'Omar', code: 'PULSE-HH1-AAAAA');
    expect(m, contains('PULSE-HH1-AAAAA'));
    expect(m, contains('Join with a code'));
    expect(m, startsWith('Hi Omar'));
  });
}
