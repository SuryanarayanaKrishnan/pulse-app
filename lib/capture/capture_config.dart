/// Which messages and notifications Pulse is allowed to look at. Everything
/// else is discarded on the device and never stored or uploaded.
///
/// The Android layer persists this and applies it in the receivers, so the
/// filter also holds when the app process is not running.
class CaptureConfig {
  const CaptureConfig({
    this.bankSenderIds = defaultBankSenderIds,
    this.walletPackages = defaultWalletPackages,
    this.bankAppPackages = defaultBankAppPackages,
    this.bankPackageHints = defaultBankPackageHints,
    this.backfillDays = 90,
  });

  /// UAE bank SMS sender IDs. Matching ignores case and punctuation; IDs of
  /// four characters or fewer must match exactly, longer ones may be a
  /// substring (carriers sometimes prefix, e.g. `AD-ADCBAlert`).
  static const defaultBankSenderIds = [
    'EmiratesNBD',
    'ENBD',
    'ADCBAlert',
    'ADCB',
    'FAB',
    'Mashreq',
    'MashreqBank',
    'RAKBANK',
    'DIB',
    'ADIB',
    'HSBC',
    'CBD',
    'EIB',
    'Liv',
    'Wio',
    'NBF',
    'CBI',
    'AjmanBank',
    'SIB',
    'NoorBank',
    'ENBDLiv',
    'StandardChartered',
    'CitiBank',
  ];

  /// Wallet apps whose notifications are always forwarded.
  static const defaultWalletPackages = [
    'com.google.android.apps.walletnfcrel', // Google Wallet
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.samsung.android.spay', // Samsung Wallet / Pay
    'com.samsung.android.samsungpay.gear', // Samsung Pay (Gear)
  ];

  /// Exact bank app package names. Package IDs vary by bank and release;
  /// add verified ones here. Empty by default on purpose.
  static const defaultBankAppPackages = <String>[];

  /// Case-insensitive substrings; a notification from any package containing
  /// one of these is treated as a bank app. Matching is on the package name,
  /// never on the message text.
  static const defaultBankPackageHints = [
    'enbd',
    'emiratesnbd',
    'adcb',
    'mashreq',
    'rakbank',
    'adib',
    'hsbc',
  ];

  final List<String> bankSenderIds;
  final List<String> walletPackages;
  final List<String> bankAppPackages;
  final List<String> bankPackageHints;

  /// How far back the one-time inbox backfill reads.
  final int backfillDays;

  Map<String, Object?> toMap() => {
    'senders': bankSenderIds,
    'walletPackages': walletPackages,
    'bankPackages': bankAppPackages,
    'bankPackageHints': bankPackageHints,
  };
}
