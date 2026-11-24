/// Keeps secrets out of the vault. The vault says where things are, never the
/// password, PIN or card number, so this refuses obvious ones in any free text.
///
/// It is a safety net, not a guarantee: it catches the common shapes (card
/// numbers that pass the Luhn check, valid or UAE-shaped IBANs, "password:
/// ...", "PIN 1234", seed phrases). A determined person can still type a
/// secret in a disguised form; the UI says so.
library;

enum GuardKind { card, iban, password, pin, seedPhrase, emiratesId }

class GuardIssue {
  const GuardIssue(this.kind, this.message, {this.blocking = true});
  final GuardKind kind;
  final String message;

  /// Blocking issues stop a save; others are a gentle heads-up.
  final bool blocking;
}

abstract final class InputGuard {
  /// Every issue found in [text] (empty when it is fine).
  static List<GuardIssue> check(String text) {
    final issues = <GuardIssue>[];
    if (text.trim().isEmpty) return issues;
    if (_hasCardNumber(text)) {
      issues.add(
        const GuardIssue(
          GuardKind.card,
          'This looks like a full card number. Write only which card it is, for example "Visa ending 4242".',
        ),
      );
    }
    if (_hasIban(text)) {
      issues.add(
        const GuardIssue(
          GuardKind.iban,
          'This looks like a full IBAN. Say which bank and account it is instead, for example "Salary account, IBAN ends 1234".',
        ),
      );
    }
    final pw = _passwordIssue(text);
    if (pw != null) issues.add(pw);
    if (_hasSeedPhrase(text)) {
      issues.add(
        const GuardIssue(
          GuardKind.seedPhrase,
          'This looks like a recovery phrase. Never write those here: say where the paper copy is kept.',
        ),
      );
    }
    if (_emiratesId.hasMatch(text)) {
      issues.add(
        const GuardIssue(
          GuardKind.emiratesId,
          'This looks like an Emirates ID number. You only need to say where the card is kept.',
          blocking: false,
        ),
      );
    }
    return issues;
  }

  static List<GuardIssue> blocking(String text) => [
    for (final i in check(text))
      if (i.blocking) i,
  ];

  /// The first blocking message across several fields, or null.
  static String? firstProblem(Iterable<String> fields) {
    for (final f in fields) {
      final b = blocking(f);
      if (b.isNotEmpty) return b.first.message;
    }
    return null;
  }

  // ---- card numbers ----------------------------------------------------

  static final _digitRun = RegExp(r'(?<!\d)\d(?:[ \-]?\d){12,18}(?!\d)');
  static final _fourGroups = RegExp(
    r'(?<!\d)\d{4}([ \-])\d{4}\1\d{4}\1\d{4}(?!\d)',
  );

  static bool _hasCardNumber(String t) {
    for (final m in _digitRun.allMatches(t)) {
      final digits = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 13 && digits.length <= 19 && luhn(digits))
        return true;
    }
    return _fourGroups.hasMatch(t);
  }

  static bool luhn(String digits) {
    var sum = 0;
    var alt = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 48;
      if (d < 0 || d > 9) return false;
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  // ---- IBAN ------------------------------------------------------------

  static final _ibanCandidate = RegExp(
    r'(?<![A-Za-z0-9])[A-Za-z]{2}\d{2}(?:[ \-]?[A-Za-z0-9]){11,30}(?![A-Za-z0-9])',
  );

  static bool _hasIban(String t) {
    for (final m in _ibanCandidate.allMatches(t)) {
      final s = m
          .group(0)!
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .toUpperCase();
      if (s.length < 15 || s.length > 34) continue;
      if (s.startsWith('AE') && RegExp(r'^AE\d{21}$').hasMatch(s)) return true;
      if (_mod97(s)) return true;
    }
    return false;
  }

  static bool _mod97(String iban) {
    final moved = iban.substring(4) + iban.substring(0, 4);
    var rem = 0;
    for (final u in moved.codeUnits) {
      final v = u >= 65 ? u - 55 : u - 48;
      if (v < 0 || v > 35) return false;
      rem = (v > 9 ? rem * 100 + v : rem * 10 + v) % 97;
    }
    return rem == 1;
  }

  // ---- passwords, PINs -------------------------------------------------

  static final _passwordWord = RegExp(
    r'\b(password|passwords|passcode|passwd|pwd|pass\s*word|login\s*pass|secret\s*code|security\s*code)\b\s*(?:(is|are|=|:|-|–)\s*)?([^\s,;]+)?',
    caseSensitive: false,
  );
  static final _pinWord = RegExp(
    r'\b(pin|cvv2?|cvc|otp|atm\s*pin|mpin|t-?pin)\b\W{0,3}(?:(?:is|=)\s*)?(\d{3,8})\b',
    caseSensitive: false,
  );
  static const _harmless = {
    'in',
    'on',
    'at',
    'the',
    'my',
    'is',
    'are',
    'with',
    'for',
    'to',
    'of',
    'and',
    'a',
    'an',
    'saved',
    'stored',
    'kept',
    'manager',
    'safe',
    'vault',
    'app',
    'book',
    'notebook',
    'paper',
    'locker',
    'known',
    'only',
    'ask',
    'see',
    'written',
    'file',
    'folder',
    'reset',
    'protected',
    'locked',
    'hint',
    'not',
    'no',
    'same',
    'unknown',
    'n/a',
    'na',
    'none',
    'wife',
    'husband',
    'spouse',
    'he',
    'she',
    'they',
    'lastpass',
    '1password',
    'bitwarden',
    'keychain',
    'dashlane',
  };

  static GuardIssue? _passwordIssue(String t) {
    final pm = _pinWord.firstMatch(t);
    if (pm != null) {
      return const GuardIssue(
        GuardKind.pin,
        'This looks like a PIN or code. Never write those here: say who knows it or where it is kept.',
      );
    }
    for (final m in _passwordWord.allMatches(t)) {
      final sep = m.group(2);
      var token = (m.group(3) ?? '').replaceAll(
        RegExp(r'^["\x27`(]+|["\x27`).!?]+$'),
        '',
      );
      if (token.isEmpty) continue;
      if (_harmless.contains(token.toLowerCase())) continue;
      final hasDigit = RegExp(r'\d').hasMatch(token);
      final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(token);
      final mixed =
          RegExp(r'[a-z]').hasMatch(token) &&
          RegExp(r'[A-Z]').hasMatch(token) &&
          token.length >= 6;
      final separated = sep != null && sep != 'is' && sep != 'are';
      if (hasDigit || hasSymbol || mixed || (separated && token.length >= 4)) {
        return const GuardIssue(
          GuardKind.password,
          'This looks like a password. Never write passwords here: say which password manager or where it is written down.',
        );
      }
    }
    return null;
  }

  // ---- recovery phrases, ids -------------------------------------------

  static final _seedWord = RegExp(
    r'\b(seed\s*phrase|recovery\s*phrase|mnemonic|secret\s*phrase|recovery\s*words?)\b\s*(?:is|are|=|:|-)?\s*((?:[a-z]{3,8}[ ,]+){11,}[a-z]{3,8})',
    caseSensitive: false,
  );
  static bool _hasSeedPhrase(String t) => _seedWord.hasMatch(t);

  static final _emiratesId = RegExp(r'\b784[- ]?\d{4}[- ]?\d{7}[- ]?\d\b');
}
