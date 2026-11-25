/// Where receipt emails come from. Pure Dart; no tokens are kept in code.
library;

import 'receipt_models.dart';

/// Read-only access to receipt emails.
abstract class ReceiptSource {
  /// True when this source can run (OAuth client configured and signed in).
  bool get isConfigured;

  /// Messages received at or after [since], newest last.
  Future<List<ReceiptMessage>> fetch({required DateTime since});
}

/// Test and demo source.
class InMemoryReceiptSource implements ReceiptSource {
  InMemoryReceiptSource([List<ReceiptMessage>? messages]) : messages = messages ?? [];
  final List<ReceiptMessage> messages;
  @override
  bool get isConfigured => true;
  @override
  Future<List<ReceiptMessage>> fetch({required DateTime since}) async => [
    for (final m in messages) if (!m.receivedAt.isBefore(since)) m,
  ];
}

/// The only Gmail permission ever requested: read-only.
const gmailReadOnlyScope = 'https://www.googleapis.com/auth/gmail.readonly';

/// Narrow search: known receipt senders, receipt-like subjects, recent only.
/// Nothing else in the mailbox is listed or read.
String gmailReceiptQuery(DateTime since) {
  final d = '${since.year}/${since.month.toString().padLeft(2, '0')}/${since.day.toString().padLeft(2, '0')}';
  return '(from:noon.com OR from:talabat.com OR from:careem.com) '
      '(subject:order OR subject:receipt OR subject:shipment OR subject:invoice) '
      'after:$d -category:promotions';
}

/// Gmail implementation: NOT FUNCTIONAL until the owner creates a Google
/// Cloud OAuth client (see docs/RECEIPTS.md). [isConfigured] stays false, so
/// the app keeps the Email receipts row disabled. No token is stored here.
class GmailReceiptSource implements ReceiptSource {
  const GmailReceiptSource({this.oauthClientId});

  /// Supplied at build time by the owner (`--dart-define`), never committed.
  final String? oauthClientId;

  static const clientIdFromEnvironment = String.fromEnvironment('GMAIL_OAUTH_CLIENT_ID');

  static GmailReceiptSource fromEnvironment() =>
      GmailReceiptSource(oauthClientId: clientIdFromEnvironment.isEmpty ? null : clientIdFromEnvironment);

  /// Even with a client id the sign-in and fetch calls are not written yet.
  @override
  bool get isConfigured => false;

  @override
  Future<List<ReceiptMessage>> fetch({required DateTime since}) async {
    throw UnsupportedError('Gmail receipts are not configured. See docs/RECEIPTS.md.');
  }
}
