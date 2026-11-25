/// Inactivity check-ins and the sealed emergency export.
///
/// Sealing: a random 128-bit release secret per nominee is split with Shamir
/// 2-of-3 (owner, nominee, escrow). The export is encrypted with a key
/// derived from that secret, so no single holder, and not the relay that
/// stores the ciphertext, can open it.
///
/// What is NOT here: the thing that notices the owner has gone quiet and
/// hands the file over. That needs a server (see [InactivityRelay]); only an
/// interface and an in-memory fake exist.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';

import '../../backup/backup_crypto.dart';
import 'emergency_sheet.dart';
import 'shamir.dart';
import 'vault_models.dart';

// ---- check-in -----------------------------------------------------------

const checkInChoices = [60, 90, 180, 365];
const defaultCheckInDays = 90;

/// Days before the release date when the app starts gently reminding.
const reminderWindowDays = 14;

enum CheckInPhase { ok, soon, overdue }

class CheckInStatus {
  const CheckInStatus(this.phase, this.daysLeft, this.releaseAt);
  final CheckInPhase phase;

  /// Whole days until release; zero or negative once overdue.
  final int daysLeft;
  final DateTime releaseAt;
}

/// Opening the app is the check-in: [lastCheckIn] is the last time it was.
CheckInStatus checkInStatus({
  required DateTime lastCheckIn,
  required int intervalDays,
  required DateTime now,
}) {
  final releaseAt = lastCheckIn.add(Duration(days: intervalDays));
  final left = releaseAt.difference(now);
  final days = left.isNegative
      ? -((-left.inHours) ~/ 24)
      : (left.inHours + 23) ~/ 24;
  final phase = left.isNegative || left == Duration.zero
      ? CheckInPhase.overdue
      : days <= reminderWindowDays
      ? CheckInPhase.soon
      : CheckInPhase.ok;
  return CheckInStatus(phase, days, releaseAt);
}

// ---- sealed export --------------------------------------------------------

/// What the owner is handed when a kit is made. Only [ownerShare] is kept on
/// the owner's phone; the others are shown once and handed over.
class ReleaseKit {
  const ReleaseKit({
    required this.nomineeId,
    required this.ownerShare,
    required this.nomineeShare,
    required this.escrowShare,
    required this.claimCode,
    required this.sealedFile,
    required this.createdAt,
    this.papersIncluded = 0,
    this.papersLeftOut = 0,
  });
  final String nomineeId;

  /// Photos and PDFs sealed into the file, and how many did not fit.
  final int papersIncluded, papersLeftOut;
  final String ownerShare, nomineeShare, escrowShare;

  /// Presented to the relay by the nominee; the relay keeps only its hash.
  final String claimCode;

  /// JSON text, safe to store anywhere: it is ciphertext.
  final String sealedFile;
  final DateTime createdAt;

  String get claimCodeHash => hashClaimCode(claimCode);
}

class OpenedVault {
  const OpenedVault({
    required this.ownerName,
    required this.nomineeName,
    required this.preparedAt,
    required this.entries,
    required this.sheet,
    this.papers = const {},
  });
  final String ownerName, nomineeName, sheet;
  final DateTime preparedAt;
  final List<VaultEntry> entries;

  /// Decrypted papers by entry id, in the order they were added.
  final Map<String, List<Uint8List>> papers;
}

/// Most paper bytes sealed into one file. Photos and PDFs travel inside the
/// ciphertext, so the relay and any chat app that carries the file see only
/// noise; the cap keeps the file small enough to send.
const maxSealedPaperBytes = 12 * 1024 * 1024;

class VaultOpenException implements Exception {
  const VaultOpenException(this.message);
  final String message;
  @override
  String toString() => message;
}

String hashClaimCode(String code) =>
    c.sha256.convert(utf8.encode(normaliseClaimCode(code))).toString();

String normaliseClaimCode(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

abstract final class VaultSeal {
  static const _info = 'pulse.vault.release.v1';
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String newClaimCode(Random random) {
    final chars = [
      for (var i = 0; i < 12; i++) _alphabet[random.nextInt(_alphabet.length)],
    ];
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4, 8).join()}-${chars.sublist(8).join()}';
  }

  static Future<SecretKey> _key(List<int> secret, List<int> salt) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(secret),
        nonce: salt,
        info: utf8.encode(_info),
      );

  static List<int> _aad(String nomineeId, String saltB64) =>
      utf8.encode('pulse-vault|1|$nomineeId|$saltB64');

  /// Seals what [nominee] may see. A fresh secret every time: the old codes
  /// stop opening the new file, and the new file is the one to keep.
  static Future<ReleaseKit> createKit({
    required String ownerName,
    required Nominee nominee,
    required List<VaultEntry> entries,
    required DateTime now,
    Random? random,
    Future<Uint8List?> Function(String path)? readPaper,
    int maxPaperBytes = maxSealedPaperBytes,
  }) async {
    final rnd = random ?? Random.secure();
    final secret = Uint8List.fromList([
      for (var i = 0; i < 16; i++) rnd.nextInt(256),
    ]);
    final salt = Uint8List.fromList([
      for (var i = 0; i < 16; i++) rnd.nextInt(256),
    ]);
    final shares = Shamir.split(secret, threshold: 2, shares: 3, random: rnd);
    final visible = visibleTo(nominee, entries);
    final papers = <String, List<String>>{};
    var used = 0, included = 0, leftOut = 0;
    for (final e in visible) {
      for (final path in e.photoPaths) {
        Uint8List? bytes;
        try {
          bytes = readPaper == null ? null : await readPaper(path);
        } catch (_) {
          bytes = null;
        }
        if (bytes == null || bytes.isEmpty) continue;
        if (used + bytes.length > maxPaperBytes) {
          leftOut++;
          continue;
        }
        used += bytes.length;
        included++;
        (papers[e.id] ??= []).add(base64Encode(bytes));
      }
    }
    final payload = jsonEncode({
      'owner': ownerName,
      'nominee': nominee.name,
      'at': now.toUtc().toIso8601String(),
      'entries': [for (final e in visible) e.toExportJson()],
      if (papers.isNotEmpty) 'papers': papers,
    });
    final saltB64 = base64Encode(salt);
    final sealed = await BackupCrypto.seal(
      await _key(secret, salt),
      utf8.encode(payload),
      aad: _aad(nominee.id, saltB64),
    );
    final file = jsonEncode({
      'app': 'pulse-vault',
      'v': 1,
      'for': nominee.id,
      'salt': saltB64,
      'ct': base64Encode(sealed),
    });
    return ReleaseKit(
      nomineeId: nominee.id,
      ownerShare: shares[0].encode(),
      nomineeShare: shares[1].encode(),
      escrowShare: shares[2].encode(),
      claimCode: newClaimCode(rnd),
      sealedFile: file,
      createdAt: now,
      papersIncluded: included,
      papersLeftOut: leftOut,
    );
  }

  /// Opens a sealed file with any two shares (as typed or pasted). Throws
  /// [VaultOpenException] with a calm message for every failure.
  static Future<OpenedVault> open(
    String sealedFile,
    List<String> shareTexts,
  ) async {
    final Map<String, dynamic> file;
    try {
      file = jsonDecode(sealedFile) as Map<String, dynamic>;
      if (file['app'] != 'pulse-vault' || file['v'] != 1)
        throw const FormatException();
    } catch (_) {
      throw const VaultOpenException('That is not a Pulse emergency file.');
    }
    final List<ShamirShare> shares;
    try {
      shares = [for (final t in shareTexts) ShamirShare.parse(t)];
    } on ShamirException catch (e) {
      throw VaultOpenException(e.message);
    }
    final Uint8List secret;
    try {
      secret = Shamir.combine(shares);
    } on ShamirException catch (e) {
      throw VaultOpenException(e.message);
    }
    try {
      final saltB64 = file['salt'] as String;
      final plain = await BackupCrypto.open(
        await _key(secret, base64Decode(saltB64)),
        Uint8List.fromList(base64Decode(file['ct'] as String)),
        aad: _aad(file['for'] as String, saltB64),
      );
      final j = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      final entries = [
        for (final e in j['entries'] as List)
          VaultEntry.fromExportJson(e as Map<String, dynamic>),
      ];
      final papers = <String, List<Uint8List>>{
        for (final kv in ((j['papers'] as Map?) ?? const {}).entries)
          kv.key as String: [
            for (final b in kv.value as List)
              Uint8List.fromList(base64Decode(b as String)),
          ],
      };
      final at = DateTime.parse(j['at'] as String);
      final owner = j['owner'] as String? ?? '';
      final nomineeName = j['nominee'] as String? ?? '';
      return OpenedVault(
        ownerName: owner,
        nomineeName: nomineeName,
        preparedAt: at,
        entries: entries,
        papers: papers,
        sheet: emergencySheet(ownerName: owner, entries: entries, now: at),
      );
    } on BackupIntegrityError {
      throw const VaultOpenException(
        'Those key shares do not open this file. Check that they belong to this file and that two different shares are used.',
      );
    } on FormatException {
      throw const VaultOpenException('That file could not be read.');
    }
  }
}

// ---- the server half (not built) -------------------------------------------

sealed class ClaimResult {
  const ClaimResult();
}

/// The owner has been active within the interval.
class ClaimNotYet extends ClaimResult {
  const ClaimNotYet(this.daysLeft);
  final int daysLeft;
}

class ClaimWrongCode extends ClaimResult {
  const ClaimWrongCode({this.locked = false});
  final bool locked;
}

class ClaimReleased extends ClaimResult {
  const ClaimReleased(this.sealedFile);
  final String sealedFile;
}

class ClaimUnavailable extends ClaimResult {
  const ClaimUnavailable();
}

/// What a server must do for automatic release. It only ever sees ciphertext
/// and a hash of the claim code. NOT IMPLEMENTED against a real service: see
/// docs/VAULT.md. [InMemoryInactivityRelay] is the fake used by tests.
abstract class InactivityRelay {
  /// False for the production stub: nothing will be released automatically.
  bool get isAvailable;

  /// Stores the sealed file for [nomineeId] and starts the countdown.
  Future<void> arm({
    required String nomineeId,
    required String sealedFile,
    required String claimCodeHash,
    required int intervalDays,
    required DateTime now,
  });

  /// The owner opened the app: restarts every countdown.
  Future<void> heartbeat(DateTime now);

  /// Changes the interval for everything armed.
  Future<void> setInterval(int intervalDays);

  Future<void> disarm(String nomineeId);

  /// Asked by the nominee, not the owner.
  Future<ClaimResult> claim({
    required String nomineeId,
    required String claimCode,
    required DateTime now,
  });
}

/// The production default: the server component does not exist yet.
class UnavailableInactivityRelay implements InactivityRelay {
  const UnavailableInactivityRelay();
  @override
  bool get isAvailable => false;
  @override
  Future<void> arm({
    required String nomineeId,
    required String sealedFile,
    required String claimCodeHash,
    required int intervalDays,
    required DateTime now,
  }) async {}
  @override
  Future<void> heartbeat(DateTime now) async {}
  @override
  Future<void> setInterval(int intervalDays) async {}
  @override
  Future<void> disarm(String nomineeId) async {}
  @override
  Future<ClaimResult> claim({
    required String nomineeId,
    required String claimCode,
    required DateTime now,
  }) async => const ClaimUnavailable();
}

/// A faithful-enough server for tests and simulations.
class InMemoryInactivityRelay implements InactivityRelay {
  InMemoryInactivityRelay({this.maxWrongCodes = 5});
  final int maxWrongCodes;

  final _armed = <String, _Armed>{};
  DateTime? _lastHeartbeat;
  int _interval = defaultCheckInDays;

  @override
  bool get isAvailable => true;

  bool isArmed(String nomineeId) => _armed.containsKey(nomineeId);

  /// Everything the "server" holds, for tests that check it learns nothing.
  Iterable<String> get storedStrings => [
    for (final a in _armed.values) ...[a.sealedFile, a.hash],
  ];

  @override
  Future<void> arm({
    required String nomineeId,
    required String sealedFile,
    required String claimCodeHash,
    required int intervalDays,
    required DateTime now,
  }) async {
    _armed[nomineeId] = _Armed(sealedFile, claimCodeHash);
    _interval = intervalDays;
    _lastHeartbeat = now;
  }

  @override
  Future<void> heartbeat(DateTime now) async {
    if (_armed.isNotEmpty) _lastHeartbeat = now;
  }

  @override
  Future<void> setInterval(int intervalDays) async => _interval = intervalDays;

  @override
  Future<void> disarm(String nomineeId) async => _armed.remove(nomineeId);

  @override
  Future<ClaimResult> claim({
    required String nomineeId,
    required String claimCode,
    required DateTime now,
  }) async {
    final a = _armed[nomineeId];
    if (a == null) return const ClaimWrongCode();
    if (a.wrong >= maxWrongCodes) return const ClaimWrongCode(locked: true);
    if (a.hash != hashClaimCode(claimCode)) {
      a.wrong++;
      return ClaimWrongCode(locked: a.wrong >= maxWrongCodes);
    }
    final st = checkInStatus(
      lastCheckIn: _lastHeartbeat!,
      intervalDays: _interval,
      now: now,
    );
    if (st.phase != CheckInPhase.overdue) return ClaimNotYet(st.daysLeft);
    return ClaimReleased(a.sealedFile);
  }
}

class _Armed {
  _Armed(this.sealedFile, this.hash);
  final String sealedFile, hash;
  int wrong = 0;
}
