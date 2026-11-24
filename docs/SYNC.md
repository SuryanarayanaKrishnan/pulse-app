# Encrypted multi-device sync

Continuous sync between a user's phones, built on the backup feature (`docs/BACKUP.md`). It shares the backup **data key**, so there is no new secret to remember: a second phone joins by restoring from backup (recovery phrase or passphrase), which puts the data key in its keystore. The server only ever sees ciphertext. Everything is free (Supabase Storage free tier, no new packages; `fake_async` was added as a dev dependency for tests).

## Design

- **Change log, not row copies.** Every local mutation becomes field writes `(table, row id, column, value, hybrid timestamp)`. The unit is one field, so edits to different fields of one row never conflict.
- **Timestamps** are hybrid logical clocks (`lib/core/sync/hlc.dart`): wall milliseconds, a counter, and the device id. They are totally ordered, strictly increase on a device even if its wall clock stalls or goes back, and move past anything the device has seen. A remote clock more than one day ahead is clamped when observed.
- **Merge** (`lib/core/sync/sync_state.dart`): per field, the greatest timestamp wins (last writer wins). A row's existence is itself a register (`_del`): `true` is a tombstone, a later `false` re-creates it. Merging is commutative, associative and idempotent (property-tested with shuffled and duplicated input).
  - Concurrent edit of different fields: both kept. Same field: later timestamp wins on every device.
  - Delete vs concurrent edit: the delete wins (the edit stays in the registers and returns if the row is re-created later).
- **Capturing local edits** without triggers or a schema change: the engine keeps, per field, the last winning value (the registers). Before each sync it reads the synced tables and compares them with the registers; differences are new local writes and rows that vanished are deletes. Remote changes are written to the database and into the registers together, so they are never re-reported. Cost is one scan of the synced tables per sync (a few thousand rows: milliseconds).
- **Segments** (`segment_codec.dart`): each device appends numbered segments `sync/<device id>/<seq>.seg` (up to 500 field writes; only the newest write per field). AES-256-GCM with an HKDF sub-key (`sync.segments`) of the backup data key, random nonce, the object name as associated data (so a segment cannot be served under another name or sequence number). Device ids are random, so names reveal nothing but the number of devices and how many segments each has.
- **Pull**: list `sync/`, for every other device read segments after its cursor, strictly in order (a gap stops that device until the missing segment appears), decrypt, merge, write the changed rows to the database, advance the cursor, save. **Push**: number the pending changes as the next segment and persist it *before* uploading, so a retry sends the same content under the same name; a reader that already took the segment never misses anything.
- **Idempotent and resumable**: re-reading a segment changes nothing; cursors only advance after the segment is merged and saved; a lost upload response, an app kill or a dropped connection at any point leaves a state the next run continues from (all covered by tests).
- **Joining**: a device's first sync reads the other devices' log *before* comparing its own data, so a phone restored from an older backup adopts newer values instead of overwriting them, and a row the others deleted is deleted there rather than resurrected. Rows only the new phone has are then sent as new.
- **State** (`lib/sync/file_sync_state_store.dart`) lives in a file beside the database, not in it, because it names this device and a backup of the database must never carry a device id to another phone. Every save writes a random epoch to the file and to the database; if they differ (the database was restored, replaced or the state file lost) the state is discarded and the phone starts over as a new device with the safe "join" behaviour above, instead of reporting a restore as mass deletes.

## What syncs

An explicit allow-list (`lib/core/sync/sync_scope.dart`): accounts, user cards, categories, transactions, budgets, merchant rules, statements and lines, assets, liabilities, salary records, savings goals, recurring reviews, jewellery, document records, fund holdings. A new table does not sync until it is added on purpose.

Never synced: `raw_ingests` (raw SMS/notification payloads; OTP messages are never stored by the app and are never read by sync), `app_settings`, `catalog_cards`, price/valuation/net-worth caches, local file paths (`photo_paths`, `file_paths`) and per-device notification ids. Photos and document files are not synced (see limits). Table and column names from a segment are checked against the allow-list and the real schema before they reach SQL.

## When it runs

- App resume (after a 1 minute cooldown), shortly after local writes to synced tables (20 s debounce, so a burst is one sync), and Settings > Sync devices > Sync now (also works while automatic sync is off).
- One run at a time; failures back off 1, 2, 4... up to 30 minutes for automatic triggers only. A manual run always goes.
- Needs: encrypted backup set up or restored on this phone (the data key), a signed-in cloud account, and the "Keep devices in sync" switch (off by default). Status ("Synced 3 min ago", "You're offline...") is shown in Settings and on the Sync screen.

## Analytics

`sync_started{trigger}`, `sync_completed{trigger, changes_bucket: none|few|many, seconds}`, `sync_failed{trigger, reason: offline|signed_out|too_new|integrity|keys_missing|other}`. No rows, names, amounts, counts or key material.

## Transport

`SyncTransport` (`sync_transport.dart`): `ensureReady`, `list`, `read`, `write`. Implementations:

| Transport | Status |
| --- | --- |
| `MemorySyncTransport` (shared "server" for tests) | Implemented and used by the two- and three-device simulations. |
| `SupabaseSyncTransport` (same private bucket `pulse-backups`, prefix `<user id>/sync/`; the RLS policies in `docs/BACKUP.md` already cover it) | **Compiled but NOT tested against a real Supabase project.** Listing (two-level walk), 404 handling and upsert behaviour are written from the API docs only. |

## Threat model

Same as backup: the server, a database leak, network observers and tampering are covered (any altered, truncated, re-keyed or renamed segment fails GCM and stops the sync with an "integrity" status; nothing from it is applied). Visible to the server: that the user syncs, how many devices, segment counts, sizes and times. A server can withhold or delay segments (the pull waits at a gap) or roll the log back (older state, not forged state); it cannot forge or alter content. A device that is compromised, or that holds the data key, can write anything: sync is not an authorization boundary between a user's own devices.

## Limits

- **Not verified on real infrastructure**: Supabase transport (above); two physical phones; background execution (sync runs in the foreground only: resume, writes, manual).
- **Photos and document files do not sync**, only their records (the file paths are device-local). A restored phone gets files from a backup, not from sync.
- **The log is never compacted.** It grows with the number of edits (segments are small). Compaction (a snapshot segment plus pruning) is not implemented; a new device replays the whole log after joining.
- **Conflicts are per field and by timestamp**: no merging inside a text field, and "delete wins" over a concurrent edit. A device with a clock more than a day ahead can still win conflicts up to that day.
- **First sync prefers the log**: on a device's very first sync, a field that both the log and the phone have is taken from the log, even if the phone's edit was newer.
- **Schema skew**: a segment from a newer app schema stops the sync ("update the app"); older segments are applied by column name (unknown columns ignored). Rows that violate a constraint locally (for example a missing NOT NULL value) are retried each sync and shown as unapplied internally, never silently dropped or turned into deletes.
- **Account switch**: the state is not tied to the signed-in user; signing in to a different account on the same phone without a restore mixes logs. Not handled.
- **Crash window**: a crash between writing merged rows and saving the state can later re-send an identical value with a newer timestamp (harmless unless another device edited that exact field in between).
- Foreign keys are switched off while merged rows are written (rows can arrive before their parents), so a dangling reference can exist until the parent arrives.
- Web builds and demo mode have no sync.
