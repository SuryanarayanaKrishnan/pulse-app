import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/db_key.dart';
import 'package:pulse/data/local/encrypted_attachments.dart';

void main() {
  late Directory tmp;
  late EncryptedAttachmentStorage store;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vault_enc');
    store = EncryptedAttachmentStorage(
      keys: MemoryKeyStore('key-one'),
      root: () async => Directory('${tmp.path}/att'),
      maxBytes: 1000,
    );
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<String> source(String name, List<int> bytes) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  test('a paper is stored encrypted and reads back identical', () async {
    final plain = Uint8List.fromList([
      ...'%PDF-1.7 title deed for the Marina flat'.codeUnits,
      ...List.filled(100, 7),
    ]);
    final stored = await store.import(await source('deed.pdf', plain));
    expect(stored, endsWith('.pdf.enc'));
    final onDisk = await File(stored).readAsBytes();
    expect(onDisk.length, plain.length + 4 + 12 + 16);
    expect(String.fromCharCodes(onDisk), isNot(contains('title deed')));
    expect(await store.read(stored), plain);
  });

  test('the same key reads it after a restore; another key cannot', () async {
    final stored = await store.import(
      await source('a.jpg', List.filled(64, 3)),
    );
    final sameKey = EncryptedAttachmentStorage(
      keys: MemoryKeyStore('key-one'),
      root: () async => Directory('${tmp.path}/att'),
    );
    expect(await sameKey.read(stored), List.filled(64, 3));
    final other = EncryptedAttachmentStorage(
      keys: MemoryKeyStore('key-two'),
      root: () async => Directory('${tmp.path}/att'),
    );
    await expectLater(other.read(stored), throwsA(anything));
  });

  test('a tampered file is refused, not shown garbled', () async {
    final stored = await store.import(
      await source('a.png', List.filled(64, 9)),
    );
    final b = await File(stored).readAsBytes();
    b[40] ^= 0xff;
    await File(stored).writeAsBytes(b);
    await expectLater(store.read(stored), throwsA(anything));
  });

  test(
    'older plain photos still open; missing files give null; delete works',
    () async {
      final legacy = await source('old.jpg', [1, 2, 3, 4, 5]);
      expect(await store.read(legacy), [1, 2, 3, 4, 5]);
      expect(await store.read('${tmp.path}/nope.jpg'), isNull);
      final stored = await store.import(
        await source('x.jpg', List.filled(10, 1)),
      );
      await store.delete([stored]);
      expect(File(stored).existsSync(), isFalse);
    },
  );

  test('a file over the limit is refused with a plain message', () async {
    await expectLater(
      store.import(await source('big.pdf', List.filled(2000, 0))),
      throwsA(isA<FileTooLarge>()),
    );
    expect(const FileTooLarge().toString(), contains('25 MB'));
  });
}
