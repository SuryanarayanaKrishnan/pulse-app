/// What may leave the phone, as an explicit allow-list: a table added to the
/// schema later does not sync until it is listed here on purpose.
///
/// Deliberately absent:
/// * `raw_ingests`: raw SMS and notification payloads (OTP messages are
///   never stored there, but the payloads are the most sensitive text the
///   app holds, and they are re-derivable);
/// * `app_settings`: per-device flags;
/// * `catalog_cards`: bundled reference data;
/// * `price_cache`, `valuation_snapshots`, `net_worth_snapshots`: caches the
///   app recomputes.
const syncedTables = <String>{
  'accounts',
  'user_cards',
  'categories',
  'transactions',
  'budgets',
  'budget_moves',
  'budget_prefs',
  'merchant_rules',
  'statements',
  'statement_lines',
  'assets',
  'liabilities',
  'salary_records',
  'savings_goals',
  'goal_contributions',
  'recurring_reviews',
  'recurring_choices',
  'jewellery_items',
  'document_attachments',
  'fund_holdings',
  'investment_holdings',
  'investing_rules',
  'investing_occurrences',
  // The family vault: where things are, never secrets (the input guard
  // refuses them). Release secrets and key shares live in `app_settings`
  // and never sync.
  'vault_entries',
  'vault_nominees',
};

/// Columns that are meaningful on one phone only: local file paths (files
/// are not synced) and per-device notification ids.
const deviceLocalColumns = <String, Set<String>>{
  'jewellery_items': {'photo_paths'},
  'document_attachments': {'file_paths', 'notification_id'},
  'vault_entries': {'photo_paths'},
};

bool isSyncedColumn(String table, String column) =>
    syncedTables.contains(table) &&
    !(deviceLocalColumns[table]?.contains(column) ?? false);
