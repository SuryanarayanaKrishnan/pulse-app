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
  'merchant_rules',
  'statements',
  'statement_lines',
  'assets',
  'liabilities',
  'salary_records',
  'savings_goals',
  'recurring_reviews',
  'jewellery_items',
  'document_attachments',
  'fund_holdings',
};

/// Columns that are meaningful on one phone only: local file paths (files
/// are not synced) and per-device notification ids.
const deviceLocalColumns = <String, Set<String>>{
  'jewellery_items': {'photo_paths'},
  'document_attachments': {'file_paths', 'notification_id'},
};

bool isSyncedColumn(String table, String column) =>
    syncedTables.contains(table) &&
    !(deviceLocalColumns[table]?.contains(column) ?? false);
