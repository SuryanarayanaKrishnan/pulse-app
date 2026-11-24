import 'package:bip39/bip39.dart' as bip39;

/// A 12-word recovery phrase (128 bits of entropy plus a 4-bit checksum) from
/// the BIP-39 English list, so typos are detected before any key derivation.
class RecoveryPhrase {
  RecoveryPhrase._();

  static List<String> generate() => bip39.generateMnemonic(strength: 128).split(' ');

  static bool isValid(String phrase) => bip39.validateMnemonic(normalize(phrase));

  /// Lower-case, single spaces.
  static String normalize(String phrase) => phrase.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

  /// What actually goes into the key derivation. A valid phrase is normalised
  /// so capitalisation and spacing never matter; anything else is treated as
  /// a passphrase and only trimmed.
  static String secretFrom(String input) => isValid(input) ? normalize(input) : input.trim();

  static bool looksLikePhrase(String input) => isValid(input);
}

/// A rough, honest strength read-out for the passphrase field.
enum PassphraseStrength { tooShort, fair, good }

PassphraseStrength passphraseStrength(String s) {
  final t = s.trim();
  if (t.length < 10) return PassphraseStrength.tooShort;
  final classes = [
    RegExp(r'[a-z]'),
    RegExp(r'[A-Z]'),
    RegExp(r'[0-9]'),
    RegExp(r'[^A-Za-z0-9]'),
  ].where((r) => r.hasMatch(t)).length;
  final words = t.split(RegExp(r'\s+')).length;
  return (t.length >= 16 || (t.length >= 12 && classes >= 3) || words >= 4) ? PassphraseStrength.good : PassphraseStrength.fair;
}
