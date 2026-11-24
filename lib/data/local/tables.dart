import 'package:drift/drift.dart';

/// Local schema. It mirrors the essentials of the backend's models
/// (pulse-api `app/models`) so a future encrypted backup/sync can map rows
/// one to one. Ids are text (UUID v4, or the slug for the default
/// categories). Money is integer minor units (fils); timestamps are UTC.

@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();

  /// bank | credit_card | wallet | cash
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get institution => text().nullable()();
  TextColumn get last4 => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  IntColumn get creditLimitMinor => integer().nullable()();
  IntColumn get statementDay => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();

  /// A balance the user (or a statement) vouches for; the live balance is
  /// this plus the transactions after it. For cards it is the amount owed.
  IntColumn get balanceAnchorMinor => integer().nullable()();
  DateTimeColumn get balanceAnchorAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local cache of the card catalog (bundled or downloaded).
@DataClassName('CatalogCardRow')
class CatalogCards extends Table {
  TextColumn get id => text()();
  TextColumn get issuer => text()();
  TextColumn get name => text()();
  TextColumn get network => text().nullable()();
  IntColumn get annualFeeMinor => integer().withDefault(const Constant(0))();
  IntColumn get minSalaryMinor => integer().nullable()();

  /// JSON, see `core/engine/rewards.dart`.
  TextColumn get rewardStructure => text().withDefault(const Constant('{}'))();
  TextColumn get perks => text().withDefault(const Constant('{}'))();

  /// Null = unverified.
  TextColumn get verifiedOn => text().nullable()();
  TextColumn get source => text().nullable()();
  IntColumn get catalogVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UserCardRow')
class UserCards extends Table {
  TextColumn get id => text()();
  TextColumn get catalogCardId => text().references(CatalogCards, #id)();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get nickname => text().nullable()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  /// The slug for default categories, `c_<random>` for custom ones.
  TextColumn get id => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get name => text()();

  /// expense | income | transfer
  TextColumn get kind => text().withDefault(const Constant('expense'))();
  BoolColumn get isFixed => boolean().withDefault(const Constant(false))();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'ix_transactions_posted_at', columns: {#postedAt})
@TableIndex(name: 'ix_transactions_account_posted', columns: {#accountId, #postedAt})
@TableIndex(name: 'ix_transactions_statement', columns: {#statementId})
@DataClassName('TxRow')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get statementId => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Always positive; [direction] carries the sign.
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();

  /// debit | credit
  TextColumn get direction => text()();
  TextColumn get merchantRaw => text().nullable()();
  TextColumn get merchantNormalized => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get postedAt => dateTime()();

  /// statement | sms | notification | apple_shortcut | google_wallet |
  /// samsung_wallet | manual
  TextColumn get source => text()();

  /// Dedupe key of the message this came from; unique when present.
  TextColumn get externalHash => text().nullable().unique()();
  BoolColumn get excludeFromBudget => boolean().withDefault(const Constant(false))();

  /// JSON list of free-form labels.
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// JSON list of every channel that saw this purchase: one purchase, one row.
  TextColumn get sources => text().withDefault(const Constant('[]'))();

  /// A statement line confirmed it: amount/date are the bank's, final.
  BoolColumn get statementLocked => boolean().withDefault(const Constant(false))();
  TextColumn get appliedRuleId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BudgetRow')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();

  /// First day of the month, `YYYY-MM-01`.
  TextColumn get month => text()();
  IntColumn get limitMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, month},
  ];
}

/// A user's classification rule ("automation"): AND-ed conditions -> actions.
@DataClassName('RuleRow')
class MerchantRules extends Table {
  TextColumn get id => text()();

  /// Upsert key of the learnt "always categorise X as Y" shortcut.
  TextColumn get merchantKey => text().nullable().unique()();
  TextColumn get name => text().nullable()();

  /// Lower runs first.
  IntColumn get priority => integer().withDefault(const Constant(100))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// JSON list of conditions, see `core/engine/rule_engine.dart`.
  TextColumn get conditions => text().withDefault(const Constant('[]'))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get renameMerchant => text().nullable()();
  BoolColumn get markTransfer => boolean().withDefault(const Constant(false))();
  BoolColumn get excludeFromBudget => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StatementRow')
class Statements extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get periodStart => text().nullable()();
  TextColumn get periodEnd => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  IntColumn get openingBalanceMinor => integer().nullable()();
  IntColumn get closingBalanceMinor => integer().nullable()();
  TextColumn get parseStatus => text().withDefault(const Constant('pending'))();
  TextColumn get reconciliationStatus => text().withDefault(const Constant('pending'))();
  IntColumn get diffMinor => integer().nullable()();
  TextColumn get institution => text().nullable()();

  /// credit_card | bank_account
  TextColumn get kind => text().nullable()();

  /// upload | gmail
  TextColumn get source => text().withDefault(const Constant('upload'))();
  TextColumn get fileSha256 => text().nullable()();
  TextColumn get originalFilename => text().nullable()();
  TextColumn get parseError => text().nullable()();

  /// JSON: min due, due date, statement date, totals, warnings...
  TextColumn get summary => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StatementLineRow')
class StatementLines extends Table {
  TextColumn get id => text()();
  TextColumn get statementId => text().references(Statements, #id)();
  IntColumn get lineNo => integer()();
  TextColumn get postedOn => text()();
  TextColumn get description => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  TextColumn get direction => text()();
  IntColumn get foreignAmountMinor => integer().nullable()();
  TextColumn get foreignCurrency => text().nullable()();
  IntColumn get balanceMinor => integer().nullable()();
  TextColumn get transactionId => text().nullable().references(Transactions, #id)();

  /// created | linked | unmatched
  TextColumn get matchStatus => text().withDefault(const Constant('unmatched'))();
  IntColumn get matchScore => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {statementId, lineNo},
  ];
}

@DataClassName('AssetRow')
class Assets extends Table {
  TextColumn get id => text()();

  /// real_estate | fd | gold | stock | crypto | cash | vehicle |
  /// gold_jewellery | other
  TextColumn get kind => text()();
  TextColumn get name => text()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  IntColumn get costBasisMinor => integer().nullable()();
  IntColumn get manualValueMinor => integer().nullable()();

  /// manual | market | estimate
  TextColumn get valuationSource => text().withDefault(const Constant('manual'))();
  DateTimeColumn get valuedAt => dateTime().nullable()();
  TextColumn get acquiredOn => text().nullable()();

  /// Latest automatic valuation (gold spot...); the manual value stays the
  /// fallback.
  IntColumn get marketValueMinor => integer().nullable()();
  DateTimeColumn get marketValuedAt => dateTime().nullable()();
  TextColumn get valuationNote => text().nullable()();
  TextColumn get meta => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LiabilityRow')
class Liabilities extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();

  /// credit_card | personal_loan | auto_loan | mortgage | other
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get lender => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  IntColumn get principalMinor => integer().nullable()();
  IntColumn get outstandingMinor => integer()();
  IntColumn get interestRateBps => integer().nullable()();
  IntColumn get emiMinor => integer().nullable()();
  TextColumn get nextDueOn => text().nullable()();
  TextColumn get endDate => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SalaryRow')
class SalaryRecords extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get employer => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  TextColumn get receivedOn => text()();

  /// One record per detected credit; a dismissed record keeps the link so a
  /// re-scan does not resurrect it.
  TextColumn get transactionId => text().nullable().unique().references(Transactions, #id)();

  /// wps | payroll | salary
  TextColumn get matchedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GoalRow')
class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get targetMinor => integer()();
  IntColumn get savedMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  TextColumn get targetDate => text().nullable()();
  IntColumn get monthlyContributionMinor => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Raw SMS / notification / shortcut payloads kept for reprocessing. OTP
/// messages never get here. Non-transactions are not kept either.
@DataClassName('RawIngestRow')
class RawIngests extends Table {
  TextColumn get id => text()();
  TextColumn get channel => text()();
  TextColumn get externalHash => text().unique()();
  TextColumn get payload => text()();

  /// pending | parsed | failed | needs_review | skipped
  TextColumn get parseStatus => text().withDefault(const Constant('pending'))();
  TextColumn get parseResult => text().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get transactionId => text().nullable().references(Transactions, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SnapshotRow')
class NetWorthSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get snapshotDate => text().unique()();
  IntColumn get assetsMinor => integer()();
  IntColumn get liabilitiesMinor => integer()();
  IntColumn get netWorthMinor => integer()();
  TextColumn get breakdown => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The user's verdict on a detected recurring series: confirmed or dismissed.
@DataClassName('ReviewRow')
class RecurringReviews extends Table {
  TextColumn get seriesKey => text()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {seriesKey};
}

/// Small key/value settings (seed state, catalog version...).
@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
