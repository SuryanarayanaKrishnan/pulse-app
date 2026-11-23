/// Monthly close: statements, reconciliation, statement passwords and mail
/// connections.
library;

/// UAE institutions the backend can parse, by canonical key.
const institutions = <String, String>{
  'enbd': 'Emirates NBD',
  'adcb': 'ADCB',
  'fab': 'First Abu Dhabi Bank',
  'mashreq': 'Mashreq',
  'rakbank': 'RAKBANK',
  'dib': 'Dubai Islamic Bank',
  'adib': 'Abu Dhabi Islamic Bank',
  'hsbc': 'HSBC UAE',
  'citi': 'Citi UAE',
  'cbd': 'Commercial Bank of Dubai',
  'eib': 'Emirates Islamic',
  'liv': 'Liv',
};

String institutionName(String? key) =>
    key == null ? 'Unknown bank' : (institutions[key] ?? key);

enum ParseStatus {
  pending,
  parsed,
  failed,
  needsReview,
  skipped,
  needsPassword;

  static ParseStatus fromWire(String? s) => switch (s) {
    'parsed' => parsed,
    'failed' => failed,
    'needs_review' => needsReview,
    'skipped' => skipped,
    'needs_password' => needsPassword,
    _ => pending,
  };
}

enum ReconStatus {
  pending,
  matched,
  mismatch;

  static ReconStatus fromWire(String? s) => switch (s) {
    'matched' => matched,
    'mismatch' => mismatch,
    _ => pending,
  };
}

/// What the user sees for one statement, collapsed from parse and
/// reconciliation status.
enum CloseState { matched, mismatch, needsPassword, needsAccount, processing, failed }

class Statement {
  const Statement({
    required this.id,
    required this.institution,
    required this.accountLabel,
    required this.parse,
    required this.recon,
    this.accountId,
    this.periodStart,
    this.periodEnd,
    this.diff,
    this.source = 'upload',
    this.filename,
    this.parseError,
  });

  final String id;

  /// Canonical institution key (e.g. `enbd`), when known.
  final String? institution;
  final String? accountId;
  final String accountLabel;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final ParseStatus parse;
  final ReconStatus recon;

  /// Computed minus printed closing balance (AED) when mismatched.
  final double? diff;

  /// `upload` | `gmail`
  final String source;
  final String? filename;
  final String? parseError;

  CloseState get state => switch (parse) {
    ParseStatus.needsPassword => CloseState.needsPassword,
    ParseStatus.needsReview => CloseState.needsAccount,
    ParseStatus.failed || ParseStatus.skipped => CloseState.failed,
    ParseStatus.pending => CloseState.processing,
    ParseStatus.parsed => switch (recon) {
      ReconStatus.matched => CloseState.matched,
      ReconStatus.mismatch => CloseState.mismatch,
      ReconStatus.pending => CloseState.processing,
    },
  };

  bool get needsAttention =>
      state != CloseState.matched && state != CloseState.processing;

  Statement copyWith({ParseStatus? parse, ReconStatus? recon, double? diff}) =>
      Statement(
        id: id,
        institution: institution,
        accountId: accountId,
        accountLabel: accountLabel,
        periodStart: periodStart,
        periodEnd: periodEnd,
        parse: parse ?? this.parse,
        recon: recon ?? this.recon,
        diff: diff ?? this.diff,
        source: source,
        filename: filename,
        parseError: parseError,
      );
}

class ReconLine {
  const ReconLine({
    required this.date,
    required this.description,
    required this.amount,
    this.credit = false,
  });
  final DateTime date;
  final String description;
  final double amount;
  final bool credit;
}

class Reconciliation {
  const Reconciliation({
    required this.statementId,
    required this.status,
    this.opening,
    this.closing,
    this.computedClosing,
    this.diff,
    this.linked = 0,
    this.statementOnly = const [],
    this.capturedOnly = const [],
    this.warnings = const [],
  });
  final String statementId;
  final ReconStatus status;
  final double? opening;
  final double? closing;
  final double? computedClosing;
  final double? diff;

  /// Statement lines matched to something Pulse had already captured.
  final int linked;

  /// On the statement, never captured (added to the ledger from the
  /// statement).
  final List<ReconLine> statementOnly;

  /// Captured in the period but not on the statement.
  final List<ReconLine> capturedOnly;
  final List<String> warnings;
}

class StatementPassword {
  const StatementPassword(this.institution, this.updatedAt);
  final String institution;
  final DateTime updatedAt;
}

class EmailConnection {
  const EmailConnection({
    required this.id,
    required this.email,
    required this.status,
    this.lastSyncedAt,
  });
  final String id;
  final String email;

  /// `active` | `needs_reauth` | ...
  final String status;
  final DateTime? lastSyncedAt;
  bool get active => status == 'active';
}

class UploadResult {
  const UploadResult({required this.id, required this.duplicate});
  final String id;
  final bool duplicate;
}
