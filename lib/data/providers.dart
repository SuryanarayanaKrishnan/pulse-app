import '../capture/kv_store.dart';
import '../core/packs/content_packs.dart';
import '../core/packs/tips.dart';
import '../core/remote_config/remote_config.dart';
import '../core/engine/receipts/receipt_source.dart';
import '../features/splits/auto_settle.dart';
import 'digit_suggestion.dart';
import 'local/receipt_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/env/env.dart';
import '../core/network/api_client.dart';
import 'api/api_pulse_repository.dart';
import '../core/engine/prices.dart';
import 'card_ranking.dart';
import '../core/analytics/analytics.dart';
import '../core/learning/learning_controller.dart';
import 'demo_wealth.dart';
import '../core/engine/budget_moves.dart';
import 'budget_plan_service.dart';
import 'goal_models.dart';
import 'local/budget_plan_store.dart';
import 'goal_service.dart';
import 'local/goal_store.dart';
import 'local/attachments.dart';
import 'local/db_key.dart';
import 'local/encrypted_attachments.dart';
import 'local/price_service.dart';
import 'local/live_prices.dart';
import 'local/cas_import_service.dart';
import '../core/engine/live_quote.dart';
import 'local/reminders.dart';
import '../core/engine/investing.dart' show InvestRule, RuleOccurrence;
import 'http_relay.dart';
import 'investing_service.dart';
import 'local/investing_store.dart';
import 'local/ocr_service.dart';
import 'local/wealth_store.dart';
import 'wealth_models.dart';
import 'wealth_service.dart';
import 'insights.dart';
import 'local/card_value_report.dart';
import 'local/catalog_service.dart';
import 'local/database.dart';
import 'local/ingest_pipeline.dart';
import 'local/local_repository.dart';
import 'mock_repository.dart';
import 'models.dart';
import 'local/statement_service.dart';
import 'statement_password_store.dart';
import 'rules.dart';
import 'statements.dart';
import 'recurring_providers.dart'
    show
        netWorthHistoryProvider,
        recurringChoicesProvider,
        recurringSeriesProvider;
import '../core/engine/goals.dart' show GoalKind;
import '../core/engine/recurring.dart' show Series;
import '../core/engine/recurring_plan.dart' show RecChoice;
import '../core/vault/release.dart';
import '../core/vault/suggestions.dart';
import '../core/vault/vault_models.dart';
import 'local/vault_store.dart';
import 'vault_service.dart';
import 'repository.dart';
import 'budget_import_service.dart';

/// Shared dio client (Supabase JWT interceptor). Overridden in tests.
/// Feature flags and params from the backend (bundled fallback, offline-safe).
/// `main` overrides this with the loaded instance.
final remoteConfigProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService(
    kv: SharedPrefsKvStore(),
    publicKeyB64: Env.configPublicKey,
  );
});

/// Server-delivered content packs (tips, walkthrough text, parser rules).
/// `main` overrides this with the loaded instance.
final contentPacksProvider = Provider<ContentPackService>((ref) {
  return ContentPackService(
    kv: SharedPrefsKvStore(),
    config: ref.watch(remoteConfigProvider),
  );
});

/// Tips and warnings from the Pulse team (the `tips` pack): the downloaded
/// copy when newer, else the bundled one.
final packTipsProvider = Provider.autoDispose<List<PackTip>>(
  (ref) => tipsFromPack(ref.watch(contentPacksProvider).pack('tips')),
);

/// True when [flag] is on for this phone.
final featureFlagProvider = Provider.family<bool, String>(
  (ref, flag) => ref.watch(remoteConfigProvider).isOn(flag),
);

final dioProvider = Provider<Dio>((ref) => buildApiClient());

/// The encrypted on-device database. Opened in `main`; null in widget tests
/// and previews, which then run on demo data.
final localDatabaseProvider = Provider<PulseDatabase?>(
  (ref) => ref.watch(databaseHolderProvider),
);

/// Holds the open database so a restore can swap in the restored one without
/// restarting the app: everything that watches [localDatabaseProvider]
/// rebuilds on [DatabaseHolder.replace].
class DatabaseHolder extends Notifier<PulseDatabase?> {
  DatabaseHolder([this._initial, PulseDatabase? own]) : _own = own ?? _initial;
  final PulseDatabase? _initial;

  /// The person's own ledger, kept open while sample data is showing.
  PulseDatabase? _own;
  @override
  PulseDatabase? build() => _initial;
  void replace(PulseDatabase db) {
    _own = db;
    state = db;
  }

  /// Runs the app on the built-in sample data (every store falls back to its
  /// demo version while there is no database). The ledger on disk is untouched.
  void useSample() => state = null;

  /// Back to the person's own ledger. False when there is none to go back to.
  bool useOwn() {
    final own = _own;
    if (own == null) return false;
    state = own;
    return true;
  }
}

final databaseHolderProvider = NotifierProvider<DatabaseHolder, PulseDatabase?>(
  DatabaseHolder.new,
);

/// The card catalog (bundled, refreshed from the backend when configured).
final catalogServiceProvider = Provider<CatalogService?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return db == null
      ? null
      : CatalogService(db: db, dio: Env.useApi ? ref.watch(dioProvider) : null);
});

/// The on-device ingest pipeline every capture channel feeds.
final ingestPipelineProvider = Provider<IngestPipeline?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (db == null) return null;
  final p = IngestPipeline(
    db,
    globalMap: ref.watch(globalMerchantMapProvider),
    memory: ref.read(merchantMemoryProvider),
  );
  ref.onDispose(p.dispose);
  return p;
});

// ---- Wealth: prices, jewellery, documents, funds ---------------------------

/// Where jewellery, documents, funds and cached prices live: the encrypted
/// database, or memory (demo data, web, tests).
final wealthStoreProvider = Provider<WealthStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null) return demoWealthStore();
  return LocalWealthStore(db);
});

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => kIsWeb || ref.watch(localDatabaseProvider) == null
      ? const NoPhotoPicker()
      : ImagePickerPhotoPicker(),
);

final attachmentStorageProvider = Provider<AttachmentStorage>(
  (ref) => kIsWeb || ref.watch(localDatabaseProvider) == null
      ? MemoryAttachmentStorage()
      : PrivateAttachmentStorage(),
);

/// The family vault's papers: photos and PDFs, encrypted on the phone.
final vaultAttachmentStorageProvider = Provider<AttachmentStorage>(
  (ref) => kIsWeb || ref.watch(localDatabaseProvider) == null
      ? MemoryAttachmentStorage()
      : EncryptedAttachmentStorage(keys: SecureStorageKeyStore()),
);

final remindersProvider = Provider<Reminders>(
  (ref) => kIsWeb || ref.watch(localDatabaseProvider) == null
      ? const NoopReminders()
      : LocalNotificationReminders(),
);

/// Gold and FX prices: fetched from the shared snapshot when `API_BASE_URL`
/// is set, cached locally, with a bundled fallback.
final priceServiceProvider = Provider<PriceService>(
  (ref) => PriceService(
    store: ref.watch(wealthStoreProvider),
    dio: Env.useApi ? ref.watch(dioProvider) : null,
  ),
);

final fundLookupProvider = Provider<FundLookup>(
  (ref) => FundLookup(Env.useApi ? ref.watch(dioProvider) : null),
);

final wealthServiceProvider = Provider<WealthService>(
  (ref) => WealthService(
    store: ref.watch(wealthStoreProvider),
    prices: ref.watch(priceServiceProvider),
    fundLookup: ref.watch(fundLookupProvider),
    reminders: ref.watch(remindersProvider),
    storage: ref.watch(attachmentStorageProvider),
    investing: ref.watch(investingStoreProvider),
  ),
);

// ---- Investing: scans, stock holdings, recurring rules ----------------------

final investingStoreProvider = Provider<InvestingStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null) return demoInvestingStore();
  return LocalInvestingStore(db);
});

/// A plain client for public sources read straight from the phone (AMFI,
/// Stooq). Deliberately not [dioProvider]: no base URL and no auth header, so
/// nothing about the user can reach those hosts.
final publicDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'User-Agent': 'PulseApp'},
    ),
  ),
);

final amfiServiceProvider = Provider<AmfiService>(
  (ref) => AmfiService(
    dio: kIsWeb ? null : ref.watch(publicDioProvider),
    cache: kIsWeb ? MemoryTextCache() : FileTextCache(),
    kv: SharedPrefsKvStore(prefix: 'pulse.prices.'),
  ),
);

/// Reads a CAMS/KFintech CAS PDF on the phone (text extraction, parsing and
/// saving holdings); nothing from the statement leaves the device.
final casImportServiceProvider = Provider<CasImportService>(
  (ref) => CasImportService(
    extractor: const PdfrxTextExtractor(),
    amfi: ref.watch(amfiServiceProvider),
    wealth: ref.watch(wealthServiceProvider),
  ),
);

final livePriceServiceProvider = Provider<LivePriceService>((ref) {
  final kv = SharedPrefsKvStore(prefix: 'pulse.prices.');
  final dio = kIsWeb ? null : ref.watch(publicDioProvider);
  return LivePriceService(
    wealth: ref.watch(wealthStoreProvider),
    investing: ref.watch(investingStoreProvider),
    amfi: ref.watch(amfiServiceProvider),
    stooq: StooqService(dio),
    kv: kv,
    backendStocks: ref.watch(stockQuoteServiceProvider),
  );
});

/// Stored end-of-day quotes (with the previous close) for the day change.
final liveQuotesProvider = FutureProvider<Map<String, LiveQuote>>((ref) => ref.watch(livePriceServiceProvider).quotes());

final stockQuoteServiceProvider = Provider<StockQuoteService>(
  (ref) => StockQuoteService(Env.useApi ? ref.watch(dioProvider) : null),
);

/// Reads text off a screenshot or bill on the phone (ML Kit); none on web.
final ocrServiceProvider = Provider<OcrService>(
  (ref) => kIsWeb || ref.watch(localDatabaseProvider) == null
      ? const NoOcr()
      : MlKitOcr(),
);

final investingServiceProvider = Provider<InvestingService>(
  (ref) => InvestingService(
    store: ref.watch(investingStoreProvider),
    wealth: ref.watch(wealthServiceProvider),
    quotes: ref.watch(stockQuoteServiceProvider),
  ),
);

final stockViewsProvider = FutureProvider<List<StockView>>(
  (ref) => ref.watch(investingServiceProvider).holdingViews(),
);
final ruleViewsProvider = FutureProvider<List<RuleView>>(
  (ref) => ref.watch(investingServiceProvider).ruleViews(),
);
final pendingBuysProvider =
    FutureProvider<List<({InvestRule rule, RuleOccurrence occurrence})>>(
      (ref) => ref.watch(investingServiceProvider).pendingBuys(),
    );

/// The price book the phone values things with (cache over bundled).
final priceBookProvider = FutureProvider<PriceBook>(
  (ref) => ref.watch(wealthServiceProvider).book(),
);
final jewelleryProvider = FutureProvider<List<JewelleryView>>(
  (ref) => ref.watch(wealthServiceProvider).jewelleryViews(),
);
final documentsProvider = FutureProvider<List<WealthDocument>>(
  (ref) => ref.watch(wealthServiceProvider).documents(),
);
final fundsProvider = FutureProvider<List<FundView>>(
  (ref) => ref.watch(wealthServiceProvider).fundViews(),
);
final upcomingProvider = FutureProvider<List<UpcomingItem>>(
  (ref) => ref.watch(wealthServiceProvider).upcoming(),
);
final jewelleryHistoryProvider =
    FutureProvider.family<List<ValuationPoint>, String>(
      (ref, id) => ref.watch(wealthServiceProvider).jewelleryHistory(id),
    );

/// Refreshes everything after jewellery, documents, funds or prices changed.
void invalidateWealth(WidgetRef ref) {
  ref.invalidate(priceBookProvider);
  ref.invalidate(liveQuotesProvider);
  ref.invalidate(jewelleryProvider);
  ref.invalidate(documentsProvider);
  ref.invalidate(fundsProvider);
  ref.invalidate(upcomingProvider);
  ref.invalidate(jewelleryHistoryProvider);
  ref.invalidate(stockViewsProvider);
  ref.invalidate(ruleViewsProvider);
  ref.invalidate(pendingBuysProvider);
  ref.invalidate(netWorthProvider);
  ref.invalidate(assetsProvider);
}

// ---- Flex budget -------------------------------------------------------------

final budgetPlanStoreProvider = Provider<BudgetPlanStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null) return demoBudgetPlanStore();
  return LocalBudgetPlanStore(db);
});

final budgetPlanServiceProvider = Provider<BudgetPlanService>(
  (ref) => BudgetPlanService(
    store: ref.watch(budgetPlanStoreProvider),
    transactions: () => ref.read(repositoryProvider).transactions(),
    onModeChanged: (m) => ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.budgetModeChanged(m.key)),
    onMoved: () => ref.read(analyticsProvider).track(AnalyticsEvent.moneyMoved),
  ),
);

/// The month the Budget tab shows, as the first of that month.
class BudgetMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  void set(DateTime m) => state = DateTime(m.year, m.month, 1);
}

final budgetMonthProvider = NotifierProvider<BudgetMonthNotifier, DateTime>(
  BudgetMonthNotifier.new,
);

final budgetPlanProvider = FutureProvider<BudgetPlanView>(
  (ref) =>
      ref.watch(budgetPlanServiceProvider).view(ref.watch(budgetMonthProvider)),
);

/// Every move not undone, all months and both scopes (the Joint view reads
/// its own from here).
final budgetMovesProvider = FutureProvider<List<BudgetMove>>(
  (ref) => ref.watch(budgetPlanServiceProvider).allMoves(),
);

/// Refreshes the Budget after a budget, a move, a mode or a category's
/// group changed.
void invalidateBudgetPlan(WidgetRef ref) {
  ref.invalidate(budgetPlanProvider);
  ref.invalidate(currentFlexPlanProvider);
  ref.invalidate(budgetProvider);
  ref.invalidate(safeToSpendProvider);
}

// ---- Goals -----------------------------------------------------------------

final goalStoreProvider = Provider<GoalStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null) return demoGoalStore();
  return LocalGoalStore(db);
});

final goalServiceProvider = Provider<GoalService>(
  (ref) => GoalService(
    store: ref.watch(goalStoreProvider),
    assets: () => ref.read(repositoryProvider).assets(),
    onCompleted: () =>
        ref.read(analyticsProvider).track(AnalyticsEvent.goalCompleted),
  ),
);

final goalsProvider = FutureProvider<List<GoalView>>(
  (ref) => ref.watch(goalServiceProvider).views(),
);

/// Refreshes everything after a goal, a contribution or a pause changed:
/// the goals themselves and the safe-to-spend they feed.
void invalidateGoals(WidgetRef ref) {
  ref.invalidate(goalsProvider);
  ref.invalidate(safeToSpendProvider);
}

/// What runs where:
///  * on-device (default): [LocalPulseRepository] over the encrypted DB;
///  * `DEMO_DATA=true` (or no database, as in tests): [MockPulseRepository];
///  * with `API_BASE_URL`, [ApiPulseRepository] serves only the shared
///    features (splits, family, statements, Gmail).
final repositoryProvider = Provider<PulseRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final catalog = ref.watch(catalogServiceProvider);
  final pipeline = ref.watch(ingestPipelineProvider);
  final wealth = ref.watch(wealthServiceProvider);
  if (Env.demoData || db == null || catalog == null || pipeline == null) {
    return MockPulseRepository(
      wealth: wealth,
      goals: ref.watch(goalStoreProvider),
      // Sample data on a phone (the "look around" choice) must not show made-up
      // friends: only the DEMO_DATA preview build seeds split groups.
      seedGroups: Env.demoData,
    );
  }
  return LocalPulseRepository(
    db: db,
    catalog: catalog,
    pipeline: pipeline,
    wealth: wealth,
    statementService: ref.watch(localStatementServiceProvider),
    shared: Env.useApi ? ApiPulseRepository(ref.watch(dioProvider)) : null,
  );
});

/// Every capture that produced a new transaction, as it happens.
final captureOutcomesProvider = StreamProvider<IngestOutcome>(
  (ref) => ref.watch(ingestPipelineProvider)?.results ?? const Stream.empty(),
);

/// Card value report (rankings, rings, hints); empty off-device (demo data).
final cardValueProvider = FutureProvider<CardValueReport>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo is LocalPulseRepository
      ? repo.cardValueReport()
      : const CardValueReport();
});

final transactionsProvider = FutureProvider<List<Transaction>>(
  (ref) => ref.watch(repositoryProvider).transactions(),
);
final budgetProvider = FutureProvider<BudgetOverview>(
  (ref) => ref.watch(repositoryProvider).budgetOverview(),
);

/// "Is ••1234 your card?" questions from alerts waiting on card digits.
final digitSuggestionsProvider = FutureProvider<List<DigitSuggestion>>(
  (ref) => ref.watch(repositoryProvider).digitSuggestions(),
);
final myCardsProvider = FutureProvider<List<CreditCard>>(
  (ref) => ref.watch(repositoryProvider).myCards(),
);
final catalogProvider = FutureProvider<List<CreditCard>>(
  (ref) => ref.watch(repositoryProvider).cardCatalog(),
);
final netWorthProvider = FutureProvider<NetWorth>(
  (ref) => ref.watch(repositoryProvider).netWorth(),
);
final assetsProvider = FutureProvider<List<Asset>>(
  (ref) => ref.watch(repositoryProvider).assets(),
);
final splitGroupsProvider = FutureProvider<List<SplitGroup>>(
  (ref) => ref.watch(repositoryProvider).splitGroups(),
);
final categoriesProvider = FutureProvider<List<SpendCategory>>(
  (ref) => ref.watch(repositoryProvider).categories(),
);
final rulesProvider = FutureProvider<List<AutomationRule>>(
  (ref) => ref.watch(repositoryProvider).rules(),
);
final statementsProvider = FutureProvider<List<Statement>>(
  (ref) => ref.watch(repositoryProvider).statements(),
);

/// Statement passwords stay on this device (Keychain/Keystore), never synced.
final statementPasswordStoreProvider = Provider<StatementPasswordStore>(
  (ref) => SecureStatementPasswordStore(),
);

/// Reads statement PDFs on this device; null with demo data or no database.
final Provider<LocalStatementService?> localStatementServiceProvider =
    Provider<LocalStatementService?>((ref) {
      final db = ref.watch(localDatabaseProvider);
      if (Env.demoData || db == null) return null;
      return LocalStatementService(
        db: db,
        passwords: ref.watch(statementPasswordStoreProvider),
        locked: kIsWeb ? MemoryLockedFileStore() : PrivateLockedFileStore(),
        onTransfer: (c, minor) =>
            ref.read(autoSettleServiceProvider).handle(c, minor),
      );
    });
final statementPasswordsProvider = FutureProvider<List<StatementPassword>>(
  (ref) => ref.watch(statementPasswordStoreProvider).saved(),
);
/// The salary typed in by hand (amount + payday), if any.
final manualSalaryProvider = FutureProvider<ManualSalary?>(
  (ref) => ref.watch(repositoryProvider).manualSalary(),
);
final emailConnectionsProvider = FutureProvider<List<EmailConnection>>(
  (ref) => ref.watch(repositoryProvider).emailConnections(),
);

final cashflowProvider = FutureProvider<Cashflow>(
  (ref) => ref.watch(repositoryProvider).cashflow(),
);
final categoryTrendsProvider = FutureProvider<CategoryTrends>(
  (ref) => ref.watch(repositoryProvider).categoryTrends(),
);

/// This month's Flex plan (not the month the Budget tab happens to show).
final currentFlexPlanProvider = FutureProvider<BudgetPlanView>(
  (ref) => ref.watch(budgetPlanServiceProvider).view(DateTime.now()),
);

/// Safe to spend. In Flex mode the budget limb is the Budget tab's
/// "Flexible left", so the two numbers share one source; otherwise the
/// repository's category budget is used.
final safeToSpendProvider = FutureProvider<SafeToSpend>((ref) async {
  final base = await ref.watch(repositoryProvider).safeToSpend();
  try {
    final plan = await ref.watch(currentFlexPlanProvider.future);
    if (plan.mode == BudgetMode.flex && plan.flex.categories > 0) {
      return base.withBudget(plan.flex.remainingMinor / 100, SafeBasis.flex);
    }
  } catch (_) {}
  return base;
});
final healthScoreProvider = FutureProvider<HealthScore>(
  (ref) => ref.watch(repositoryProvider).healthScore(),
);
final bankAccountsProvider = FutureProvider<List<BankAccount>>(
  (ref) => ref.watch(repositoryProvider).bankAccounts(),
);

/// Best card for each everyday category, for a nominal AED 100 purchase.
final bestByCategoryProvider =
    FutureProvider<List<(SpendCategory, String, BestCardPick?)>>((ref) async {
      ref.watch(myCardsProvider);
      final repo = ref.watch(repositoryProvider);
      return [
        for (final (cat, label) in bestCardCategories)
          (cat, label, (await repo.bestCard(cat, 100)).firstOrNull),
      ];
    });

final householdProvider = FutureProvider<Household>(
  (ref) => ref.watch(repositoryProvider).household(),
);

final List<ProviderOrFamily> _ledgerProviders = [
  transactionsProvider,
  digitSuggestionsProvider,
  budgetProvider,
  currentFlexPlanProvider,
  cashflowProvider,
  categoryTrendsProvider,
  safeToSpendProvider,
  healthScoreProvider,
  bankAccountsProvider,
  bestByCategoryProvider,
  netWorthProvider,
  netWorthHistoryProvider,
  assetsProvider,
];

/// Refreshes everything derived from transactions.
void invalidateLedger(WidgetRef ref) {
  _ledgerProviders.forEach(ref.invalidate);
}

/// Same, for callers that outlive their widget (an Undo snackbar).
void invalidateLedgerIn(ProviderContainer container) {
  _ledgerProviders.forEach(container.invalidate);
}

/// Refreshes everything after the wallet itself changed (a card, an account
/// or an asset was added or removed).
void invalidateWallet(WidgetRef ref) {
  ref.invalidate(myCardsProvider);
  ref.invalidate(digitSuggestionsProvider);
  ref.invalidate(cardValueProvider);
  ref.invalidate(catalogProvider);
  invalidateLedger(ref);
}

/// Where receipt emails come from. Gmail is a stub until the owner creates an
/// OAuth client (docs/RECEIPTS.md), so this is not configured today.
final receiptSourceProvider = Provider<ReceiptSource>(
  (ref) => GmailReceiptSource.fromEnvironment(),
);

/// Links receipt emails to card charges on this device; null with demo data
/// or no database.
final receiptServiceProvider = Provider<ReceiptService?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null) return null;
  return ReceiptService(
    db: db,
    source: ref.watch(receiptSourceProvider),
    analytics: ref.watch(analyticsProvider),
  );
});

/// Held receipts still waiting for their card charge.
final receiptsWaitingProvider = FutureProvider<int>(
  (ref) async => await ref.watch(receiptServiceProvider)?.waitingCount() ?? 0,
);

// ---- Family vault ----------------------------------------------------------

final vaultStoreProvider = Provider<VaultStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (db == null) return MemoryVaultStore();
  return LocalVaultStore(db);
});

/// Automatic release goes through the Pulse backend when `API_BASE_URL` is set;
/// otherwise nothing is released automatically (docs/VAULT.md).
final inactivityRelayProvider = Provider<InactivityRelay>(
  (ref) => Env.useApi
      ? HttpInactivityRelay(ref.watch(dioProvider))
      : const UnavailableInactivityRelay(),
);

final vaultServiceProvider = Provider<VaultService>(
  (ref) => VaultService(
    store: ref.watch(vaultStoreProvider),
    storage: ref.watch(vaultAttachmentStorageProvider),
    relay: ref.watch(inactivityRelayProvider),
    reminders: ref.watch(remindersProvider),
    analytics: ref.watch(analyticsProvider),
    sources: () async {
      final repo = ref.read(repositoryProvider);
      final series = await ref
          .read(recurringSeriesProvider.future)
          .catchError((_) => <Series>[]);
      final choices = await ref
          .read(recurringChoicesProvider.future)
          .catchError((_) => <String, RecChoice>{});
      final goals = await ref
          .read(goalsProvider.future)
          .catchError((_) => <GoalView>[]);
      final funds = await ref
          .read(fundsProvider.future)
          .catchError((_) => <FundView>[]);
      return VaultSourceData(
        accounts: await repo.bankAccounts().catchError((_) => <BankAccount>[]),
        cards: await repo.myCards().catchError((_) => <CreditCard>[]),
        assets: await repo.assets().catchError((_) => <Asset>[]),
        funds: [for (final f in funds) f.holding],
        documents: await ref
            .read(documentsProvider.future)
            .catchError((_) => <WealthDocument>[]),
        rules: await ref
            .read(investingStoreProvider)
            .rules()
            .catchError((_) => <InvestRule>[]),
        recurring: [
          for (final s in series)
            if (choices[s.key] != RecChoice.ignored && s.status != 'lapsed')
              (
                key: s.key,
                merchant: s.merchant,
                isSubscription: s.isSubscription,
              ),
        ],
        paydownGoals: [
          for (final g in goals)
            if (g.record.kind == GoalKind.paydown)
              (id: g.record.id, name: g.record.name),
        ],
      );
    },
  ),
);

final vaultEntriesProvider = FutureProvider<List<VaultEntry>>(
  (ref) => ref.watch(vaultServiceProvider).entries(),
);
final vaultNomineesProvider = FutureProvider<List<Nominee>>(
  (ref) => ref.watch(vaultServiceProvider).nominees(),
);
final vaultScoreProvider = FutureProvider<Completeness>((ref) async {
  ref.watch(vaultEntriesProvider);
  return ref.watch(vaultServiceProvider).score();
});
final vaultSuggestionsProvider = FutureProvider<List<VaultSource>>((ref) async {
  ref.watch(vaultEntriesProvider);
  return ref.watch(vaultServiceProvider).suggestions();
});
final vaultStatusProvider = FutureProvider<CheckInStatus>((ref) async {
  ref.watch(vaultCheckInTickProvider);
  return ref.watch(vaultServiceProvider).status();
});

/// Bumped after the interval changes or the app records a check-in.
class VaultTick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final vaultCheckInTickProvider = NotifierProvider<VaultTick, int>(
  VaultTick.new,
);

void invalidateVault(WidgetRef ref) {
  ref.invalidate(vaultEntriesProvider);
  ref.invalidate(vaultNomineesProvider);
  ref.invalidate(vaultScoreProvider);
  ref.invalidate(vaultSuggestionsProvider);
  ref.read(vaultCheckInTickProvider.notifier).bump();
}

// ---- Budget setup: suggestion and import -------------------------------------

final budgetImportServiceProvider = Provider<BudgetImportService>(
  (ref) => BudgetImportService(
    repo: ref.watch(repositoryProvider),
    plan: ref.watch(budgetPlanServiceProvider),
  ),
);
