/// The gate every merchant key must pass before it is stored for, previewed
/// for, or sent in a contribution. Deliberately conservative: when in doubt
/// the key is rejected (a missed contribution costs nothing; a leaked name
/// or number cannot be taken back).
///
/// A key passes if it is a known merchant (exactly an entry of the global
/// map) and has none of the hard problems, or if it looks like a business:
/// plain letters, at least one business word, no person-like words.
library;

import 'global_merchant_map.dart';

/// Why a key was refused (for tests and the debug log only; never sent).
enum KeyRejection {
  empty,
  notNormalised,
  tooLong,
  tooManyWords,
  email,
  url,
  phone,
  digits,
  transferText,
  badCharacters,
  personLike,
  notBusiness,
}

class KeyDecision {
  const KeyDecision.ok() : rejection = null;
  const KeyDecision.no(KeyRejection this.rejection);
  final KeyRejection? rejection;
  bool get ok => rejection == null;
}

class MerchantKeyFilter {
  const MerchantKeyFilter(this.map);

  final GlobalMerchantMap map;

  static const maxLength = 40;
  static const maxWords = 5;
  static const maxDigitRun = 3;
  static const maxTotalDigits = 4;

  static final _ws = RegExp(r'\s+');
  static final _digitRun = RegExp(r'\d+');
  static final _plainChars = RegExp(r"^[a-z0-9&'.\- ]+$");

  /// Words that show up in descriptors of money moving between people or
  /// accounts rather than at a business.
  static const _transferWords = {
    'transfer', 'iban', 'payroll', 'salary', 'atm', 'cheque', 'chq', 'wps',
    'p2p', 'upi', 'refund', 'reversal', 'otp', 'swift', 'ref', //
  };

  /// Titles and name particles. Any of these means a person.
  static const _personWords = {
    'mr', 'mrs', 'ms', 'miss', 'sheikh', 'shaikh', 'sheikha', 'eng', 'capt',
    'bin', 'bint', 'ibn', 'abu', 'umm', 'sayed', 'syed', 'haji', 'hajji', //
  };

  /// Common first names in the UAE's main communities. Not complete; it is a
  /// second line of defence after the "must look like a business" rule.
  static const _firstNames = {
    'mohammed', 'mohamed', 'muhammad', 'mohammad', 'ahmed', 'ahmad', 'ali',
    'omar', 'umar', 'khalid', 'khaled', 'hassan', 'hussain', 'hussein',
    'ibrahim', 'yusuf', 'yousef', 'youssef', 'abdullah', 'abdulla', 'abdul',
    'rashid', 'saeed', 'saif', 'sultan', 'zayed', 'hamad', 'hamdan', 'majid',
    'nasser', 'faisal', 'fahad', 'tariq', 'tarek', 'karim', 'kareem',
    'mustafa', 'mahmoud', 'ismail', 'bilal', 'imran', 'usman', 'hamza',
    'fatima', 'fatma', 'aisha', 'ayesha', 'mariam', 'maryam', 'khadija',
    'noor', 'noura', 'mona', 'layla', 'leila', 'sara', 'sarah', 'amina',
    'hana', 'huda', 'reem', 'salma', 'zainab', 'lina', 'dina', 'rania',
    'raj', 'rahul', 'amit', 'sanjay', 'vijay', 'ravi', 'kumar', 'singh',
    'sharma', 'patel', 'khan', 'shah', 'priya', 'anita', 'sunita', 'deepak',
    'suresh', 'ramesh', 'rajesh', 'arun', 'anil', 'mohan', 'krishna',
    'john', 'david', 'michael', 'james', 'robert', 'william', 'daniel',
    'thomas', 'peter', 'paul', 'mark', 'chris', 'mary', 'jennifer', 'emma',
    'olivia', 'sophia', 'anna', 'maria', 'elena', 'natalia', 'olga',
    'juan', 'jose', 'carlos', 'ahmet', 'mehmet', 'wei', 'li', 'chen',
    'joseph', 'george', 'jacob', 'rizwan', 'nadeem', 'asif',
    'shahid', 'waseem', 'junaid', 'zahid', 'sajid', 'naveed', 'adnan', //
  };

  /// Words that make a free-form name read as a business.
  static const _businessWords = {
    'llc', 'l.l.c', 'fze', 'fzco', 'fzc', 'ltd', 'limited', 'inc', 'co',
    'company', 'trading', 'est', 'establishment', 'restaurant', 'cafe',
    'coffee', 'bakery', 'pharmacy', 'supermarket', 'hypermarket', 'market',
    'markets', 'mart', 'grocery', 'groceries', 'store', 'stores', 'shop',
    'mall', 'hotel', 'resort', 'clinic', 'hospital', 'medical', 'dental',
    'salon', 'spa', 'gym', 'fitness', 'laundry', 'cleaners', 'garage',
    'auto', 'motors', 'petrol', 'fuel', 'station', 'cinema', 'cinemas',
    'airlines', 'airways', 'travel', 'tours', 'school', 'academy',
    'university', 'college', 'electronics', 'furniture', 'jewellery',
    'jewelry', 'optics', 'stationery', 'traders', 'general', 'services',
    'kitchen', 'grill', 'pizza', 'burger', 'shawarma', 'biryani', 'juice',
    'sweets', 'butchery', 'fresh', 'foods', 'food', 'catering', 'tailoring',
    'flowers', 'florist', 'vet', 'gold', 'bookstore', 'boutique', 'bistro',
    'diner', 'eatery', 'lounge', 'carwash', 'tyres', 'hardware', //
  };

  /// Decides whether [key] may be stored, previewed or sent.
  KeyDecision check(String? key) {
    if (key == null) return const KeyDecision.no(KeyRejection.empty);
    if (key.trim().isEmpty) return const KeyDecision.no(KeyRejection.empty);
    // Already lower case, trimmed and single-spaced, as the app's merchant
    // key produces. Anything else was not built by the normaliser.
    if (key != key.trim().toLowerCase().replaceAll(_ws, ' ')) {
      return const KeyDecision.no(KeyRejection.notNormalised);
    }
    if (key.length > maxLength)
      return const KeyDecision.no(KeyRejection.tooLong);
    final words = key.split(' ');
    if (words.length > maxWords)
      return const KeyDecision.no(KeyRejection.tooManyWords);

    // ---- Hard rejections: apply even to known merchants. ----
    if (key.contains('@')) return const KeyDecision.no(KeyRejection.email);
    if (key.contains('http') || key.contains('www.') || key.contains('://')) {
      return const KeyDecision.no(KeyRejection.url);
    }
    if (key.contains('+')) return const KeyDecision.no(KeyRejection.phone);
    var total = 0;
    for (final m in _digitRun.allMatches(key)) {
      final n = m.group(0)!.length;
      total += n;
      if (n > maxDigitRun) return const KeyDecision.no(KeyRejection.digits);
    }
    if (total > maxTotalDigits) return const KeyDecision.no(KeyRejection.phone);
    for (final w in words) {
      if (_transferWords.contains(w)) {
        return const KeyDecision.no(KeyRejection.transferText);
      }
    }
    // Control characters, brackets, slashes, quotes of any other kind.
    if (RegExp(r'[\u0000-\u001f\u007f-\u009f<>{}\[\]\\/|;:,!?=_~^`"]')
        .hasMatch(key)) {
      return const KeyDecision.no(KeyRejection.badCharacters);
    }

    // ---- A known merchant is accepted from here. ----
    if (map.containsKey(key)) return const KeyDecision.ok();

    // ---- Otherwise it must look like a business. ----
    if (!_plainChars.hasMatch(key)) {
      return const KeyDecision.no(KeyRejection.badCharacters);
    }
    final bare = [
      for (final w in words) w.replaceAll(RegExp(r"^[.\-']+|[.\-']+$"), ''),
    ];
    for (final w in bare) {
      if (_personWords.contains(w) || _firstNames.contains(w)) {
        return const KeyDecision.no(KeyRejection.personLike);
      }
    }
    if (!bare.any(_businessWords.contains)) {
      return const KeyDecision.no(KeyRejection.notBusiness);
    }
    return const KeyDecision.ok();
  }

  bool accepts(String? key) => check(key).ok;
}
