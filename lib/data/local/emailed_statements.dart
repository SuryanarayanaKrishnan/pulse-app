import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/engine/statement_import.dart' show StatementImportException;
import '../repository.dart';
import '../statements.dart';
import 'database.dart';
import 'statement_service.dart';

const _pulledKey = 'email_statements.pulled';

/// Brings emailed (Gmail) statements onto this phone.
///
/// The server only fetches the email and keeps the file as the bank sent it
/// (still locked). Each new file is downloaded once and read here, with the
/// passwords saved on this phone, through the same import as an uploaded PDF:
/// lines become transactions, own transfers are flagged and captured rows are
/// merged. Returns how many statements were brought in.
///
/// A statement is fetched once: its server id is remembered, and a file whose
/// hash is already on the phone is never downloaded. Offline or failing files
/// are tried again next time; a locked file stays in Statements and opens when
/// its password is saved.
Future<int> pullEmailedStatements({
  required PulseDatabase db,
  required LocalStatementService service,
  required StatementFileSource files,
  required List<Statement> remote,
}) async {
  final raw = await db.setting(_pulledKey);
  final pulled = <String>{
    if (raw != null) ...(jsonDecode(raw) as List).cast<String>(),
  };
  var changed = false;
  var brought = 0;
  for (final st in remote) {
    if (st.source != 'gmail' || pulled.contains(st.id)) continue;
    if (st.parse == ParseStatus.skipped) continue;
    final sha = st.fileSha256;
    if (sha != null) {
      final have =
          await (db.select(db.statements)
                ..where((t) => t.fileSha256.equals(sha) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (have != null) {
        pulled.add(st.id);
        changed = true;
        continue;
      }
    }
    try {
      final bytes = await files.statementFile(st.id);
      final name = st.filename ?? 'statement.pdf';
      try {
        final r = await service.upload(
          bytes: bytes,
          filename: name,
          institution: st.institution,
          source: 'gmail',
        );
        if (!r.duplicate) brought++;
      } on StatementImportException {
        // A locked file is kept in Statements (and opens when its password is
        // saved); a file this phone cannot read is not downloaded again.
      }
      pulled.add(st.id);
      changed = true;
    } on Object {
      // Offline or a transient server error: try again next time.
    }
  }
  if (changed) await db.putSetting(_pulledKey, jsonEncode(pulled.toList()));
  return brought;
}
