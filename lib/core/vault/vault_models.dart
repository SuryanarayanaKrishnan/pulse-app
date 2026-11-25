/// Plain data for the family vault. A vault entry says *where to look*, never
/// the secret itself: see `input_guard.dart`.
library;

import 'dart:convert';

enum VaultType {
  bank('bank', 'Bank account', 'Where is the statement, the branch, the app?'),
  card('card', 'Credit card', 'Which bank, and where the paperwork is kept'),
  loan('loan', 'Loan or mortgage', 'Lender, and where the agreement is kept'),
  insurance(
    'insurance',
    'Insurance',
    'Policy folder, broker or agent, who to call',
  ),
  investment(
    'investment',
    'Investment or gold',
    'Platform, broker or where the certificates are',
  ),
  property('property', 'Property', 'Title deed location, Ejari, agent'),
  crypto(
    'crypto',
    'Crypto',
    'Which exchange or wallet app, and where the recovery paper is kept (never the words)',
  ),
  subscription('subscription', 'Subscription', 'What to cancel and where'),
  digital(
    'digital',
    'Digital account',
    'Email, cloud, social: which one, never the password',
  ),
  documents(
    'documents',
    'Documents location',
    'The folder, safe or locker, and who has the key',
  ),
  identity(
    'identity',
    'Will, ID or passport',
    'Where the originals and copies are',
  );

  const VaultType(this.key, this.label, this.hint);
  final String key;
  final String label;
  final String hint;

  static VaultType fromKey(String? k) => VaultType.values.firstWhere(
    (t) => t.key == k,
    orElse: () => VaultType.documents,
  );
}

/// How many of each a typical UAE household has. 12 in all, so the score
/// reads as "7 of ~12". Crypto only counts for people who have it.
const typicalPerType = <VaultType, int>{
  VaultType.bank: 2,
  VaultType.card: 1,
  VaultType.loan: 1,
  VaultType.insurance: 2,
  VaultType.investment: 1,
  VaultType.property: 1,
  VaultType.crypto: 0,
  VaultType.subscription: 1,
  VaultType.digital: 1,
  VaultType.documents: 1,
  VaultType.identity: 1,
};

class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.type,
    required this.institution,
    this.title = '',
    this.whereToFind = '',
    this.nomineeName = '',
    this.contactPerson = '',
    this.estimatedValueMinor,
    this.photoPaths = const [],
    this.sourceRef,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final VaultType type;

  /// Bank, insurer, exchange, landlord... Required.
  final String institution;

  /// What it is, for example "Savings account" or "Term life".
  final String title;

  /// Free text: where the paperwork, the app or the branch is. Never a secret.
  final String whereToFind;

  /// The nominee named on the account or policy itself (not a vault person).
  final String nomineeName;
  final String contactPerson;

  /// Optional, in AED fils.
  final int? estimatedValueMinor;

  /// Photos of documents, in the app-private attachments folder.
  final List<String> photoPaths;

  /// `account:<id>`, `card:<id>`... set when the entry came from a suggestion,
  /// so the same thing is not suggested twice.
  final String? sourceRef;
  final DateTime createdAt, updatedAt;

  String get displayName =>
      title.trim().isEmpty ? institution : '$institution, ${title.trim()}';

  VaultEntry copyWith({
    VaultType? type,
    String? institution,
    String? title,
    String? whereToFind,
    String? nomineeName,
    String? contactPerson,
    int? estimatedValueMinor,
    bool clearValue = false,
    List<String>? photoPaths,
    DateTime? updatedAt,
  }) => VaultEntry(
    id: id,
    type: type ?? this.type,
    institution: institution ?? this.institution,
    title: title ?? this.title,
    whereToFind: whereToFind ?? this.whereToFind,
    nomineeName: nomineeName ?? this.nomineeName,
    contactPerson: contactPerson ?? this.contactPerson,
    estimatedValueMinor: clearValue
        ? null
        : (estimatedValueMinor ?? this.estimatedValueMinor),
    photoPaths: photoPaths ?? this.photoPaths,
    sourceRef: sourceRef,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// What goes into a sealed export. Photo paths never do; the papers
  /// themselves travel separately, inside the ciphertext.
  Map<String, Object?> toExportJson() => {
    'id': id,
    'type': type.key,
    'institution': institution,
    'title': title,
    'where': whereToFind,
    'nominee': nomineeName,
    'contact': contactPerson,
    'valueMinor': estimatedValueMinor,
    'photos': photoPaths.length,
  };

  static VaultEntry fromExportJson(Map<String, dynamic> j) => VaultEntry(
    id: j['id'] as String,
    type: VaultType.fromKey(j['type'] as String?),
    institution: j['institution'] as String? ?? '',
    title: j['title'] as String? ?? '',
    whereToFind: j['where'] as String? ?? '',
    nomineeName: j['nominee'] as String? ?? '',
    contactPerson: j['contact'] as String? ?? '',
    estimatedValueMinor: j['valueMinor'] as int?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// A trusted person: someone who may be handed an emergency export.
class Nominee {
  const Nominee({
    required this.id,
    required this.name,
    this.relationship = '',
    this.contact = '',
    this.entryIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String relationship;

  /// Phone or email, free text.
  final String contact;

  /// What they may see: null means everything, otherwise these entry ids.
  final Set<String>? entryIds;
  final DateTime createdAt;

  bool get seesAll => entryIds == null;

  bool canSee(VaultEntry e) => entryIds == null || entryIds!.contains(e.id);

  Nominee copyWith({
    String? name,
    String? relationship,
    String? contact,
    Set<String>? entryIds,
    bool seeAll = false,
  }) => Nominee(
    id: id,
    name: name ?? this.name,
    relationship: relationship ?? this.relationship,
    contact: contact ?? this.contact,
    entryIds: seeAll ? null : (entryIds ?? this.entryIds),
    createdAt: createdAt,
  );

  /// Stored form: `*` for everything, else a JSON list of ids.
  String get entryIdsStored =>
      entryIds == null ? '*' : jsonEncode(entryIds!.toList()..sort());

  static Set<String>? parseEntryIds(String? s) {
    if (s == null || s == '*' || s.isEmpty) return null;
    try {
      return {for (final v in jsonDecode(s) as List) v as String};
    } catch (_) {
      return <String>{};
    }
  }
}

/// The entries a nominee may see, in a stable order.
List<VaultEntry> visibleTo(Nominee? nominee, List<VaultEntry> entries) {
  final list = [
    for (final e in entries)
      if (nominee == null || nominee.canSee(e)) e,
  ];
  list.sort((a, b) {
    final t = a.type.index.compareTo(b.type.index);
    return t != 0
        ? t
        : a.institution.toLowerCase().compareTo(b.institution.toLowerCase());
  });
  return list;
}
