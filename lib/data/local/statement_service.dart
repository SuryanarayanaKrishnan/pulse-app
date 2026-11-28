import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/engine/sheet_import.dart' show parseCsv, readXlsx;
import '../../core/engine/split_settle.dart';
import '../../core/engine/statement_import.dart';
import '../../core/engine/statement_parser.dart';
import '../../core/engine/own_transfers.dart';
import '../../core/engine/statement_transfers.dart';
import '../../core/engine/types.dart';
import '../statement_password_store.dart';
import '../statements.dart';
import 'database.dart';
import 'ids.dart';
import 'ingest_pipeline.dart';
import 'statement_txns.dart';

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
    this.pipeline,
  }) : _extractor = extractor ?? const PdfrxTextExtractor(),
       _locked = locked ?? MemoryLockedFileStore();

  final PulseDatabase db;
  final StatementPasswordStore passwords;

  /// When set, a statement's lines become transactions (merged with what was
  /// already captured) as soon as they are read.
  final IngestPipeline? pipeline;
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
    final row = await (db.select(
      db.statements,
    )..where((t) => t.id.equals(statementId))).getSingleOrNull();
    final own = row == null ? null : await _ownAccounts(row);
    for (final l in parsed.lines) {
      final c = transferCounterparty(l.description, l.direction);
      if (c == null) continue;
      // Your own account is not someone to settle a split with.
      if (own != null &&
          classifyOwnTransfer(
                merchant: l.description,
                text: l.description,
                direction: l.direction,
                source: own.source,
                accounts: own.all,
              ) !=
              null) {
        continue;
      }
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

  /// Reads a statement file of any supported kind (PDF, CSV, Excel .xlsx,
  /// text). Throws [StatementImportException] with a specific reason and next
  /// step when it cannot; a locked PDF is kept (still encrypted) and the
  /// exception carries its `statementId` so the screen can ask for the
  /// password and retry.
  Future<StatementUpload> upload({
    required Uint8List bytes,
    required String filename,
    String? institution,
    StatementColumns? columns,
    List<List<String>>? rows,
    String source = 'upload',
  }) async {
    if (bytes.isEmpty)
      throw StatementImportException.empty.copyWith(filename: filename);
    final format = sniffFormat(bytes, filename);
    institution ??= _detectFromFilename(filename);
    if (format == StatementFormat.xls ||
        format == StatementFormat.image ||
        format == StatementFormat.unknown) {
      throw StatementImportException.wrongFormat(format)
          .copyWith(filename: filename);
    }
    final sha = sha256.convert(bytes).toString();
    final dup =
        await (db.select(db.statements)
              ..where((t) => t.fileSha256.equals(sha) & t.deletedAt.isNull()))
            .getSingleOrNull();
    if (dup != null) return StatementUpload(dup.id, duplicate: true);

    // Tables and text are read before anything is stored, so a failure leaves
    // no half-imported row behind.
    ParsedStatement? parsed;
    if (format != StatementFormat.pdf) {
      try {
        parsed = _readNonPdf(
          format,
          bytes,
          institution,
          columns: columns,
          rows: rows,
        );
      } on StatementImportException catch (e) {
        throw e.copyWith(filename: filename);
      }
    }
    final id = newId();
    await db
        .into(db.statements)
        .insert(
          StatementsCompanion.insert(
            id: id,
            institution: Value(institution),
            originalFilename: Value(filename),
            fileSha256: Value(sha),
            source: Value(source),
          ),
        );
    if (parsed != null) {
      await _store(id, parsed, parsed.institution ?? institution);
      return StatementUpload(id);
    }
    final problem = await _process(id, bytes, institution);
    if (problem != null) {
      if (problem.problem != StatementProblem.passwordNeeded &&
          problem.problem != StatementProblem.wrongPassword) {
        // Nothing worth keeping: the message is shown right away.
        await (db.delete(db.statements)..where((t) => t.id.equals(id))).go();
        throw problem.copyWith(filename: filename);
      }
      throw problem.copyWith(statementId: id, filename: filename);
    }
    return StatementUpload(id);
  }

  ParsedStatement _readNonPdf(
    StatementFormat format,
    Uint8List bytes,
    String? institution, {
    StatementColumns? columns,
    List<List<String>>? rows,
  }) {
    ParsedStatement fromRows(List<List<String>> r) {
      if (columns == null)
        return readStatementTable(r, institution: institution);
      final p = parseStatementTable(r, columns, institution: institution);
      if (p == null) {
        throw StatementImportException(
          StatementProblem.unrecognisedLayout,
          'No transactions were found with those columns.',
          nextStep: 'Check which column is the date and which is the amount.',
          rows: r,
          institution: institution,
        );
      }
      return p;
    }

    switch (format) {
      case StatementFormat.csv:
        return fromRows(rows ?? parseCsv(decodeText(bytes)));
      case StatementFormat.xlsx:
        final Map<String, List<List<String>>> sheets;
        try {
          sheets = readXlsx(bytes);
        } on FormatException {
          throw StatementImportException.wrongFormat(StatementFormat.unknown);
        }
        if (sheets.values.every(
          (s) => s.every((r) => r.every((c) => c.trim().isEmpty)),
        )) {
          throw StatementImportException.empty;
        }
        if (rows != null) return fromRows(rows);
        StatementImportException? last;
        List<List<String>>? biggest;
        for (final sheet in sheets.values) {
          if (biggest == null || sheet.length > biggest.length) biggest = sheet;
          try {
            return fromRows(sheet);
          } on StatementImportException catch (e) {
            last = e;
          }
        }
        throw last == null
            ? StatementImportException.empty
            : StatementImportException(
                last.problem,
                last.message,
                nextStep: last.nextStep,
                rows: biggest,
                institution: institution,
              );
      case StatementFormat.text:
        final text = decodeText(bytes);
        if (text.trim().isEmpty) throw StatementImportException.empty;
        final inst = institution ?? _detect(text);
        final p = parseStatement(text, institution: inst);
        if (p != null) return p;
        try {
          return fromRows(parseCsv(text));
        } on StatementImportException {
          throw StatementImportException.unsupported(institution: inst);
        }
      default:
        throw StatementImportException.wrongFormat(format);
    }
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

  /// Reads a stored PDF. Returns why it could not be read, or null when its
  /// lines were stored.
  Future<StatementImportException?> _process(
    String id,
    Uint8List bytes,
    String? institution,
  ) async {
    Future<void> setStatus(String status, {String? error}) =>
        (db.update(db.statements)..where((t) => t.id.equals(id))).write(
          StatementsCompanion(
            parseStatus: Value(status),
            parseError: Value(error),
          ),
        );
    Future<StatementImportException> fail(StatementImportException e) async {
      await setStatus('failed', error: '${e.message} ${e.nextStep}'.trim());
      return e;
    }

    final candidates = await _candidates(institution);
    final read = await _extractor.extract(bytes, candidates);
    switch (read.status) {
      case PdfReadStatus.needsPassword:
        await _locked.put(id, bytes);
        await setStatus('needs_password');
        return candidates.isEmpty
            ? StatementImportException(
                StatementProblem.passwordNeeded,
                'This statement is locked with a password.',
                nextStep: 'Enter it once. It stays on this phone and Pulse reads the statement again.',
                institution: institution,
              )
            : StatementImportException(
                StatementProblem.wrongPassword,
                'The saved password did not open this statement.',
                nextStep: 'Check it and enter it again.',
                institution: institution,
              );
      case PdfReadStatus.failed:
        await _locked.remove(id);
        return fail(StatementImportException.damaged);
      case PdfReadStatus.read:
        break;
    }
    await _locked.remove(id);
    if (looksScanned(read.text)) return fail(StatementImportException.scanned);
    final inst = institution ?? _detect(read.text);
    final parsed = parseStatement(read.text, institution: inst);
    if (parsed == null) {
      return fail(StatementImportException.unsupported(institution: inst));
    }
    await _store(id, parsed, inst);
    return null;
  }

  /// Writes a parsed statement's lines and summary.
  Future<void> _store(String id, ParsedStatement parsed, String? inst) async {
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
    await _fillCardFromStatement(parsed, inst);
    final p = pipeline;
    if (p != null) {
      try {
        await importStatementTransactions(
          db,
          p,
          statementId: id,
          parsed: parsed,
          institution: inst,
        );
      } on Object catch (e) {
        // The statement itself is stored; lines can be imported again later.
        debugPrint('Statement lines not imported: $e');
      }
    }
  }

  Future<void> _fillCardFromStatement(
    ParsedStatement parsed,
    String? inst,
  ) async {
    if (parsed.kind != StatementKind.creditCard) return;
    await fillCardFromSummary(
      db,
      last4: parsed.last4,
      institution: inst,
      limitMinor: parsed.creditLimitMinor,
      statementDay: parsed.statementDate?.day,
      dueDay: parsed.dueDate?.day,
    );
  }

  /// What the reconciliation sheet shows: the statement's balances and how its
  /// lines compare with what Pulse captured in the same period.
  Future<Reconciliation> reconciliation(String statementId) async {
    final row = await (db.select(
      db.statements,
    )..where((t) => t.id.equals(statementId))).getSingle();
    final lines =
        await (db.select(db.statementLines)
              ..where((t) => t.statementId.equals(statementId))
              ..orderBy([(t) => OrderingTerm.asc(t.lineNo)]))
            .get();
    final captured =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  (t.source.equals('statement').not() |
                      t.statementId.equals(statementId)),
            ))
            .get();
    final a = _day(row.periodStart), b = _day(row.periodEnd);
    final inPeriod = captured.where((t) {
      if (a == null || b == null) return false;
      final d = DateTime.utc(t.postedAt.year, t.postedAt.month, t.postedAt.day);
      return !d.isBefore(DateTime.utc(a.year, a.month, a.day)) &&
          !d.isAfter(DateTime.utc(b.year, b.month, b.day));
    }).toList();
    final used = <String>{};
    var linked = 0;
    final only = <ReconLine>[];
    final transfers = <ReconLine>[];
    final own = await _ownAccounts(row);
    for (final l in lines) {
      final day = DateTime.parse(l.postedOn).toUtc();
      final hit = inPeriod.where((t) {
        if (used.contains(t.id)) return false;
        return t.amountMinor == l.amountMinor &&
            t.direction == l.direction &&
            t.postedAt.toUtc().difference(day).inDays.abs() <= 1;
      }).firstOrNull;
      if (hit != null) {
        used.add(hit.id);
        linked++;
      } else {
        // Paying a card or moving money between your own accounts is not a
        // purchase to chase: it is listed on its own, never as missing spend.
        final verdict = own == null
            ? null
            : classifyOwnTransfer(
                merchant: l.description,
                text: l.description,
                direction: l.direction == 'credit'
                    ? Direction.credit
                    : Direction.debit,
                source: own.source,
                accounts: own.all,
              );
        (verdict == null ? only : transfers).add(
          ReconLine(
            date: DateTime.parse(l.postedOn),
            description: l.description,
            amount: l.amountMinor / 100,
            credit: l.direction == 'credit',
            reason: verdict?.reason,
          ),
        );
      }
    }
    final missing = [
      for (final t in inPeriod)
        if (!used.contains(t.id))
          ReconLine(
            date: t.postedAt,
            description: t.merchantNormalized ?? t.merchantRaw ?? 'Transaction',
            amount: t.amountMinor / 100,
            credit: t.direction == 'credit',
          ),
    ];
    final diff = row.diffMinor;
    final closing = row.closingBalanceMinor;
    return Reconciliation(
      statementId: statementId,
      status: ReconStatus.fromWire(row.reconciliationStatus),
      opening: row.openingBalanceMinor == null
          ? null
          : row.openingBalanceMinor! / 100,
      closing: closing == null ? null : closing / 100,
      computedClosing: closing == null || diff == null
          ? null
          : (closing - diff) / 100,
      diff: diff == null ? null : diff / 100,
      linked: linked,
      statementOnly: only,
      capturedOnly: missing,
      ownTransfers: transfers,
      warnings: [
        for (final w
            in (jsonDecode(row.summary ?? '{}') as Map)['warnings'] as List? ??
                const [])
          '$w',
      ],
    );
  }

  /// The account this statement is for, and all the user's accounts, for
  /// telling own-account movements from purchases. Null when none is known.
  Future<({OwnAccountRef source, List<OwnAccountRef> all})?> _ownAccounts(
    StatementRow row,
  ) async {
    final accts = await (db.select(
      db.accounts,
    )..where((a) => a.deletedAt.isNull())).get();
    final all = [
      for (final a in accts)
        OwnAccountRef(
          id: a.id,
          type: a.type,
          institution: a.institution,
          name: a.name,
          last4: a.last4,
        ),
    ];
    final summary = row.summary == null
        ? const <String, dynamic>{}
        : jsonDecode(row.summary!) as Map<String, dynamic>;
    final last4 = summary['last4'] as String?;
    final isCard = row.kind == 'credit_card';
    AccountRow? hit;
    if (row.accountId != null) {
      hit = accts.where((a) => a.id == row.accountId).firstOrNull;
    }
    if (hit == null && last4 != null) {
      final c = accts.where((a) => a.last4 == last4).toList();
      if (c.length == 1) hit = c.first;
    }
    if (hit != null) {
      return (source: all.firstWhere((a) => a.id == hit!.id), all: all);
    }
    // Unknown account: the statement still tells its kind and bank.
    return (
      source: OwnAccountRef(
        id: 'statement:${row.id}',
        type: isCard ? 'credit_card' : 'bank',
        institution: row.institution,
        last4: last4,
      ),
      all: all,
    );
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

/// A card added with only its name gets its limit, statement day and due day
/// from the first statement that names it, however the statement arrived
/// (uploaded PDF, or the summary of an emailed one). Only empty fields are
/// filled, so anything the person typed stays. The card is the one with the
/// same last four digits, or the only card of that bank still without digits.
Future<void> fillCardFromSummary(
  PulseDatabase db, {
  String? last4,
  String? institution,
  int? limitMinor,
  int? statementDay,
  int? dueDay,
}) async {
  final cards = await (db.select(
    db.accounts,
  )..where((a) => a.type.equals('credit_card') & a.deletedAt.isNull())).get();
  AccountRow? target;
  if (last4 != null) {
    target = cards.where((c) => c.last4 == last4).firstOrNull;
  }
  if (target == null && institution != null) {
    // Statements carry a short bank code ("enbd") and the card a display name
    // ("Emirates NBD"): the code's letters appear in order in the name.
    bool isSubsequence(String code, String name) {
      var i = 0;
      for (final ch in name.split('')) {
        if (i < code.length && ch == code[i]) i++;
      }
      return i == code.length;
    }

    String key(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final bank = key(institution);
    final same = [
      for (final c in cards)
        if (c.last4 == null &&
            bank.isNotEmpty &&
            isSubsequence(bank, key(c.institution ?? '')))
          c,
    ];
    if (same.length == 1) target = same.single;
  }
  if (target == null) return;
  final t = target;
  await (db.update(db.accounts)..where((a) => a.id.equals(t.id))).write(
    AccountsCompanion(
      last4: t.last4 == null && last4 != null
          ? Value(last4)
          : const Value.absent(),
      creditLimitMinor: t.creditLimitMinor == null && limitMinor != null
          ? Value(limitMinor)
          : const Value.absent(),
      statementDay: t.statementDay == null && statementDay != null
          ? Value(statementDay)
          : const Value.absent(),
      dueDay: t.dueDay == null && dueDay != null
          ? Value(dueDay)
          : const Value.absent(),
    ),
  );
}
