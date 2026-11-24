import 'dart:io';

import 'package:pulse/core/engine/receipts/receipt_models.dart';

/// Loads a fixture. A leading `From:` and `Subject:` header is split off.
ReceiptMessage loadReceipt(
  String path, {
  String from = 'x@example.com',
  String subject = '',
  DateTime? at,
  String? id,
}) {
  var text = File('test/fixtures/receipts/$path').readAsStringSync();
  var f = from, s = subject;
  final lines = text.split('\n');
  if (lines.first.startsWith('From:')) {
    f = lines[0].substring(5).trim();
    s = lines[1].substring(8).trim();
    text = lines.skip(2).join('\n');
  }
  return ReceiptMessage(
    id: id ?? path,
    from: f,
    subject: s,
    body: text,
    receivedAt: at ?? DateTime(2026, 3, 12, 19, 50),
    isHtml: path.endsWith('.html'),
  );
}
