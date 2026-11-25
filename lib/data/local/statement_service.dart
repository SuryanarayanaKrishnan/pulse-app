import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/engine/split_settle.dart';
import '../../core/engine/statement_parser.dart';
import '../../core/engine/statement_transfers.dart';
import '../../core/engine/types.dart';
import '../statement_password_store.dart';
import '../statements.dart';
import 'database.dart';
import 'ids.dart';

// ---- PDF text -----------------------------------------------------------------

enum PdfReadStatus { read, needsPassword, failed }

class PdfReadResult {
  const PdfReadResult(this.status, [this.text = '', this.error]);
  final PdfReadStatus status;
  final String text;
  final String? error;
}

/// Opens a PDF (trying each password in turn) and returns its text.
abstract class PdfTextExtractor {
  Future<PdfReadResult> extract(Uint8List bytes, List<String> passwords);
}

class PdfrxTextExtractor implements PdfTextExtractor {
  /// [initialize] is the Flutter setup in the app; tests pass the plain engine.
  const PdfrxTextExtractor({this.initialize = pdfrxFlutterInitialize});
  final Future<void> Function() initialize;

  @override
  Future<PdfReadResult> extract(Uint8List bytes, List<String> passwords) async {
    await initialize();
    // No password first (an open PDF), then each saved one.
    final attempts = <String?>[null, ...passwords];
    var locked = false;
    for (final pw in attempts) {
      PdfDocument? doc;
      try {
        var offered = false;
        doc = await PdfDocument.openData(
          bytes,
          passwordProvider: () {
            // Offer this candidate once; null tells pdfrx to give up on it.
            if (pw == null || offered) return null;
            offered = true;
            return pw;
          },
        );
        final out = StringBuffer();
        for (final page in doc.pages) {
          final t = await page.loadText();
          if (t != null) out.writeln(t.fullText);
        }
        return PdfReadResult(PdfReadStatus.read, out.toString());
      } on PdfPasswordException {
        locked = true;
      } catch (e) {
        return PdfReadResult(
          PdfReadStatus.failed,
          '',
          'Could not read this PDF.',
        );
      } finally {
        await doc?.dispose();
      }
    }
    return locked
        ? const PdfReadResult(PdfReadStatus.needsPassword)
        : const PdfReadResult(
            PdfReadStatus.failed,
            '',
            'Could not read this PDF.',
          );
  }
}

// ---- locked files -------------------------------------------------------------

/// Keeps a locked PDF (still encrypted) until a password opens it, then it is
/// deleted. Parsed statements keep only their numbers, never the file.
abstract class LockedFileStore {
  Future<void> put(String id, Uint8List bytes);
  Future<Uint8List?> get(String id);
  Future<void> remove(String id);
}

class MemoryLockedFileStore implements LockedFileStore {
  final _files = <String, Uint8List>{};
  @override
  Future<void> put(String id, Uint8List bytes) async => _files[id] = bytes;
  @override
  Future<Uint8List?> get(String id) async => _files[id];
  @override
  Future<void> remove(String id) async => _files.remove(id);
}

class PrivateLockedFileStore implements LockedFileStore {
  Future<File> _file(String id) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'locked_statements'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File(p.join(dir.path, '$id.pdf'));
  }

  @override
  Future<void> put(String id, Uint8List bytes) async =>
      (await _file(id)).writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List?> get(String id) async {
    final f = await _file(id);
    return f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  Future<void> remove(String id) async {
    final f = await _file(id);
    if (f.existsSync()) await f.delete();
  }
}

// ---- service ------------------------------------------------------------------

class StatementUpload {
  const StatementUpload(this.id, {this.duplicate = false});
  final String id;
  final bool duplicate;
}

/// Reads statement PDFs on this device: unlocks them with the saved
/// passwords, parses them and stores the numbers. Nothing is uploaded.
class LocalStatementService {
  LocalStatementService({
    required this.db,
    required this.passwords,
    PdfTextExtractor? extractor,
    LockedFileStore? locked,
    this.onTransfer,
  }) : _extractor = extractor ?? const PdfrxTextExtractor(),
       _locked = locked ?? MemoryLockedFileStore();

  final PulseDatabase db;
  final StatementPasswordStore passwords;
  final PdfTextExtractor _extractor;
  final LockedFileStore _locked;

  /// Called once per imported transfer line that names a person (auto-settle).
  final Future<void> Function(Counterparty counterparty, int amountMinor)?
  onTransfer;

  static const _handledKey = 'autosettle.statement_handled';

  /// Offers each transfer line to auto-settle exactly once: lines already
  /// offered (re-reads, overlapping statements) and lines a live capture
  /// (SMS, notification) already saw are skipped.
  Future<void> _settleTransfers(
    String statementId,
    ParsedStatement parsed,
  ) async {
    final cb = onTransfer;
    if (cb == null) return;
    Set<String> handled;
    try {
      handled = (jsonDecode(await db.setting(_handledKey) ?? '[]') as List)
          .cast<String>()
          .toSet();
    } catch (_) {
      handled = {};
    }
    final captured =
        await (db.select(db.transactions)..where(
              (t) => t.deletedAt.isNull() & t.source.equals('statement').not(),
            ))
            .get();
    var changed = false;
    for (final l in parsed.lines) {
      final c = transferCounterparty(l.description, l.direction);
      if (c == null) continue;
      final key =
          '${l.postedOn.toIso()}|${l.direction.name}|${l.amountMinor}|${normaliseName(c.name)}|${c.phone ?? ''}|${c.ibanTail ?? ''}';
      if (handled.contains(key)) continue;
      handled.add(key);
      changed = true;
      final day = l.postedOn.toUtcMidnight();
      final seen = captured.any(
        (t) =>
            t.amountMinor == l.amountMinor &&
            t.direction == l.direction.name &&
            t.postedAt.toUtc().difference(day).inDays.abs() <= 1,
      );
      if (seen) continue;
      try {
        await cb(c, l.amountMinor);
      } catch (_) {}
    }
    if (changed) await db.putSetting(_handledKey, jsonEncode(handled.toList()));
  }

  Future<List<String>> _candidates(String? institution) async {
    final saved = await passwords.saved();
    // Known bank: its password first. Unknown: every saved one.
    final ordered = [
      ...saved.where((s) => s.institution == institution),
      ...saved.where((s) => s.institution != institution),
    ];
    return [for (final s in ordered) ?await passwords.read(s.institution)];
  }

  Future<StatementUpload> upload({
    required Uint8List bytes,
    required String filename,
    String? institution,
  }) async {
    institution ??= _detectFromFilename(filename);
    final sha = sha256.convert(bytes).toString();
    final dup =
        await (db.select(db.statements)
              ..where((t) => t.fileSha256.equals(sha) & t.deletedAt.isNull()))
            .getSingleOrNull();
    if (dup != null) return StatementUpload(dup.id, duplicate: true);
    final id = newId();
    await db
        .into(db.statements)
        .insert(
          StatementsCompanion.insert(
            id: id,
            institution: Value(institution),
            originalFilename: Value(filename),
            fileSha256: Value(sha),
            source: const Value('upload'),
          ),
        );
    await _process(id, bytes, institution);
    return StatementUpload(id);
  }

  /// Re-reads a locked statement (after a password was saved).
  Future<void> reprocess(String id) async {
    final row = await (db.select(
      db.statements,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final bytes = await _locked.get(id);
    if (bytes == null) return;
    await _process(id, bytes, row.institution);
  }

  /// Retries every statement waiting for a password; returns how many opened.
  Future<int> retryLocked() async {
    final rows =
        await (db.select(db.statements)..where(
              (t) =>
                  t.parseStatus.equals('needs_password') & t.deletedAt.isNull(),
            ))
            .get();
    var opened = 0;
    for (final r in rows) {
      await reprocess(r.id);
      final now = await (db.select(
        db.statements,
      )..where((t) => t.id.equals(r.id))).getSingle();
      if (now.parseStatus != 'needs_password') opened++;
    }
    return opened;
  }

  Future<void> _process(String id, Uint8List bytes, String? institution) async {
    Future<void> setStatus(String status, {String? error}) =>
        (db.update(db.statements)..where((t) => t.id.equals(id))).write(
          StatementsCompanion(
            parseStatus: Value(status),
            parseError: Value(error),
          ),
        );

    final read = await _extractor.extract(
      bytes,
      await _candidates(institution),
    );
    switch (read.status) {
      case PdfReadStatus.needsPassword:
        await _locked.put(id, bytes);
        return setStatus('needs_password');
      case PdfReadStatus.failed:
        await _locked.remove(id);
        return setStatus('failed', error: read.error);
      case PdfReadStatus.read:
        break;
    }
    await _locked.remove(id);
    final inst = institution ?? _detect(read.text);
    final parsed = parseStatement(read.text, institution: inst);
    if (parsed == null) {
      return setStatus(
        'failed',
        error: 'No transactions found in this statement.',
      );
    }
    final recon = reconcile(parsed);
    await db.transaction(() async {
      await (db.delete(
        db.statementLines,
      )..where((t) => t.statementId.equals(id))).go();
      await db.batch((b) {
        b.insertAll(db.statementLines, [
          for (var i = 0; i < parsed.lines.length; i++)
            StatementLinesCompanion.insert(
              id: newId(),
              statementId: id,
              lineNo: i,
              postedOn: parsed.lines[i].postedOn.toIso(),
              description: parsed.lines[i].description,
              amountMinor: parsed.lines[i].amountMinor,
              direction: parsed.lines[i].direction.name,
              currency: Value(parsed.currency),
              foreignAmountMinor: Value(parsed.lines[i].foreignAmountMinor),
              foreignCurrency: Value(parsed.lines[i].foreignCurrency),
              balanceMinor: Value(parsed.lines[i].balanceMinor),
            ),
        ]);
      });
      await (db.update(db.statements)..where((t) => t.id.equals(id))).write(
        StatementsCompanion(
          institution: Value(inst),
          kind: Value(
            parsed.kind == StatementKind.creditCard
                ? 'credit_card'
                : 'bank_account',
          ),
          currency: Value(parsed.currency),
          periodStart: Value(parsed.periodStart?.toIso()),
          periodEnd: Value(parsed.periodEnd?.toIso()),
          openingBalanceMinor: Value(parsed.openingMinor),
          closingBalanceMinor: Value(parsed.closingMinor),
          parseStatus: const Value('parsed'),
          parseError: const Value(null),
          reconciliationStatus: Value(recon.status),
          diffMinor: Value(recon.diffMinor),
          summary: Value(jsonEncode(summaryJson(parsed))),
        ),
      );
    });
    await _settleTransfers(id, parsed);
  }

  Future<List<Statement>> statements() async {
    final rows =
        await (db.select(db.statements)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return [for (final r in rows) _toModel(r)];
  }

  Statement _toModel(StatementRow r) {
    final s = r.summary == null
        ? const <String, dynamic>{}
        : jsonDecode(r.summary!) as Map<String, dynamic>;
    final last4 = s['last4'] as String?;
    final name = institutionName(r.institution);
    return Statement(
      id: r.id,
      institution: r.institution,
      accountId: r.accountId,
      accountLabel: last4 == null ? name : '$name ····$last4',
      periodStart: _day(r.periodStart),
      periodEnd: _day(r.periodEnd),
      parse: ParseStatus.fromWire(r.parseStatus),
      recon: ReconStatus.fromWire(r.reconciliationStatus),
      diff: r.diffMinor == null ? null : r.diffMinor! / 100,
      source: r.source,
      filename: r.originalFilename,
      parseError: r.parseError,
    );
  }

  static DateTime? _day(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);
}

String? _detectFromFilename(String filename) {
  final up = filename.toUpperCase();
  if (up.startsWith('SIB_') || up.contains('SHARJAH')) return 'sib';
  return _detect(up);
}

String? _detect(String text) {
  final up = text.toUpperCase();
  const markers = {
    'eib': ['EMIRATES ISLAMIC'],
    'enbd': ['EMIRATES NBD', 'EMIRATESNBD'],
    'adcb': ['ABU DHABI COMMERCIAL BANK', 'ADCB'],
    'adib': ['ABU DHABI ISLAMIC BANK', 'ADIB'],
    'fab': ['FIRST ABU DHABI BANK', 'BANKFAB', 'DUBAI FIRST'],
    'mashreq': ['MASHREQ'],
    'rakbank': ['RAKBANK', 'RAK BANK'],
    'dib': ['DUBAI ISLAMIC BANK'],
    'hsbc': ['HSBC'],
    'citi': ['CITIBANK', 'CITI '],
    'cbd': ['COMMERCIAL BANK OF DUBAI'],
    'liv': ['LIV '],
    'sib': ['SHARJAH ISLAMIC'],
  };
  for (final e in markers.entries) {
    if (e.value.any(up.contains)) return e.key;
  }
  return null;
}

class StatementRecon {
  const StatementRecon(this.status, this.diffMinor);
  final String status; // matched | mismatch | pending
  final int? diffMinor; // printed closing - computed closing
}

/// Does opening + the lines equal the printed closing balance?
StatementRecon reconcile(ParsedStatement s) {
  final opening = s.openingMinor, closing = s.closingMinor;
  if (opening == null || closing == null)
    return const StatementRecon('pending', null);
  var debits = 0, credits = 0;
  for (final l in s.lines) {
    if (l.direction == Direction.debit) {
      debits += l.amountMinor;
    } else {
      credits += l.amountMinor;
    }
  }
  final net = s.kind == StatementKind.creditCard
      ? debits - credits
      : credits - debits;
  final diff = closing - (opening + net);
  return StatementRecon(diff == 0 ? 'matched' : 'mismatch', diff);
}

Map<String, Object?> summaryJson(ParsedStatement s) => {
  'last4': s.last4,
  'statement_date': s.statementDate?.toIso(),
  'due_date': s.dueDate?.toIso(),
  'min_due_minor': s.minDueMinor,
  'total_payments_minor': s.totalPaymentsMinor,
  'total_purchases_minor': s.totalPurchasesMinor,
  'warnings': s.warnings,
};
