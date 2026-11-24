import 'dart:convert';

/// Bump when the on-disk layout changes incompatibly. A reader refuses a
/// higher number instead of guessing.
const backupFormatVersion = 1;

class TableEntry {
  const TableEntry({required this.name, required this.rows, required this.chunks});
  final String name;
  final int rows;
  final List<String> chunks;

  Map<String, Object> toJson() => {'name': name, 'rows': rows, 'chunks': chunks};
  static TableEntry fromJson(Map<String, dynamic> j) =>
      TableEntry(name: j['name'] as String, rows: j['rows'] as int, chunks: (j['chunks'] as List).cast<String>());
}

class AttachmentEntry {
  const AttachmentEntry({
    required this.origPath,
    required this.name,
    required this.size,
    required this.fileId,
    required this.chunks,
  });

  /// Where the file lived on the old phone; used only to re-point database
  /// rows at the restored copy.
  final String origPath;
  final String name;
  final int size;

  /// Keyed hash of the chunk ids, so identical files share an identity.
  final String fileId;
  final List<String> chunks;

  Map<String, Object> toJson() => {
    'orig': origPath,
    'name': name,
    'size': size,
    'fileId': fileId,
    'chunks': chunks,
  };
  static AttachmentEntry fromJson(Map<String, dynamic> j) => AttachmentEntry(
    origPath: j['orig'] as String,
    name: j['name'] as String,
    size: j['size'] as int,
    fileId: j['fileId'] as String,
    chunks: (j['chunks'] as List).cast<String>(),
  );
}

/// The decrypted description of one snapshot. It is the only thing that knows
/// which chunks belong together, and it is itself encrypted.
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.appSchemaVersion,
    required this.createdAt,
    required this.id,
    required this.tables,
    required this.attachments,
    required this.skippedAttachments,
    required this.treeHash,
  });

  final int format;

  /// `PulseDatabase.schemaVersion` of the app that wrote it. A newer app
  /// restores it by running the row upgraders; an older app refuses.
  final int appSchemaVersion;
  final DateTime createdAt;
  final String id;
  final List<TableEntry> tables;
  final List<AttachmentEntry> attachments;

  /// Files the database pointed at but that were gone when the backup ran.
  final int skippedAttachments;

  /// Keyed hash over all chunk ids; checked on restore.
  final String treeHash;

  int get rowCount => tables.fold(0, (a, t) => a + t.rows);

  Set<String> get allChunks => {
    for (final t in tables) ...t.chunks,
    for (final a in attachments) ...a.chunks,
  };

  List<int> encode() => utf8.encode(
    jsonEncode({
      'format': format,
      'schema': appSchemaVersion,
      'created': createdAt.toUtc().toIso8601String(),
      'id': id,
      'tables': [for (final t in tables) t.toJson()],
      'attachments': [for (final a in attachments) a.toJson()],
      'skipped': skippedAttachments,
      'tree': treeHash,
    }),
  );

  static BackupManifest decode(List<int> bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return BackupManifest(
        format: j['format'] as int,
        appSchemaVersion: j['schema'] as int,
        createdAt: DateTime.parse(j['created'] as String),
        id: j['id'] as String,
        tables: [for (final t in (j['tables'] as List)) TableEntry.fromJson((t as Map).cast<String, dynamic>())],
        attachments: [
          for (final a in (j['attachments'] as List)) AttachmentEntry.fromJson((a as Map).cast<String, dynamic>()),
        ],
        skippedAttachments: (j['skipped'] as int?) ?? 0,
        treeHash: j['tree'] as String,
      );
    } catch (_) {
      throw const FormatException('The backup index is damaged');
    }
  }
}

/// A snapshot as listed to the user.
class BackupVersion {
  const BackupVersion({required this.objectName, required this.manifest});
  final String objectName;
  final BackupManifest manifest;
}

class BackupTooNew implements Exception {
  const BackupTooNew();
  @override
  String toString() => 'This backup was made by a newer version of the app. Update the app, then try again.';
}

class BackupIncomplete implements Exception {
  const BackupIncomplete(this.missing);
  final int missing;
  @override
  String toString() => 'This backup is incomplete ($missing pieces are missing), so it was not used.';
}

class NoBackupFound implements Exception {
  const NoBackupFound();
  @override
  String toString() => 'No backup was found here.';
}
