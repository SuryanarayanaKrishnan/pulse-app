/// The plain-text emergency sheet: what a family member would read. Markdown
/// so it also reads fine as plain text in a message.
library;

import 'vault_models.dart';

String _aed(int minor) {
  final v = minor / 100;
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return 'AED ${parts.length > 1 ? '$whole.${parts[1]}' : whole}';
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [forNominee] limits the sheet to what that person may see; null lists
/// every entry (the owner's own copy).
String emergencySheet({
  required String ownerName,
  required List<VaultEntry> entries,
  Nominee? forNominee,
  required DateTime now,
}) {
  final who = ownerName.trim().isEmpty
      ? 'the account holder'
      : ownerName.trim();
  final list = visibleTo(forNominee, entries);
  final b = StringBuffer()
    ..writeln('# If something happens to $who')
    ..writeln()
    ..writeln(
      'Prepared with Pulse on ${_date(now)}${forNominee == null ? '' : ' for ${forNominee.name}'}.',
    )
    ..writeln()
    ..writeln(
      'This sheet says where to look. It holds no passwords, PINs or full card numbers. '
      'It is an information aid, not a will and not legal advice. For anything about who inherits '
      'what, speak to a lawyer who knows UAE succession law.',
    )
    ..writeln();
  if (list.isEmpty) {
    b.writeln('Nothing has been added yet.');
    return b.toString();
  }
  VaultType? current;
  for (final e in list) {
    if (e.type != current) {
      current = e.type;
      b
        ..writeln('## ${e.type.label}')
        ..writeln();
    }
    b.writeln('- **${e.displayName}**');
    if (e.whereToFind.trim().isNotEmpty)
      b.writeln('  - Where to find it: ${e.whereToFind.trim()}');
    if (e.nomineeName.trim().isNotEmpty)
      b.writeln('  - Nominee named on it: ${e.nomineeName.trim()}');
    if (e.contactPerson.trim().isNotEmpty)
      b.writeln('  - Who to contact: ${e.contactPerson.trim()}');
    if (e.estimatedValueMinor != null)
      b.writeln('  - Roughly: ${_aed(e.estimatedValueMinor!)}');
    if (e.photoPaths.isNotEmpty)
      b.writeln(
        '  - ${e.photoPaths.length} photo${e.photoPaths.length == 1 ? '' : 's'} of the papers are on the phone.',
      );
  }
  b
    ..writeln()
    ..writeln('---')
    ..writeln(
      'Keep this sheet somewhere private. Anyone who has it knows where your accounts are.',
    );
  return b.toString();
}
