import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/vault/release.dart';
import 'package:pulse/core/vault/vault_models.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  VaultEntry entry(String id, List<String> photos) => VaultEntry(
    id: id,
    type: VaultType.bank,
    institution: 'Mashreq',
    photoPaths: photos,
    createdAt: t0,
    updatedAt: t0,
  );
  final nominee = Nominee(id: 'n1', name: 'Karim', createdAt: t0);
  final files = <String, Uint8List>{
    'a.pdf': Uint8List.fromList(utf8.encode('%PDF-secret-deed')),
    'b.jpg': Uint8List.fromList(List.filled(40, 7)),
  };

  test(
    'papers are sealed, opened with two shares, and never in plaintext',
    () async {
      final kit = await VaultSeal.createKit(
        ownerName: 'Leila',
        nominee: nominee,
        entries: [
          entry('1', ['a.pdf', 'b.jpg']),
        ],
        now: t0,
        random: Random(3),
        readPaper: (p) async => files[p],
      );
      expect(kit.papersIncluded, 2);
      expect(kit.papersLeftOut, 0);
      expect(kit.sealedFile, isNot(contains('secret-deed')));
      expect(kit.sealedFile, isNot(contains(base64Encode(files['a.pdf']!))));

      final opened = await VaultSeal.open(kit.sealedFile, [
        kit.nomineeShare,
        kit.escrowShare,
      ]);
      expect(opened.papers['1'], hasLength(2));
      expect(opened.papers['1']![0], files['a.pdf']);
      expect(opened.papers['1']![1], files['b.jpg']);
    },
  );

  test('papers over the size cap are left out and counted', () async {
    final kit = await VaultSeal.createKit(
      ownerName: 'Leila',
      nominee: nominee,
      entries: [
        entry('1', ['a.pdf', 'b.jpg']),
      ],
      now: t0,
      random: Random(4),
      readPaper: (p) async => files[p],
      maxPaperBytes: 50,
    );
    expect(kit.papersIncluded, 1);
    expect(kit.papersLeftOut, 1);
  });

  test('only entries the nominee may see carry their papers', () async {
    final limited = Nominee(
      id: 'n2',
      name: 'Sam',
      entryIds: const {'1'},
      createdAt: t0,
    );
    final kit = await VaultSeal.createKit(
      ownerName: 'Leila',
      nominee: limited,
      entries: [
        entry('1', ['a.pdf']),
        entry('2', ['b.jpg']),
      ],
      now: t0,
      random: Random(5),
      readPaper: (p) async => files[p],
    );
    final opened = await VaultSeal.open(kit.sealedFile, [
      kit.ownerShare,
      kit.nomineeShare,
    ]);
    expect(opened.papers.keys, ['1']);
  });

  test('a missing or unreadable paper is skipped quietly', () async {
    final kit = await VaultSeal.createKit(
      ownerName: 'Leila',
      nominee: nominee,
      entries: [
        entry('1', ['gone.pdf', 'a.pdf']),
      ],
      now: t0,
      random: Random(6),
      readPaper: (p) async => p == 'gone.pdf' ? throw Exception('x') : files[p],
    );
    expect(kit.papersIncluded, 1);
  });

  test('files made before papers existed still open', () async {
    final kit = await VaultSeal.createKit(
      ownerName: 'Leila',
      nominee: nominee,
      entries: [entry('1', [])],
      now: t0,
      random: Random(7),
    );
    final opened = await VaultSeal.open(kit.sealedFile, [
      kit.ownerShare,
      kit.escrowShare,
    ]);
    expect(opened.papers, isEmpty);
    expect(opened.entries, hasLength(1));
  });
}
