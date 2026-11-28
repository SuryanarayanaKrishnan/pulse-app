/// Strips anything that could identify a person or their money from text
/// that is about to go into a bug report.
///
/// It is deliberately blunt: a log line that loses a harmless digit is fine,
/// one that keeps an amount or a name is not. Rules run in order:
///
/// 1. quoted text (error messages echo the input that broke them);
/// 2. `field: value` pairs for money, merchant and contact fields;
/// 3. emails, links, IBAN-like codes, phone numbers, currency amounts;
/// 4. every remaining digit. Only the line and column of a Dart stack frame
///    (`file.dart:12:5`) and its `#3` frame number survive, so traces stay
///    useful.
///
/// Running it twice gives the same result.
abstract final class Redactor {
  static final _quoted = RegExp(r'''"[^"\n]*"|'[^'\n]*'|`[^`\n]*`''');

  static const _fieldNames =
      'merchant|merchants|payee|payer|counterparty|vendor|store|shop|name|'
      'first_?name|last_?name|full_?name|nickname|contact|contacts|note|notes|'
      'memo|description|desc|title|label|narration|reference|ref|message|body|'
      'text|sms|address|email|e-?mail|phone|mobile|msisdn|iban|account|'
      'account_?number|acct|card|pan|last4|amount|amt|balance|total|price|'
      'value|spent|limit|income|salary|token|password|pass|passphrase|secret|'
      'key|code|otp|pin|member|owner|household';
  static final _field = RegExp(
    '(?<![A-Za-z_])($_fieldNames)(["\']?\\s*[:=]\\s*)(?!\\s|\\[redacted\\])[^,;\\n}\\]]+',
    caseSensitive: false,
  );

  static final _email = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+',
  );
  static final _url = RegExp(
    r'(?:https?|ftp|pulse)://\S+',
    caseSensitive: false,
  );
  static final _iban = RegExp(
    r'\b[A-Za-z]{2}\p{Nd}{2}(?:[ \-]?[A-Za-z0-9]){10,30}\b',
    unicode: true,
  );
  static final _phone = RegExp(
    r'\+?\p{Nd}[\p{Nd} \-().]{5,}\p{Nd}',
    unicode: true,
  );
  static const _cur =
      r'(?:AED|USD|EUR|GBP|INR|SAR|QAR|KWD|BHD|OMR|PKR|Dhs?|Dirhams?|Rs\.?|'
      r'\$|€|£|₹|د\.إ)';
  static const _num = r'\p{Nd}[\p{Nd},.  ]*';
  static final _amount = RegExp(
    '(?:$_cur\\s?-?$_num)|(?:-?$_num\\s?$_cur(?![A-Za-z]))',
    caseSensitive: false,
    unicode: true,
  );
  // Digits, except a stack frame's `.dart:line:col` and a leading `#frame`.
  static final _digits = RegExp(
    r'(\.dart:\p{Nd}+(?::\p{Nd}+)?)|(^#\p{Nd}+)|(\p{Nd}+)',
    multiLine: true,
    unicode: true,
  );

  static String redact(String input) {
    var s = input;
    s = s.replaceAll(_quoted, '[text]');
    s = s.replaceAllMapped(_field, (m) => '${m[1]}${m[2]}[redacted]');
    s = s.replaceAll(_email, '[email]');
    s = s.replaceAll(_url, '[link]');
    s = s.replaceAll(_iban, '[iban]');
    s = s.replaceAllMapped(
      _phone,
      (m) => _digitCount(m[0]!) >= 7 ? '[phone]' : m[0]!,
    );
    s = s.replaceAll(_amount, '[amount]');
    s = s.replaceAllMapped(_digits, (m) => m[3] != null ? '#' : m[0]!);
    return s;
  }

  /// Also removes literal [terms] (names or merchants the caller knows are
  /// on screen), case-insensitively, before the general rules run.
  static String redactWith(String input, Iterable<String> terms) {
    var s = input;
    for (final t in terms) {
      final term = t.trim();
      if (term.length < 2) continue;
      s = s.replaceAll(
        RegExp(RegExp.escape(term), caseSensitive: false),
        '[text]',
      );
    }
    return redact(s);
  }

  static int _digitCount(String s) =>
      RegExp(r'\p{Nd}', unicode: true).allMatches(s).length;
}
