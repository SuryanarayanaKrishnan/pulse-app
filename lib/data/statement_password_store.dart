import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'statements.dart';

/// Statement PDF passwords, kept on this device only.
///
/// They live in the iOS Keychain (this device only, so not in iCloud backups
/// or sync) or the Android Keystore. They are never part of backup, sync or an
/// API call, and the UI never reads one back: [read] is for the on-device
/// statement reader.
abstract class StatementPasswordStore {
  /// Banks with a saved password and when it was last set.
  Future<List<StatementPassword>> saved();
  Future<String?> read(String institution);
  Future<void> save(String institution, String password);
  Future<void> remove(String institution);
}

class SecureStatementPasswordStore implements StatementPasswordStore {
  SecureStatementPasswordStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  static const _prefix = 'pulse.statement_pw.v1.';
  static const _atSuffix = '.at';

  @override
  Future<List<StatementPassword>> saved() async {
    final all = await _storage.readAll();
    return [
      for (final e in all.entries)
        if (e.key.startsWith(_prefix) && e.key.endsWith(_atSuffix))
          StatementPassword(
            e.key.substring(_prefix.length, e.key.length - _atSuffix.length),
            DateTime.tryParse(e.value) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
    ]..sort((a, b) => a.institution.compareTo(b.institution));
  }

  @override
  Future<String?> read(String institution) =>
      _storage.read(key: '$_prefix$institution');

  @override
  Future<void> save(String institution, String password) async {
    await _storage.write(key: '$_prefix$institution', value: password);
    await _storage.write(
      key: '$_prefix$institution$_atSuffix',
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> remove(String institution) async {
    await _storage.delete(key: '$_prefix$institution');
    await _storage.delete(key: '$_prefix$institution$_atSuffix');
  }
}

/// For tests and demo data.
class MemoryStatementPasswordStore implements StatementPasswordStore {
  final _pw = <String, String>{};
  final _at = <String, DateTime>{};

  @override
  Future<List<StatementPassword>> saved() async =>
      [for (final e in _at.entries) StatementPassword(e.key, e.value)]
        ..sort((a, b) => a.institution.compareTo(b.institution));

  @override
  Future<String?> read(String institution) async => _pw[institution];

  @override
  Future<void> save(String institution, String password) async {
    _pw[institution] = password;
    _at[institution] = DateTime.now();
  }

  @override
  Future<void> remove(String institution) async {
    _pw.remove(institution);
    _at.remove(institution);
  }
}
