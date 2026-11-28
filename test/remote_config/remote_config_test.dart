import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/remote_config/remote_config.dart';

String doc(
  int v, {
  Map<String, Object?>? flags,
  List<String> kill = const [],
}) => jsonEncode({
  'version': v,
  'flags':
      flags ??
      {
        'a': {'enabled': true, 'rollout_pct': 100},
      },
  'params': {'n': 3},
  'kill_switches': kill,
});

RemoteConfigService svc(KvStore kv, {String bundledDoc = ''}) =>
    RemoteConfigService(
      kv: kv,
      bundled: () async => bundledDoc.isEmpty ? doc(1) : bundledDoc,
      randomId: () => 'phone-1',
    );

void main() {
  test('bundled config is used offline', () async {
    final s = svc(MemoryKvStore());
    await s.load();
    expect(s.isOn('a'), isTrue);
    expect(s.isOn('missing'), isFalse);
    expect(s.param<int>('n', 0), 3);
    expect(s.param<int>('nope', 7), 7);
  });

  test('kill switch and disabled flags are off', () async {
    final s = svc(MemoryKvStore(), bundledDoc: doc(2, kill: ['a']));
    await s.load();
    expect(s.isOn('a'), isFalse);
  });

  test('rollout is stable per phone and roughly proportional', () {
    expect(rolloutBucket('x', 'f'), rolloutBucket('x', 'f'));
    var on = 0;
    for (var i = 0; i < 1000; i++) {
      if (rolloutBucket('id$i', 'f') < 20) on++;
    }
    expect(on, inInclusiveRange(140, 260));
  });

  test('canonical JSON sorts keys and has no spaces', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {
          'd': [2, 1],
          'c': 'é',
        },
      }),
      '{"a":{"c":"é","d":[2,1]},"b":1}',
    );
  });

  test('signature verifies and tampering fails', () async {
    final ed = Ed25519();
    final pair = await ed.newKeyPairFromSeed(List.filled(32, 1));
    final pub = base64.encode((await pair.extractPublicKey()).bytes);
    final payload = Map<String, Object?>.from(jsonDecode(doc(5)) as Map);
    final sig = await ed.sign(
      utf8.encode(canonicalJson(payload)),
      keyPair: pair,
    );
    final sigB64 = base64.encode(sig.bytes);
    expect(
      await verifyConfigSignature(
        payload: payload,
        signatureB64: sigB64,
        publicKeyB64: pub,
      ),
      isTrue,
    );
    payload['version'] = 6;
    expect(
      await verifyConfigSignature(
        payload: payload,
        signatureB64: sigB64,
        publicKeyB64: pub,
      ),
      isFalse,
    );
    expect(
      await verifyConfigSignature(
        payload: payload,
        signatureB64: 'junk',
        publicKeyB64: pub,
      ),
      isFalse,
    );
  });

  test('cached newer config wins over bundled on next start', () async {
    final kv = MemoryKvStore();
    await kv.write('remote_config.cached', doc(9, kill: ['a']));
    final s = svc(kv);
    await s.load();
    expect(s.config.version, 9);
    expect(s.isOn('a'), isFalse);
  });
}
