import 'dart:io' show Directory;

import 'database.dart';
import 'db_key.dart';

/// The web build has no encrypted native database: run it with
/// `--dart-define=DEMO_DATA=true`, which never calls this.
Future<PulseDatabase> openEncryptedDatabase({
  DatabaseKeyStore? keys,
  String fileName = 'pulse.db',
  Directory? directory,
  bool background = true,
  bool allowPlaintext = false,
}) => throw UnsupportedError(
  'The on-device ledger needs the iOS or Android app. Use DEMO_DATA=true on the web.',
);
