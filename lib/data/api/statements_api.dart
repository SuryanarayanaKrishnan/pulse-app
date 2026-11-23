/// Client surface for statements, statement passwords and Gmail connect.
///
/// The backend routes for these do not exist yet (the API README lists them
/// under "Not built yet"), so nothing here talks to the network. When they
/// land, implement the methods with the published paths and wire them into the
/// connect screen's "Gmail statements" and "Upload a PDF statement" tiles.
abstract class StatementsApi {
  /// TODO(statements): `POST /v1/statements` (multipart PDF upload).
  Future<void> uploadStatement({required String filePath, String? accountId});

  /// TODO(statements): `POST /v1/statement-passwords` (store an encrypted PDF
  /// password for an institution).
  Future<void> savePassword({
    required String institution,
    required String password,
  });

  /// TODO(gmail): `POST /v1/gmail/connect` returning an OAuth URL to open.
  Future<Uri> startGmailConnect();
}

/// Placeholder until the backend ships the routes.
class UnimplementedStatementsApi implements StatementsApi {
  const UnimplementedStatementsApi();

  @override
  Future<void> uploadStatement({required String filePath, String? accountId}) =>
      Future.error(UnsupportedError('Statement upload API not available yet'));

  @override
  Future<void> savePassword({
    required String institution,
    required String password,
  }) => Future.error(
    UnsupportedError('Statement password API not available yet'),
  );

  @override
  Future<Uri> startGmailConnect() =>
      Future.error(UnsupportedError('Gmail connect API not available yet'));
}
