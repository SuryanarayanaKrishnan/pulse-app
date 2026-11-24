import 'dart:async';

import 'backup_controller.dart';
import 'backup_engine.dart';
import 'backup_state.dart';

/// Backup controller for the demo build (no database, no network): enough
/// behaviour to walk through the screens. Nothing is stored or uploaded.
class DemoBackupController implements BackupController {
  DemoBackupController({BackupState? initial, DateTime? now})
    : _state =
          initial ??
          BackupState(
            enabled: true,
            lastSuccess: (now ?? DateTime.now()).subtract(
              const Duration(hours: 2),
            ),
            lastBytes: 3 << 20,
          );
  BackupState _state;
  final _ctl = StreamController<BackupState>.broadcast();

  void _set(BackupState s) {
    _state = s;
    _ctl.add(s);
  }

  @override
  BackupState get state => _state;
  @override
  Stream<BackupState> get changes => _ctl.stream;
  @override
  bool get cloudAvailable => true;

  @override
  Future<void> enable({
    required String secret,
    required String secretKind,
    required BackupDestination destination,
    bool replaceExisting = false,
  }) async {
    _set(
      BackupState(
        enabled: true,
        destination: destination,
        secretKind: secretKind,
        lastSuccess: DateTime.now(),
      ),
    );
  }

  @override
  Future<BackupStats?> backupNow({String trigger = 'manual'}) async {
    _set(_state.copyWith(running: true, progress: 0));
    for (var i = 1; i <= 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _set(_state.copyWith(progress: i / 4));
    }
    _set(
      _state.copyWith(
        running: false,
        lastSuccess: DateTime.now(),
        lastError: null,
        failures: 0,
        dirty: false,
      ),
    );
    return null;
  }

  @override
  Future<void> changePassphrase({
    required String current,
    required String next,
    required String nextKind,
  }) async => _set(_state.copyWith(secretKind: nextKind));
  @override
  Future<void> setAuto(bool v) async => _set(_state.copyWith(auto: v));
  @override
  Future<void> setWifiOnly(bool v) async => _set(_state.copyWith(wifiOnly: v));
  @override
  Future<void> setKeep(int n) async => _set(_state.copyWith(keep: n));
  @override
  Future<void> setDestination(BackupDestination d) async =>
      _set(_state.copyWith(destination: d));
  @override
  Future<String> exportArchive() async =>
      throw UnsupportedError('Export needs the iOS or Android app.');
  @override
  Future<void> deleteCloudBackup() async => _set(const BackupState());
  @override
  Future<void> disable() async => _set(const BackupState());
}
