import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../rules.dart';
import '../statements.dart';
import 'api_exception.dart';

/// Wire-level types for the Pulse backend (`/v1`). Amounts are integer minor
/// units (fils); conversion to the UI's double AED happens in the `toDomain`
/// mappers only.

double fromMinor(int minor) => minor / 100;
int toMinor(double amount) => (amount * 100).round();

DateTime _dt(Object? v) => DateTime.parse(v! as String).toLocal();
DateTime? _dtOpt(Object? v) => v == null ? null : _dt(v);
int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `{"items": [...], "next_cursor": "..."}`
class PageDto<T> {
  const PageDto(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;

  factory PageDto.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?>) item,
  ) => PageDto([
    for (final e in (json['items'] as List? ?? const []))
      item(Map<String, Object?>.from(e as Map)),
  ], json['next_cursor'] as String?);
}

class AccountDto {
  const AccountDto({
    required this.id,
    required this.type,
    required this.name,
    this.institution,
    this.last4,
    this.currency = 'AED',
    this.creditLimitMinor,
    this.dueDay,
    this.statementDay,
  });
  final String id;

  /// `bank` | `credit_card` | `wallet` | `cash`
  final String type;
  final String name;
  final String? institution;
  final String? last4;
  final String currency;
  final int? creditLimitMinor;
  final int? dueDay;
  final int? statementDay;

  bool get isCreditCard => type == 'credit_card';

  factory AccountDto.fromJson(Map<String, Object?> j) => AccountDto(
    id: j['id']! as String,
    type: j['type']! as String,
    name: j['name']! as String,
    institution: j['institution'] as String?,
    last4: j['last4'] as String?,
    currency: (j['currency'] as String?) ?? 'AED',
    creditLimitMinor: (j['credit_limit_minor'] as num?)?.toInt(),
    dueDay: (j['due_day'] as num?)?.toInt(),
    statementDay: (j['statement_day'] as num?)?.toInt(),
  );

  /// Human label, e.g. "Emirates NBD ••4821".
  String get label {
    final base = (institution?.isNotEmpty ?? false) ? institution! : name;
    return last4 == null ? base : '$base ••$last4';
  }
}

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    required this.kind,
    this.slug,
    this.userId,
    this.isHidden = false,
  });
  final String id;
  final String name;

  /// `expense` | `income` | `transfer`
  final String kind;

  /// Stable key of a default category (e.g. `groceries`); null for custom.
  final String? slug;

  /// Owner of a custom category; null for the shared defaults.
  final String? userId;
  final bool isHidden;

  factory CategoryDto.fromJson(Map<String, Object?> j) => CategoryDto(
    id: j['id']! as String,
    name: j['name']! as String,
    kind: (j['kind'] as String?) ?? 'expense',
    slug: j['slug'] as String?,
    userId: j['user_id'] as String?,
    isHidden: (j['is_hidden'] as bool?) ?? false,
  );

  bool get isCustom => userId != null && slug == null;

  CategoryKind get categoryKind => switch (kind) {
    'income' => CategoryKind.income,
    'transfer' => CategoryKind.transfer,
    _ => CategoryKind.expense,
  };

  /// Default by slug, a custom category by id, else best match by name.
  SpendCategory get spendCategory {
    final bySlug = SpendCategory.byId(slug);
    if (bySlug != null) return bySlug;
    if (isCustom) return SpendCategory.custom(id, name, kind: categoryKind);
    return spendCategoryFor(name, kind: kind);
  }
}

/// Maps a backend category name to the UI's default set.
SpendCategory spendCategoryFor(String name, {String kind = 'expense'}) {
  final n = name.toLowerCase();
  for (final c in SpendCategory.defaults) {
    if (c.label.toLowerCase() == n) return c;
  }
  bool has(List<String> keys) => keys.any(n.contains);
  if (kind == 'income' || has(['income', 'salary', 'refund'])) {
    return SpendCategory.salary;
  }
  if (has(['credit card', 'card payment'])) return SpendCategory.cardPayments;
  if (has(['grocer', 'supermarket'])) return SpendCategory.groceries;
  if (has(['din', 'restaurant', 'food', 'cafe', 'coffee', 'delivery'])) {
    return SpendCategory.dining;
  }
  if (has(['car loan', 'auto loan'])) return SpendCategory.carLoan;
  if (has(['mortgage', 'home loan'])) return SpendCategory.homeLoan;
  if (has(['transport', 'fuel', 'taxi', 'ride', 'parking', 'toll'])) {
    return SpendCategory.transport;
  }
  if (has(['telecom', 'internet', 'mobile', 'phone'])) {
    return SpendCategory.telecom;
  }
  if (has(['utilit', 'bill', 'electric', 'water'])) {
    return SpendCategory.utilities;
  }
  if (has(['subscription', 'fixed', 'insurance'])) {
    return SpendCategory.fixedExpenses;
  }
  if (has(['school', 'education', 'tuition'])) return SpendCategory.education;
  if (has(['shop', 'retail', 'fashion', 'electronics'])) {
    return SpendCategory.shopping;
  }
  if (has(['travel', 'flight', 'hotel', 'airline'])) {
    return SpendCategory.travel;
  }
  if (has(['health', 'pharma', 'medical', 'fitness', 'gym'])) {
    return SpendCategory.health;
  }
  if (has(['entertain', 'streaming', 'movie'])) {
    return SpendCategory.entertainment;
  }
  if (has(['family', 'remittance'])) return SpendCategory.family;
  if (has(['saving', 'invest'])) return SpendCategory.savings;
  if (has(['fee', 'charge', 'interest'])) return SpendCategory.fees;
  if (has(['rent', 'housing', 'home'])) return SpendCategory.rent;
  return SpendCategory.other;
}

class TransactionDto {
  const TransactionDto({
    required this.id,
    required this.accountId,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    required this.postedAt,
    required this.source,
    this.categoryId,
    this.merchantRaw,
    this.merchantNormalized,
    this.notes,
  });
  final String id;
  final String accountId;
  final String? categoryId;
  final int amountMinor;
  final String currency;

  /// `debit` | `credit`
  final String direction;
  final String? merchantRaw;
  final String? merchantNormalized;
  final String? notes;
  final DateTime postedAt;

  /// `statement` | `sms` | `notification` | `apple_shortcut` | `manual`
  final String source;

  factory TransactionDto.fromJson(Map<String, Object?> j) => TransactionDto(
    id: j['id']! as String,
    accountId: j['account_id']! as String,
    categoryId: j['category_id'] as String?,
    amountMinor: _int(j['amount_minor']),
    currency: (j['currency'] as String?) ?? 'AED',
    direction: j['direction']! as String,
    merchantRaw: j['merchant_raw'] as String?,
    merchantNormalized: j['merchant_normalized'] as String?,
    notes: j['notes'] as String?,
    postedAt: _dt(j['posted_at']),
    source: j['source']! as String,
  );

  Transaction toDomain({
    Map<String, AccountDto> accounts = const {},
    Map<String, CategoryDto> categories = const {},
  }) {
    final income = direction == 'credit';
    final cat = categories[categoryId];
    return Transaction(
      id: id,
      merchant: (merchantNormalized?.trim().isNotEmpty ?? false)
          ? merchantNormalized!.trim()
          : (merchantRaw?.trim().isNotEmpty ?? false)
          ? merchantRaw!.trim()
          : 'Unknown merchant',
      amount: fromMinor(amountMinor),
      category:
          cat?.spendCategory ??
          (income ? SpendCategory.income : SpendCategory.other),
      rawDescription: merchantRaw?.trim().isNotEmpty ?? false
          ? merchantRaw!.trim()
          : null,
      date: postedAt,
      source: txSourceFor(source),
      cardId: accountId,
      accountLabel: accounts[accountId]?.label ?? 'Account',
      isIncome: income,
    );
  }
}

TxSource txSourceFor(String wire) => switch (wire) {
  'statement' => TxSource.statement,
  'sms' => TxSource.sms,
  'notification' => TxSource.walletNotification,
  'apple_shortcut' => TxSource.applePayShortcut,
  _ => TxSource.manual,
};

class BudgetDto {
  const BudgetDto({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limitMinor,
    required this.spentMinor,
    required this.remainingMinor,
  });
  final String id;
  final String categoryId;

  /// First day of the budget month.
  final DateTime month;
  final int limitMinor;
  final int spentMinor;
  final int remainingMinor;

  factory BudgetDto.fromJson(Map<String, Object?> j) => BudgetDto(
    id: j['id']! as String,
    categoryId: j['category_id']! as String,
    // `month` is a date-only string; keep it timezone-free.
    month: DateTime.parse(j['month']! as String),
    limitMinor: _int(j['limit_minor']),
    spentMinor: _int(j['spent_minor']),
    remainingMinor: _int(j['remaining_minor']),
  );
}

class AssetDto {
  const AssetDto({
    required this.id,
    required this.kind,
    required this.name,
    this.manualValueMinor,
    this.costBasisMinor,
    this.unit,
  });
  final String id;

  /// `real_estate` | `fd` | `gold` | `stock` | `crypto` | `cash` | `vehicle` | `other`
  final String kind;
  final String name;
  final int? manualValueMinor;
  final int? costBasisMinor;
  final String? unit;

  factory AssetDto.fromJson(Map<String, Object?> j) => AssetDto(
    id: j['id']! as String,
    kind: j['kind']! as String,
    name: j['name']! as String,
    manualValueMinor: (j['manual_value_minor'] as num?)?.toInt(),
    costBasisMinor: (j['cost_basis_minor'] as num?)?.toInt(),
    unit: j['unit'] as String?,
  );

  Asset toDomain() => Asset(
    id: id,
    name: name,
    kind: switch (kind) {
      'cash' => AssetKind.cash,
      'fd' => AssetKind.fixedDeposit,
      'stock' || 'crypto' => AssetKind.stocks,
      'gold' => AssetKind.gold,
      'real_estate' => AssetKind.realEstate,
      _ => AssetKind.other,
    },
    // Fall back to cost basis when no manual valuation exists yet.
    value: fromMinor(manualValueMinor ?? costBasisMinor ?? 0),
    note: kind == 'crypto' ? 'Crypto' : (kind == 'vehicle' ? 'Vehicle' : ''),
  );
}

class LiabilityDto {
  const LiabilityDto({
    required this.id,
    required this.kind,
    required this.name,
    required this.outstandingMinor,
    this.lender,
    this.accountId,
    this.nextDueOn,
  });
  final String id;
  final String kind;
  final String name;
  final String? lender;
  final int outstandingMinor;
  final String? accountId;
  final DateTime? nextDueOn;

  factory LiabilityDto.fromJson(Map<String, Object?> j) => LiabilityDto(
    id: j['id']! as String,
    kind: j['kind']! as String,
    name: j['name']! as String,
    lender: j['lender'] as String?,
    outstandingMinor: _int(j['outstanding_minor']),
    accountId: j['account_id'] as String?,
    nextDueOn: _dtOpt(j['next_due_on']),
  );

  Asset toDomain() => Asset(
    id: id,
    name: name,
    kind: AssetKind.liability,
    value: fromMinor(outstandingMinor),
    note: lender ?? '',
  );
}

class NetWorthDto {
  const NetWorthDto({
    required this.currency,
    required this.assetsMinor,
    required this.liabilitiesMinor,
    required this.netWorthMinor,
    this.unconverted = const [],
  });
  final String currency;
  final int assetsMinor;
  final int liabilitiesMinor;
  final int netWorthMinor;
  final List<String> unconverted;

  factory NetWorthDto.fromJson(Map<String, Object?> j) => NetWorthDto(
    currency: (j['base_currency'] as String?) ?? 'AED',
    assetsMinor: _int(j['total_assets_minor']),
    liabilitiesMinor: _int(j['total_liabilities_minor']),
    netWorthMinor: _int(j['net_worth_minor']),
    unconverted: [
      for (final c in (j['unconverted_currencies'] as List? ?? const []))
        c as String,
    ],
  );

  /// The backend has no history endpoint yet, so the series is flat and the
  /// change is zero.
  NetWorth toDomain() {
    final total = fromMinor(netWorthMinor);
    return NetWorth(
      total: total,
      series: [total, total],
      changePct: 0,
      changeAed: 0,
    );
  }
}

class SplitMemberDto {
  const SplitMemberDto({
    required this.id,
    required this.displayName,
    this.userId,
  });
  final String id;
  final String? userId;
  final String displayName;

  factory SplitMemberDto.fromJson(Map<String, Object?> j) => SplitMemberDto(
    id: j['id']! as String,
    userId: j['user_id'] as String?,
    displayName: j['display_name']! as String,
  );
}

class SplitGroupDto {
  const SplitGroupDto({
    required this.id,
    required this.name,
    required this.currency,
    required this.members,
  });
  final String id;
  final String name;
  final String currency;
  final List<SplitMemberDto> members;

  factory SplitGroupDto.fromJson(Map<String, Object?> j) => SplitGroupDto(
    id: j['id']! as String,
    name: j['name']! as String,
    currency: (j['currency'] as String?) ?? 'AED',
    members: [
      for (final m in (j['members'] as List? ?? const []))
        SplitMemberDto.fromJson(Map<String, Object?>.from(m as Map)),
    ],
  );
}

class SplitShareDto {
  const SplitShareDto(this.memberId, this.shareMinor);
  final String memberId;
  final int shareMinor;
  factory SplitShareDto.fromJson(Map<String, Object?> j) =>
      SplitShareDto(j['member_id']! as String, _int(j['share_minor']));
}

class SplitExpenseDto {
  const SplitExpenseDto({
    required this.id,
    required this.description,
    required this.amountMinor,
    required this.paidByMemberId,
    required this.spentAt,
    required this.shares,
  });
  final String id;
  final String description;
  final int amountMinor;
  final String paidByMemberId;
  final DateTime spentAt;
  final List<SplitShareDto> shares;

  factory SplitExpenseDto.fromJson(Map<String, Object?> j) => SplitExpenseDto(
    id: j['id']! as String,
    description: j['description']! as String,
    amountMinor: _int(j['amount_minor']),
    paidByMemberId: j['paid_by_member_id']! as String,
    spentAt: _dt(j['spent_at']),
    shares: [
      for (final s in (j['shares'] as List? ?? const []))
        SplitShareDto.fromJson(Map<String, Object?>.from(s as Map)),
    ],
  );
}

const _memberPalette = [
  Color(0xFF60A5FA),
  Color(0xFFF472B6),
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFFA78BFA),
  Color(0xFFFB923C),
];

/// Builds the UI group. The signed-in user's member id is exposed as `'me'`
/// (the UI convention); everyone else keeps their backend member id.
SplitGroup splitGroupToDomain(
  SplitGroupDto g,
  List<SplitExpenseDto> expenses, {
  String? myUserId,
  List<SettlementDto> settlements = const [],
}) {
  String idOf(String memberId) {
    final m = g.members.where((m) => m.id == memberId);
    return (myUserId != null && m.isNotEmpty && m.first.userId == myUserId)
        ? 'me'
        : memberId;
  }

  return SplitGroup(
    id: g.id,
    name: g.name,
    emoji: '👥',
    members: [
      for (var i = 0; i < g.members.length; i++)
        Member(
          idOf(g.members[i].id),
          g.members[i].displayName,
          _memberPalette[i % _memberPalette.length],
        ),
    ],
    expenses: [
      for (final e in expenses)
        SplitExpense(
          id: e.id,
          title: e.description,
          paidBy: idOf(e.paidByMemberId),
          amount: fromMinor(e.amountMinor),
          participants: [for (final s in e.shares) idOf(s.memberId)],
          date: e.spentAt,
          shares: {
            for (final s in e.shares) idOf(s.memberId): fromMinor(s.shareMinor),
          },
        ),
    ],
    settlements: [for (final s in settlements) s.toDomain(idOf)],
  );
}

/// Note the client writes on an Aani payment the payee has not confirmed.
const aaniPendingNote = 'aani:awaiting_confirmation';

class SettlementDto {
  const SettlementDto({
    required this.id,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountMinor,
    required this.settledAt,
    this.note,
    this.status,
  });
  final String id;
  final String fromMemberId;
  final String toMemberId;
  final int amountMinor;
  final DateTime settledAt;
  final String? note;

  /// `pending` | `paid` | `confirmed` when the server tracks it.
  final String? status;

  factory SettlementDto.fromJson(Map<String, Object?> j) => SettlementDto(
    id: j['id']! as String,
    fromMemberId: j['from_member_id']! as String,
    toMemberId: j['to_member_id']! as String,
    amountMinor: _int(j['amount_minor']),
    settledAt: _dt(j['settled_at']),
    note: j['note'] as String?,
    status: j['status'] as String?,
  );

  bool get _awaiting =>
      status != null ? status != 'confirmed' : note == aaniPendingNote;

  SettlementRecord toDomain(String Function(String) idOf) => SettlementRecord(
    id: id,
    from: idOf(fromMemberId),
    to: idOf(toMemberId),
    amount: fromMinor(amountMinor),
    date: settledAt,
    status: _awaiting
        ? SettlementStatus.awaitingConfirmation
        : SettlementStatus.confirmed,
    method: status != null || (note ?? '').startsWith('aani')
        ? 'aani'
        : 'manual',
  );
}

class MerchantRuleDto {
  const MerchantRuleDto(this.id, this.merchantKey, this.categoryId);
  final String id;
  final String merchantKey;
  final String categoryId;
  factory MerchantRuleDto.fromJson(Map<String, Object?> j) => MerchantRuleDto(
    j['id']! as String,
    j['merchant_key']! as String,
    j['category_id']! as String,
  );

  AutomationRule toDomain(Map<String, CategoryDto> categories) =>
      AutomationRule(
        id: id,
        field: RuleField.merchant,
        op: RuleOperator.equals,
        value: merchantKey,
        action: RuleAction.setCategory,
        category: categories[categoryId]?.spendCategory ?? SpendCategory.other,
      );
}

DateTime? _dateOpt(Object? v) => v == null ? null : DateTime.parse(v as String);
double? _aedOpt(Object? v) => v == null ? null : fromMinor(_int(v));

class StatementDto {
  static Statement toDomain(
    Map<String, Object?> j, {
    Map<String, AccountDto> accounts = const {},
  }) {
    final inst = j['institution'] as String?;
    final acct = accounts[j['account_id']];
    return Statement(
      id: j['id']! as String,
      institution: inst,
      accountId: j['account_id'] as String?,
      accountLabel:
          acct?.label ??
          (inst != null
              ? institutionName(inst)
              : (j['original_filename'] as String?) ?? 'Statement'),
      periodStart: _dateOpt(j['period_start']),
      periodEnd: _dateOpt(j['period_end']),
      parse: ParseStatus.fromWire(j['parse_status'] as String?),
      recon: ReconStatus.fromWire(j['reconciliation_status'] as String?),
      diff: _aedOpt(j['diff_minor']),
      source: (j['source'] as String?) ?? 'upload',
      filename: j['original_filename'] as String?,
      parseError: j['parse_error'] as String?,
    );
  }

  static ReconLine _line(Map<String, Object?> j) => ReconLine(
    date: DateTime.parse(j['posted_on']! as String),
    description: (j['description'] as String?) ?? '',
    amount: fromMinor(_int(j['amount_minor'])),
    credit: j['direction'] == 'credit',
  );

  static Reconciliation reconciliation(Map<String, Object?> j) {
    final b = Map<String, Object?>.from(j['balances'] as Map? ?? const {});
    final counts = Map<String, Object?>.from(j['counts'] as Map? ?? const {});
    List<Map<String, Object?>> list(String k) => [
      for (final e in (j[k] as List? ?? const []))
        Map<String, Object?>.from(e as Map),
    ];
    return Reconciliation(
      statementId: j['statement_id']! as String,
      status: ReconStatus.fromWire(j['reconciliation_status'] as String?),
      opening: _aedOpt(b['opening_minor']),
      closing: _aedOpt(b['closing_minor']),
      computedClosing: _aedOpt(b['computed_closing_minor']),
      diff: _aedOpt(b['diff_minor']),
      linked: _int(counts['linked']),
      statementOnly: list('statement_only').map(_line).toList(),
      capturedOnly: [
        for (final t in list('captured_only'))
          ReconLine(
            date: _dt(t['posted_at']),
            description:
                (t['merchant_normalized'] as String?) ??
                (t['merchant_raw'] as String?) ??
                '',
            amount: fromMinor(_int(t['amount_minor'])),
            credit: t['direction'] == 'credit',
          ),
      ],
      warnings: [for (final w in (j['warnings'] as List? ?? const [])) '$w'],
    );
  }
}

// ---- Requests -------------------------------------------------------------

/// Body of `POST /v1/ingest/{sms,notification,apple-shortcut}`.
class IngestRequestDto {
  const IngestRequestDto({
    this.rawText,
    this.sender,
    this.institution,
    this.receivedAt,
    this.externalId,
    this.appName,
    this.title,
    this.fields,
  });

  final String? rawText;
  final String? sender;
  final String? institution;
  final DateTime? receivedAt;
  final String? externalId;
  final String? appName;
  final String? title;
  final IngestFieldsDto? fields;

  static String? _cap(String? s, int max) =>
      s == null ? null : (s.length <= max ? s : s.substring(0, max));

  /// Server limits: raw_text 5000, sender 80, institution 80, external_id 128,
  /// app_name 120, title 300. Truncated client-side so one long message can
  /// never produce a permanently failing 422.
  Map<String, Object?> toJson() => {
    if (rawText != null) 'raw_text': _cap(rawText, 5000),
    if (sender != null) 'sender': _cap(sender, 80),
    if (institution != null) 'institution': _cap(institution, 80),
    if (receivedAt != null)
      'received_at': receivedAt!.toUtc().toIso8601String(),
    if (externalId != null) 'external_id': _cap(externalId, 128),
    if (appName != null) 'app_name': _cap(appName, 120),
    if (title != null) 'title': _cap(title, 300),
    if (fields != null) 'fields': fields!.toJson(),
  };
}

class IngestFieldsDto {
  const IngestFieldsDto({
    required this.amountMinor,
    this.currency = 'AED',
    this.direction = 'debit',
    this.merchant,
    this.last4,
    this.postedAt,
  });
  final int amountMinor;
  final String currency;
  final String direction;
  final String? merchant;

  /// Exactly four digits or omitted (server pattern `^\d{4}$`).
  final String? last4;
  final DateTime? postedAt;

  Map<String, Object?> toJson() => {
    'amount_minor': amountMinor,
    'currency': currency,
    'direction': direction,
    if (merchant != null)
      'merchant': merchant!.length <= 500
          ? merchant
          : merchant!.substring(0, 500),
    if (last4 != null && RegExp(r'^\d{4}$').hasMatch(last4!)) 'last4': last4,
    if (postedAt != null) 'posted_at': postedAt!.toUtc().toIso8601String(),
  };
}

/// Response of the ingest endpoints (202 new, 200 duplicate).
class IngestResultDto {
  const IngestResultDto({
    required this.id,
    required this.duplicate,
    required this.parseStatus,
  });
  final String id;
  final bool duplicate;
  final String parseStatus;
  factory IngestResultDto.fromJson(Map<String, Object?> j) => IngestResultDto(
    id: j['id']! as String,
    duplicate: (j['duplicate'] as bool?) ?? false,
    parseStatus: (j['parse_status'] as String?) ?? 'pending',
  );
}

// ---- /v1/rules ---------------------------------------------------------------

String _escapeRegex(String s) =>
    s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');

/// The literal text of a pattern made only of plain and escaped characters,
/// or null when it uses real regex syntax the editor cannot show.
String? _unescapeRegex(String s) {
  final literal = RegExp(r'^(?:\\.|[^.*+?^${}()|[\]\\])*$');
  if (!literal.hasMatch(s)) return null;
  return s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
}

/// Maps a backend rule to the one-condition shape the editor shows. Returns
/// null for rules the app cannot represent (no supported action).
AutomationRule? ruleFromJson(
  Map<String, Object?> j, {
  Map<String, CategoryDto> categories = const {},
  Map<String, AccountDto> accounts = const {},
}) {
  final conditions = [
    for (final c in (j['conditions'] as List? ?? const []))
      Map<String, Object?>.from(c as Map),
  ];
  if (conditions.isEmpty) return null;
  final c = conditions.first;
  RuleField? field;
  RuleOperator? op;
  String? value;
  switch (c['field']) {
    case 'merchant' || 'description':
      field = c['field'] == 'merchant'
          ? RuleField.merchant
          : RuleField.description;
      final raw = (c['value'] as String?) ?? '';
      switch (c['op']) {
        case 'contains':
          op = RuleOperator.contains;
          value = raw;
        case 'equals':
          op = RuleOperator.equals;
          value = raw;
        case 'regex':
          if (!raw.startsWith('^')) return null;
          final plain = _unescapeRegex(raw.substring(1));
          if (plain == null) return null;
          op = RuleOperator.startsWith;
          value = plain;
      }
    case 'amount':
      field = RuleField.amount;
      final v = _int(c['value_minor']);
      switch (c['op']) {
        case 'equals':
          op = RuleOperator.equals;
          value = fromMinor(v).toStringAsFixed(2);
        case 'gte':
          op = RuleOperator.greaterThan;
          value = fromMinor(v - 1).toStringAsFixed(2);
        case 'lte':
          op = RuleOperator.lessThan;
          value = fromMinor(v + 1).toStringAsFixed(2);
      }
    case 'account':
      field = RuleField.account;
      op = RuleOperator.equals;
      value = accounts[c['account_id']]?.label ?? 'Account';
  }
  if (field == null || op == null || value == null) return null;

  final categoryId = j['category_id'] as String?;
  final rename = j['rename_merchant'] as String?;
  final exclude =
      (j['exclude_from_budget'] as bool? ?? false) ||
      (j['mark_transfer'] as bool? ?? false);
  final RuleAction action;
  if (categoryId != null) {
    action = RuleAction.setCategory;
  } else if (rename != null) {
    action = RuleAction.rename;
  } else if (exclude) {
    action = RuleAction.exclude;
  } else {
    return null;
  }
  return AutomationRule(
    id: j['id']! as String,
    field: field,
    op: op,
    value: value,
    action: action,
    category: categoryId == null
        ? null
        : categories[categoryId]?.spendCategory ?? SpendCategory.other,
    renameTo: rename,
    enabled: j['is_active'] as bool? ?? true,
  );
}

/// The `/v1/rules` body for [r]. Text matching on the server is
/// case-insensitive against lower-cased text, so "starts with" becomes an
/// anchored, escaped, lower-case regex.
Map<String, Object?> ruleToJson(
  AutomationRule r, {
  String? categoryId,
  Iterable<AccountDto> accounts = const [],
}) {
  final value = r.value.trim();
  final Map<String, Object?> condition;
  switch (r.field) {
    case RuleField.merchant || RuleField.description:
      condition = {
        'field': r.field.name,
        if (r.op == RuleOperator.startsWith) ...{
          'op': 'regex',
          'value': '^${_escapeRegex(value.toLowerCase())}',
        } else ...{
          'op': r.op == RuleOperator.equals ? 'equals' : 'contains',
          'value': value,
        },
      };
    case RuleField.amount:
      final minor = toMinor(double.parse(value));
      condition = {
        'field': 'amount',
        ...switch (r.op) {
          RuleOperator.greaterThan => {'op': 'gte', 'value_minor': minor + 1},
          RuleOperator.lessThan => {
            'op': 'lte',
            'value_minor': minor > 0 ? minor - 1 : 0,
          },
          _ => {'op': 'equals', 'value_minor': minor},
        },
      };
    case RuleField.account:
      final needle = normaliseText(value);
      final match = accounts
          .where((a) => normaliseText(a.label).contains(needle))
          .firstOrNull;
      if (match == null) {
        throw ApiException(
          code: 'unknown_account',
          message: 'No account matches "$value".',
        );
      }
      condition = {'field': 'account', 'account_id': match.id};
  }
  if (r.action == RuleAction.setCategory && categoryId == null) {
    throw const ApiException(
      code: 'unknown_category',
      message: 'That category is not available on the server yet.',
    );
  }
  return {
    'name': r.condition,
    'is_active': r.enabled,
    'conditions': [condition],
    if (r.action == RuleAction.setCategory) 'category_id': categoryId,
    if (r.action == RuleAction.rename) 'rename_merchant': r.renameTo!.trim(),
    if (r.action == RuleAction.exclude) 'exclude_from_budget': true,
  };
}
