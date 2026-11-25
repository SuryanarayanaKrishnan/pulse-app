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

  /// Whose it is: `me` (default), `shared`, or another household member's id.
  TextColumn get owner => text().withDefault(const Constant('me'))();

  /// Private items never leave this phone: not in sync to the household, not
  /// in any joint view. (They still sync to your own devices.)
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

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

  /// The glyph a user picked for a custom category (a key of the Pulse
  /// category icon family). Null for defaults, which have fixed glyphs.
  /// Synced like any other column.
  TextColumn get iconKey => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  /// Flex budgeting group: `fixed` | `flexible` | `nonmonthly`. Null falls
  /// back to the default (fixed categories are Fixed, the rest Flexible).
  TextColumn get budgetGroup => text().nullable()();

  /// Unspent (or overspent) amount carries into the next month.
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();

  /// First month (`YYYY-MM-01`) the rollover counts from, and the balance it
  /// opens with. Null start: the category's earliest budget month.
  TextColumn get rolloverStart => text().nullable()();
  IntColumn get rolloverStartMinor => integer().withDefault(const Constant(0))();

  /// Non-monthly: the whole cost per cycle and the cycle length in months.
  /// The monthly amount is the cost spread over the cycle.
  IntColumn get cycleCostMinor => integer().withDefault(const Constant(0))();
  IntColumn get cycleMonths => integer().withDefault(const Constant(1))();

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

  /// The user has looked at this and it is right (swipe-to-review). Captured
  /// payments start unreviewed; anything the user typed or edited is reviewed.
  /// Synced like any other column.
  BoolColumn get reviewed => boolean().withDefault(const Constant(false))();

  /// Link to the receipt email that explained this charge (a message id, not
  /// the email itself). Null when no receipt was matched. Synced.
  TextColumn get receiptRef => text().nullable()();

  /// Item-level notes extracted from that receipt (items, fees, promos).
  /// Extracted fields only: raw email bodies are never stored or synced.
  TextColumn get receiptNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Whose it is: `me` (default), `shared`, or another household member's id.
  TextColumn get owner => text().withDefault(const Constant('me'))();

  /// Private items never leave this phone: not in sync to the household, not
  /// in any joint view. (They still sync to your own devices.)
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

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

  /// Whose it is: `me` (default), `shared`, or another household member's id.
  TextColumn get owner => text().withDefault(const Constant('me'))();

  /// Private items never leave this phone: not in sync to the household, not
  /// in any joint view. (They still sync to your own devices.)
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

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

  /// Whose it is: `me` (default), `shared`, or another household member's id.
  TextColumn get owner => text().withDefault(const Constant('me'))();

  /// Private items never leave this phone: not in sync to the household, not
  /// in any joint view. (They still sync to your own devices.)
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

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

  /// The starting amount: what you already had (save), or the balance owed
  /// when you began (pay down). Contributions are rows in `goal_contributions`.
  IntColumn get savedMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  TextColumn get targetDate => text().nullable()();
  IntColumn get monthlyContributionMinor => integer().nullable()();

  /// save | pay down: `save` | `paydown`.
  TextColumn get kind => text().withDefault(const Constant('save'))();

  /// A glyph key from the category icon family.
  TextColumn get iconKey => text().nullable()();

  /// An Asset id as the Wealth list knows it (`account:..`, an asset, a
  /// liability or `card:..`). Null: contributions are logged by hand.
  TextColumn get linkedRef => text().nullable()();

  /// Paused goals reserve nothing from safe-to-spend.
  BoolColumn get paused => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Whose it is: `me` (default), `shared`, or another household member's id.
  TextColumn get owner => text().withDefault(const Constant('me'))();

  /// Private items never leave this phone: not in sync to the household, not
  /// in any joint view. (They still sync to your own devices.)
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Money put into (positive) or taken out of (negative) a goal, or paid
/// towards a pay down goal.
@DataClassName('GoalContributionRow')
class GoalContributions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get onDate => text()();
  TextColumn get note => text().nullable()();
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

// ---- schema v2: priced assets, documents, funds ---------------------------

/// Last prices fetched from the shared snapshot (`GET /v1/prices/snapshot`),
/// one row per symbol: `XAU_AED_G_24K`, `XAU_AED_G_22K`, `FX_USD_AED`... The
/// phone revalues gold, jewellery and funds from these rows alone, so values
/// still work offline.
@DataClassName('PriceRow')
class PriceCache extends Table {
  TextColumn get symbol => text()();
  RealColumn get price => real()();

  /// What [price] is quoted in (`AED`).
  TextColumn get unit => text().withDefault(const Constant('AED'))();
  TextColumn get source => text().nullable()();

  /// live | stale | unavailable, as reported by the backend.
  TextColumn get status => text().withDefault(const Constant('live'))();

  /// When the source last quoted it (null when unknown).
  DateTimeColumn get quotedAt => dateTime().nullable()();

  /// When this phone last fetched it.
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {symbol};
}

/// A piece of gold jewellery. Valued locally as weight x purity x gold price;
/// photos are files in the app-private folder, never uploaded.
@DataClassName('JewelleryRow')
class JewelleryItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get weightGrams => real()();

  /// 24 | 22 | 21 | 18 (or 0 with a purity override).
  IntColumn get karat => integer()();

  /// Fineness 0..1 when it is not a plain karat (e.g. 0.875).
  RealColumn get purityOverride => real().nullable()();
  IntColumn get purchasePriceMinor => integer().nullable()();
  TextColumn get purchaseDate => text().nullable()();
  IntColumn get makingChargesMinor => integer().nullable()();
  TextColumn get notes => text().nullable()();

  /// JSON list of file paths inside the app-private attachments folder.
  TextColumn get photoPaths => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// True when the weight, karat or price were estimated rather than read
  /// off a bill (added in schema v11).
  BoolColumn get approximate => boolean().withDefault(const Constant(false))();

  /// Household ownership (added in schema v12): `me`, `shared` or a member id,
  /// and a Private flag that keeps the item out of every household log.
  TextColumn get owner => text().withDefault(const Constant('me'))();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A scan or photo of a document (title deed, FD certificate, insurance...)
/// with metadata and an optional date that drives a local reminder.
@DataClassName('DocumentRow')
class DocumentAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();

  /// title_deed | fd_certificate | insurance | passport | emirates_id | other
  TextColumn get category => text()();
  TextColumn get notes => text().nullable()();

  /// JSON list of file paths inside the app-private attachments folder.
  TextColumn get filePaths => text().withDefault(const Constant('[]'))();

  /// ISO date (yyyy-mm-dd) of the expiry, maturity or renewal.
  TextColumn get dueOn => text().nullable()();

  /// expiry | maturity | renewal
  TextColumn get dueKind => text().withDefault(const Constant('expiry'))();

  /// Days before [dueOn] to notify; null = no reminder.
  IntColumn get remindDaysBefore => integer().nullable()();

  /// Id of the scheduled local notification (stable per document).
  IntColumn get notificationId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A mutual fund position: an Indian scheme found by search (`india_mf`, NAV
/// from mfapi.in through the backend) or one entered by hand (`manual`).
@DataClassName('FundRow')
class FundHoldings extends Table {
  TextColumn get id => text()();

  /// india_mf | manual
  TextColumn get kind => text()();
  TextColumn get schemeCode => text().nullable()();
  TextColumn get name => text()();

  /// Currency of the NAV (INR for Indian funds, AED/USD for others).
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  RealColumn get units => real()();

  /// Average cost per unit, in [currency].
  RealColumn get avgCostNav => real().nullable()();
  RealColumn get nav => real()();
  TextColumn get navDate => text().nullable()();

  /// market | manual
  TextColumn get navSource => text().withDefault(const Constant('manual'))();
  DateTimeColumn get navFetchedAt => dateTime().nullable()();

  /// Monthly SIP amount in [currency] minor units, and the debit day.
  IntColumn get sipAmountMinor => integer().nullable()();
  IntColumn get sipDay => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Household ownership (added in schema v12): `me`, `shared` or a member id,
  /// and a Private flag that keeps the item out of every household log.
  TextColumn get owner => text().withDefault(const Constant('me'))();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One stored valuation of one thing on one day (jewellery value over time).
/// The latest value of a day replaces the earlier ones.
@DataClassName('ValuationRow')
class ValuationSnapshots extends Table {
  TextColumn get id => text()();

  /// jewellery | fund
  TextColumn get subjectKind => text()();
  TextColumn get subjectId => text()();
  TextColumn get snapshotDate => text()();
  IntColumn get valueMinor => integer()();

  /// The AED/g (or NAV) used, so the chart can be explained later.
  RealColumn get unitPrice => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {subjectKind, subjectId, snapshotDate},
  ];
}


// ---- Household (schema v6) ---------------------------------------------------
//
// None of these tables is on the sync allow-list: the household log is its
// own end-to-end encrypted channel (see docs/HOUSEHOLD.md), and its key lives
// in the keystore of this phone only.

/// The one household this phone belongs to (at most one row).
@DataClassName('HouseholdConfigRow')
class HouseholdConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get myMemberId => text()();
  BoolColumn get shareMine => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HouseholdMemberRow')
class HouseholdMembers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get joinedAt => dateTime().nullable()();

  /// Member id of whoever removed this member (schema v12). Set when the
  /// household is re-keyed without them; null for everyone else.
  TextColumn get removedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A recurring due split between members. `split` is JSON: member id -> basis
/// points.
@DataClassName('HouseholdBillRow')
class HouseholdBills extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  IntColumn get dueDay => integer()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get split => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A joint monthly limit on a category.
@DataClassName('HouseholdLimitRow')
class HouseholdLimits extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  IntColumn get limitMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// What the other members shared with this phone: read-only copies of their
/// rows, kept apart from the ledger so they can never be mistaken for (or
/// double counted with) your own. `payload` is JSON.
@DataClassName('HouseholdMirrorRow')
class HouseholdMirror extends Table {
  TextColumn get kind => text()();
  TextColumn get rowId => text()();
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {kind, rowId};
}


/// A move of planned amount from one category to another, inside one month.
/// Undo soft-deletes it. `scope` is `me` or `shared` (the Joint view's
/// limits), so Mine and Joint budgets never mix.
@DataClassName('BudgetMoveRow')
class BudgetMoves extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text().withDefault(const Constant('me'))();

  /// `YYYY-MM-01`.
  TextColumn get month => text()();
  TextColumn get fromCategoryId => text()();
  TextColumn get toCategoryId => text()();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Budget view preferences, one row (`id = 'main'`). `mode` is `flex`
/// (Fixed / Flexible / Non-monthly groups) or `category` (every category on
/// its own).
@DataClassName('BudgetPrefRow')
class BudgetPrefs extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text().withDefault(const Constant('flex'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---- schema v8: recurring payments -----------------------------------------

/// What the user decided about a detected recurring series: `confirmed` (it
/// is a real subscription or bill) or `ignored` (not recurring, hide it).
/// Keyed by the series key (the normalised merchant, plus `#<amount>` for an
/// amount tier). Deleting the row undoes the choice. Replaces the unused
/// `recurring_reviews`, whose rows are copied across when migrating.
@DataClassName('RecurringChoiceRow')
class RecurringChoices extends Table {
  TextColumn get seriesKey => text()();
  TextColumn get choice => text()();

  /// The merchant's name when the choice was made, so a list can show it
  /// even when the series is not detected right now.
  TextColumn get merchant => text().withDefault(const Constant(''))();
  DateTimeColumn get decidedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {seriesKey};
}

/// One thing the family would need to find. It says where to look, never the
/// secret: the app refuses passwords, PINs and full card or IBAN numbers
/// before they get here (`core/vault/input_guard.dart`).
@DataClassName('VaultEntryRow')
class VaultEntries extends Table {
  TextColumn get id => text()();

  /// bank | card | loan | insurance | investment | property | crypto |
  /// subscription | digital | documents | identity
  TextColumn get type => text()();
  TextColumn get institution => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get whereToFind => text().withDefault(const Constant(''))();

  /// The nominee named on the account or policy itself, as free text.
  TextColumn get nomineeName => text().withDefault(const Constant(''))();
  TextColumn get contactPerson => text().withDefault(const Constant(''))();

  /// Optional rough value in AED fils.
  IntColumn get estimatedValueMinor => integer().nullable()();

  /// JSON list of file paths in the app-private attachments folder. Device
  /// local: never synced.
  TextColumn get photoPaths => text().withDefault(const Constant('[]'))();

  /// `account:<id>` etc. when the entry came from a suggestion.
  TextColumn get sourceRef => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A trusted person who may be handed an emergency export. Release secrets
/// and key shares are never stored here (they live in `app_settings`, which
/// never syncs).
@DataClassName('VaultNomineeRow')
class VaultNominees extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get relationship => text().withDefault(const Constant(''))();
  TextColumn get contact => text().withDefault(const Constant(''))();

  /// `*` for everything, otherwise a JSON list of entry ids.
  TextColumn get entryIds => text().withDefault(const Constant('*'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}


// ---- Investing (schema v11) ---------------------------------------------------

/// A stock or ETF position, entered by hand or read from a portfolio
/// screenshot. Valued locally: units x last close (from the price service),
/// converted at the cached FX rate. `approximate` marks quantities or costs
/// the user estimated.
@DataClassName('InvestmentRow')
class InvestmentHoldings extends Table {
  TextColumn get id => text()();

  /// Upper-case ticker, US listing (VOO, AAPL).
  TextColumn get symbol => text()();
  TextColumn get name => text().nullable()();

  /// Currency of the price and cost.
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  RealColumn get quantity => real()();

  /// Average cost per unit in [currency]; null when unknown.
  RealColumn get avgCost => real().nullable()();
  RealColumn get lastPrice => real().nullable()();
  DateTimeColumn get priceAt => dateTime().nullable()();
  TextColumn get priceSource => text().nullable()();
  TextColumn get purchaseDate => text().nullable()();
  BoolColumn get approximate => boolean().withDefault(const Constant(false))();

  /// screenshot | typed | manual | rule
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// "Buy 200 USD of VOO every month on the 5th."
@DataClassName('InvestingRuleRow')
class InvestingRules extends Table {
  TextColumn get id => text()();
  TextColumn get symbol => text()();
  TextColumn get name => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  /// weekly | monthly
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();

  /// Day of month (monthly) or weekday 1-7 (weekly).
  IntColumn get day => integer().withDefault(const Constant(1))();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One planned buy of a rule: pending until the user confirms or skips it.
@DataClassName('InvestingOccurrenceRow')
class InvestingOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get ruleId => text()();
  TextColumn get dueDate => text()();
  IntColumn get amountMinor => integer()();

  /// pending | confirmed | skipped
  TextColumn get status => text().withDefault(const Constant('pending'))();
  RealColumn get price => real().nullable()();
  RealColumn get units => real().nullable()();
  TextColumn get decidedOn => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {ruleId, dueDate},
  ];
}
