import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/vault/release.dart';
import 'package:pulse/core/vault/vault_models.dart';

/// The whole story, with a clock: an owner seals a file for her husband,
/// keeps using the app, then goes silent.
void main() {
  final day0 = DateTime.utc(2026, 1, 1);
  DateTime day(int n) => day0.add(Duration(days: n));

  VaultEntry e(String id, VaultType t, String inst, String where) => VaultEntry(
    id: id,
    type: t,
    institution: inst,
    whereToFind: where,
    createdAt: day0,
    updatedAt: day0,
  );

  final entries = [
    e('1', VaultType.bank, 'Mashreq', 'Statements in the grey folder'),
    e('2', VaultType.insurance, 'Sukoon', 'Policy in the safe, agent Ravi'),
  ];
  final husband = Nominee(id: 'h1', name: 'Karim', createdAt: day0);

  test('silence for the interval releases the file; activity postpones it; nobody opens it alone', () async {
    final relay = InMemoryInactivityRelay();
    final kit = await VaultSeal.createKit(
      ownerName: 'Leila',
      nominee: husband,
      entries: entries,
      now: day(0),
      random: Random(10),
    );
    await relay.arm(
      nomineeId: husband.id,
      sealedFile: kit.sealedFile,
      claimCodeHash: kit.claimCodeHash,
      intervalDays: 90,
      now: day(0),
    );

    // The server holds only ciphertext and a hash.
    for (final s in relay.storedStrings) {
      expect(s, isNot(contains('Mashreq')));
      expect(s, isNot(contains(kit.claimCode)));
    }

    // Day 30: too early, even with the right code.
    var r = await relay.claim(
      nomineeId: husband.id,
      claimCode: kit.claimCode,
      now: day(30),
    );
    expect(r, isA<ClaimNotYet>().having((x) => x.daysLeft, 'daysLeft', 60));

    // Leila opens the app on day 80: the countdown restarts.
    await relay.heartbeat(day(80));
    r = await relay.claim(
      nomineeId: husband.id,
      claimCode: kit.claimCode,
      now: day(150),
    );
    expect(
      r,
      isA<ClaimNotYet>().having((x) => x.daysLeft, 'daysLeft', 20),
      reason: '80 + 90 = 170',
    );

    // Silence from day 80 on. Day 171: released, but only with the right code.
    r = await relay.claim(
      nomineeId: husband.id,
      claimCode: 'WRONG-CODE-0000',
      now: day(171),
    );
    expect(r, isA<ClaimWrongCode>());
    r = await relay.claim(
      nomineeId: husband.id,
      claimCode: kit.claimCode.toLowerCase(),
      now: day(171),
    );
    expect(r, isA<ClaimReleased>());
    final file = (r as ClaimReleased).sealedFile;

    // The file alone is not enough, and neither is the claim code or one share.
    expect(
      VaultSeal.open(file, [kit.nomineeShare]),
      throwsA(isA<VaultOpenException>()),
    );
    expect(
      VaultSeal.open(file, [kit.claimCode, kit.nomineeShare]),
      throwsA(isA<VaultOpenException>()),
    );

    // Karim's share plus the escrow share (held by her sister) opens it.
    final opened = await VaultSeal.open(file, [
      kit.nomineeShare,
      kit.escrowShare,
    ]);
    expect(opened.nomineeName, 'Karim');
    expect(
      opened.entries.map((x) => x.institution),
      unorderedEquals(['Mashreq', 'Sukoon']),
    );
    // The owner's own share plus the escrow share also works (she can recover it herself).
    expect(
      (await VaultSeal.open(file, [kit.ownerShare, kit.escrowShare])).entries,
      hasLength(2),
    );
  });

  test('guessing the claim code locks the claim', () async {
    final relay = InMemoryInactivityRelay(maxWrongCodes: 3);
    final kit = await VaultSeal.createKit(
      ownerName: 'Leila',
      nominee: husband,
      entries: entries,
      now: day(0),
      random: Random(11),
    );
    await relay.arm(
      nomineeId: husband.id,
      sealedFile: kit.sealedFile,
      claimCodeHash: kit.claimCodeHash,
      intervalDays: 60,
      now: day(0),
    );
    for (var i = 0; i < 3; i++) {
      expect(
        await relay.claim(
          nomineeId: husband.id,
          claimCode: 'AAAA-BBBB-C$i',
          now: day(100),
        ),
        isA<ClaimWrongCode>(),
      );
    }
    final r = await relay.claim(
      nomineeId: husband.id,
      claimCode: kit.claimCode,
      now: day(100),
    );
    expect(
      r,
      isA<ClaimWrongCode>().having((x) => x.locked, 'locked', isTrue),
      reason: 'even the right code is refused once locked',
    );
  });

  test('disarming (removing the person) stops release; changing the interval applies', () async {
    final relay = InMemoryInactivityRelay();
    final kit = await VaultSeal.createKit(
      ownerName: 'Leila',
      nominee: husband,
      entries: entries,
      now: day(0),
      random: Random(12),
    );
    await relay.arm(
      nomineeId: husband.id,
      sealedFile: kit.sealedFile,
      claimCodeHash: kit.claimCodeHash,
      intervalDays: 60,
      now: day(0),
    );
    await relay.setInterval(180);
    expect(
      await relay.claim(
        nomineeId: husband.id,
        claimCode: kit.claimCode,
        now: day(100),
      ),
      isA<ClaimNotYet>(),
    );
    await relay.disarm(husband.id);
    expect(
      await relay.claim(
        nomineeId: husband.id,
        claimCode: kit.claimCode,
        now: day(400),
      ),
      isA<ClaimWrongCode>(),
    );
  });

  test('the production stub releases nothing and says so', () async {
    const relay = UnavailableInactivityRelay();
    expect(relay.isAvailable, isFalse);
    expect(
      await relay.claim(nomineeId: 'x', claimCode: 'y', now: day(999)),
      isA<ClaimUnavailable>(),
    );
  });
}
