import 'dart:convert';

enum BackupDestination {
  /// Supabase Storage, through the signed-in account.
  cloud,

  /// No automatic upload: the user exports the encrypted file when they want.
  file;

  String get analyticsName => name;
}

/// Everything the Backup screen shows. Persisted (no secrets in it).
class BackupState {
  const BackupState({
    this.enabled = false,
    this.destination = BackupDestination.cloud,
    this.secretKind = 'phrase',
    this.auto = true,
    this.wifiOnly = true,
    this.keep = 5,
    this.lastSuccess,
    this.lastAttempt,
    this.lastError,
    this.failures = 0,
    this.running = false,
    this.progress = 0,
    this.dirty = false,
    this.lastBytes = 0,
  });

  final bool enabled;
  final BackupDestination destination;

  /// `phrase` or `passphrase` (a hint for the unlock prompt).
  final String secretKind;
  final bool auto;
  final bool wifiOnly;
  final int keep;
  final DateTime? lastSuccess;
  final DateTime? lastAttempt;

  /// A calm, user-facing sentence; null when the last run was fine.
  final String? lastError;
  final int failures;
  final bool running;
  final double progress;

  /// Something changed since the last good backup.
  final bool dirty;
  final int lastBytes;

  bool get cloud => enabled && destination == BackupDestination.cloud;

  /// Three failures in a row, or no success for two days while changes wait.
  bool needsAttention(DateTime now) =>
      cloud &&
      lastError != null &&
      (failures >= 3 ||
          (lastSuccess != null &&
              now.difference(lastSuccess!).inDays >= 2 &&
              dirty));

  BackupState copyWith({
    bool? enabled,
    BackupDestination? destination,
    String? secretKind,
    bool? auto,
    bool? wifiOnly,
    int? keep,
    DateTime? lastSuccess,
    DateTime? lastAttempt,
    Object? lastError = _keep,
    int? failures,
    bool? running,
    double? progress,
    bool? dirty,
    int? lastBytes,
  }) => BackupState(
    enabled: enabled ?? this.enabled,
    destination: destination ?? this.destination,
    secretKind: secretKind ?? this.secretKind,
    auto: auto ?? this.auto,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    keep: keep ?? this.keep,
    lastSuccess: lastSuccess ?? this.lastSuccess,
    lastAttempt: lastAttempt ?? this.lastAttempt,
    lastError: identical(lastError, _keep)
        ? this.lastError
        : lastError as String?,
    failures: failures ?? this.failures,
    running: running ?? this.running,
    progress: progress ?? this.progress,
    dirty: dirty ?? this.dirty,
    lastBytes: lastBytes ?? this.lastBytes,
  );

  static const _keep = Object();

  String toJson() => jsonEncode({
    'enabled': enabled,
    'destination': destination.name,
    'kind': secretKind,
    'auto': auto,
    'wifiOnly': wifiOnly,
    'keep': keep,
    'lastSuccess': lastSuccess?.toIso8601String(),
    'lastAttempt': lastAttempt?.toIso8601String(),
    'lastError': lastError,
    'failures': failures,
    'dirty': dirty,
    'lastBytes': lastBytes,
  });

  static BackupState fromJson(String? s) {
    if (s == null) return const BackupState();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return BackupState(
        enabled: j['enabled'] as bool? ?? false,
        destination: BackupDestination.values.firstWhere(
          (d) => d.name == j['destination'],
          orElse: () => BackupDestination.cloud,
        ),
        secretKind: j['kind'] as String? ?? 'phrase',
        auto: j['auto'] as bool? ?? true,
        wifiOnly: j['wifiOnly'] as bool? ?? true,
        keep: (j['keep'] as int?) ?? 5,
        lastSuccess: DateTime.tryParse(j['lastSuccess'] as String? ?? ''),
        lastAttempt: DateTime.tryParse(j['lastAttempt'] as String? ?? ''),
        lastError: j['lastError'] as String?,
        failures: j['failures'] as int? ?? 0,
        dirty: j['dirty'] as bool? ?? false,
        lastBytes: j['lastBytes'] as int? ?? 0,
      );
    } catch (_) {
      return const BackupState();
    }
  }
}

/// "Last backed up 2 hours ago", "...yesterday", "...just now".
String backedUpAgo(DateTime? when, DateTime now) {
  if (when == null) return 'Not backed up yet';
  final d = now.difference(when);
  if (d.inSeconds < 60) return 'Last backed up just now';
  if (d.inMinutes < 60) return 'Last backed up ${d.inMinutes} min ago';
  if (d.inHours < 24)
    return 'Last backed up ${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'} ago';
  if (d.inDays == 1) return 'Last backed up yesterday';
  return 'Last backed up ${d.inDays} days ago';
}

String sizeBucket(int bytes) {
  if (bytes < 1 << 20) return '<1MB';
  if (bytes < 10 << 20) return '1-10MB';
  if (bytes < 100 << 20) return '10-100MB';
  return '>100MB';
}

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1 << 20) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1 << 30) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
  return '${(b / (1 << 30)).toStringAsFixed(2)} GB';
}
