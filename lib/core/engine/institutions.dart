/// Registry of supported UAE institutions: names, aliases and SMS sender IDs.
///
/// Port of `app/services/institutions.py` (pulse-api). Pure Dart.
library;

final _nonAlnum = RegExp(r'[^a-z0-9]+');

/// Lower-cases and strips everything but letters and digits.
String normName(String value) => value.toLowerCase().replaceAll(_nonAlnum, '');

class Institution {
  const Institution({
    required this.key,
    required this.name,
    this.aliases = const [],
    this.smsSenders = const [],
    this.textMarkers = const [],
  });

  /// Canonical key stored on transactions and used as the parser id.
  final String key;
  final String name;
  final List<String> aliases;
  final List<String> smsSenders;
  final List<String> textMarkers;

  List<String> get allNames => [key, name, ...aliases];
}

class InstitutionRegistry {
  InstitutionRegistry(Iterable<Institution> items)
    : _items = {for (final i in items) i.key: i};

  final Map<String, Institution> _items;

  Iterable<Institution> get all => _items.values;
  List<String> get keys => _items.keys.toList();
  Institution? get(String key) => _items[key];

  /// Maps free text ("Emirates NBD", "enbd", "ENBD Bank") to its key.
  String? resolveKey(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final n = normName(name);
    for (final inst in _items.values) {
      if (inst.allNames.map(normName).contains(n)) return inst.key;
    }
    // "Emirates NBD Credit Card" style: an alias contained in the string
    // (longest alias wins).
    var bestLen = 0;
    String? best;
    for (final inst in _items.values) {
      for (final alias in inst.allNames) {
        final a = normName(alias);
        if (a.length >= 4 && n.contains(a) && a.length > bestLen) {
          bestLen = a.length;
          best = inst.key;
        }
      }
    }
    return best;
  }

  String? fromSender(String? sender) {
    if (sender == null || sender.isEmpty) return null;
    final n = normName(sender);
    for (final inst in _items.values) {
      if (inst.smsSenders.map(normName).contains(n)) return inst.key;
    }
    return null;
  }
}

/// The twelve institutions the app understands (same order as the backend).
final institutions = InstitutionRegistry(const [
  Institution(
    key: 'enbd',
    name: 'Emirates NBD',
    aliases: ['ENBD', 'Emirates National Bank of Dubai'],
    smsSenders: ['ENBD', 'EmiratesNBD', 'Emirates NBD'],
    textMarkers: ['EMIRATES NBD', 'EMIRATESNBD.COM', 'ENBD'],
  ),
  Institution(
    key: 'adcb',
    name: 'ADCB',
    aliases: ['Abu Dhabi Commercial Bank'],
    smsSenders: ['ADCB'],
    textMarkers: ['ABU DHABI COMMERCIAL BANK', 'ADCB'],
  ),
  Institution(
    key: 'fab',
    name: 'First Abu Dhabi Bank',
    aliases: ['FAB', 'Bank FAB', 'BankFAB'],
    smsSenders: ['FAB', 'BankFAB'],
    textMarkers: ['FIRST ABU DHABI BANK', 'BANKFAB.COM', 'BANK FAB'],
  ),
  Institution(
    key: 'mashreq',
    name: 'Mashreq',
    aliases: ['Mashreq Bank', 'MashreqBank'],
    smsSenders: ['MASHREQ', 'Mashreq'],
    textMarkers: ['MASHREQ', 'MASHREQBANK'],
  ),
  Institution(
    key: 'rakbank',
    name: 'RAKBANK',
    aliases: ['RAK Bank', 'National Bank of Ras Al Khaimah'],
    smsSenders: ['RAKBANK', 'RAK BANK'],
    textMarkers: ['RAKBANK', 'RAK BANK'],
  ),
  Institution(
    key: 'dib',
    name: 'Dubai Islamic Bank',
    aliases: ['DIB'],
    smsSenders: ['DIB', 'DubaiIslamic', 'DubaiIslamicBank'],
    textMarkers: ['DUBAI ISLAMIC BANK', 'DIB'],
  ),
  Institution(
    key: 'adib',
    name: 'Abu Dhabi Islamic Bank',
    aliases: ['ADIB'],
    smsSenders: ['ADIB'],
    textMarkers: ['ABU DHABI ISLAMIC BANK', 'ADIB'],
  ),
  Institution(
    key: 'hsbc',
    name: 'HSBC UAE',
    aliases: ['HSBC', 'HSBC Bank Middle East'],
    smsSenders: ['HSBC', 'HSBCUAE'],
    textMarkers: ['HSBC'],
  ),
  Institution(
    key: 'citi',
    name: 'Citi UAE',
    aliases: ['Citi', 'Citibank', 'Citibank UAE'],
    smsSenders: ['Citibank', 'CITI', 'Citi'],
    textMarkers: ['CITIBANK', 'CITI'],
  ),
  Institution(
    key: 'cbd',
    name: 'Commercial Bank of Dubai',
    aliases: ['CBD'],
    smsSenders: ['CBD', 'CBDUAE'],
    textMarkers: ['COMMERCIAL BANK OF DUBAI', 'CBD'],
  ),
  Institution(
    key: 'eib',
    name: 'Emirates Islamic',
    aliases: ['EIB', 'Emirates Islamic Bank'],
    smsSenders: ['EmiratesIslamic', 'EIB', 'E-Islamic'],
    textMarkers: ['EMIRATES ISLAMIC'],
  ),
  Institution(
    key: 'liv',
    name: 'Liv',
    aliases: ['Liv.', 'Liv by Emirates NBD'],
    smsSenders: ['LIV', 'Liv.'],
    textMarkers: ['LIV.ME', 'LIV BANKING', 'LIV'],
  ),
]);
