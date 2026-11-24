# Encrypted backup and restore

The ledger lives on the phone. Backup exists so a lost or replaced phone never means lost data, while the server (or cloud drive) only ever holds ciphertext. Everything here is free: `cryptography` and `cryptography_flutter` (Apache-2.0), `bip39` (BSD), `workmanager` (MIT), `connectivity_plus` (BSD), Supabase Storage free tier, files the user keeps themselves.

## Design

- **Secret**: a 12-word BIP-39 recovery phrase (recommended, generated on the phone, shown once and verified by re-typing 3 words) or a user passphrase (10+ characters, explicit "cannot be recovered" acknowledgement).
- **Keys**: Argon2id (19 MiB, 3 passes, 16-byte random salt; parameters are stored and authenticated) turns the secret into a master key. The master key only wraps a random 32-byte **data key** (AES-256-GCM). HKDF-SHA256 derives separate sub-keys for chunks, manifests and chunk naming.
- **Objects** (`key.json`, `manifests/<time>-<id>.bin`, `chunks/<id>`): AES-256-GCM, random nonce, name or id bound as associated data. Chunk names are an HMAC of the plaintext under a secret key, so unchanged chunks are not re-uploaded (dedupe) but the server cannot test a guessed file against a name.
- **Content**: every table row (generic, column-name keyed, 400 rows per chunk) plus every photo/document file the ledger references (2 MiB chunks). The encrypted manifest lists tables, files, chunk ids, the app schema version and a keyed tree hash. A snapshot exists only once its manifest is written, last.
- **Versions**: last N (default 5) manifests are kept; unreferenced chunks are deleted, except ones younger than 2 hours or of unknown age (so another device mid-upload is safe).
- **Change passphrase** re-wraps the same data key under a new salt and writes `key.json`; no data is re-uploaded. Old exported files still open with the old secret.
- **Restore**: read `key.json`, derive, unwrap (wrong secret fails the GCM tag), list versions, check every chunk exists, decrypt and verify each (GCM tag plus recomputed chunk id plus manifest tree hash), write files, import into a **fresh** encrypted database created under a **new** random keystore key, then swap: current database is renamed to a safety copy (kept 7 days), the restored one takes its place, the new key replaces the old. Any failure before the swap leaves the phone untouched and removes partial files. Existing data triggers a confirmation first.
- **Schema versions**: a backup from a newer schema is refused ("update the app"); an older one is imported by column name (unknown columns dropped, new ones default) and passes through `RowUpgrader` hooks for non-additive changes (none needed yet).
- **Where the data key lives**: the keystore (iOS Keychain this-device-only, Android Keystore), so automatic backups need no prompt. The passphrase and phrase are never stored or sent.

## Destinations (`BackupProvider`)

| Provider | Status |
| --- | --- |
| Supabase Storage (private bucket, per-user prefix, existing auth) | Implemented. Not exercised against a live project here. |
| Local file export/import (`.pulsebak`, share sheet / file picker) | Implemented and tested end to end. |
| Google Drive `appDataFolder` | Stub. Needs a free Google Cloud OAuth client and `google_sign_in` native setup. |
| iCloud Drive | Stub. Needs the iCloud capability and a native file-coordination bridge in Xcode. |

## Automatic backups

Changes to ledger tables (not price caches, settings or snapshots) mark the backup dirty and start a 2 minute debounce; Wi-Fi only by default; failures retry 30 min x failure count. App resume catches up after 24 hours. A daily `workmanager` task (unmetered network) runs the same code in a background isolate. Failures are shown calmly ("Your data is safe on this phone") and only called out after three in a row. iOS decides when background tasks run, so foreground triggers are the dependable path there.

## Supabase setup (free tier)

```sql
insert into storage.buckets (id, name, public, file_size_limit)
values ('pulse-backups', 'pulse-backups', false, 10485760)
on conflict (id) do nothing;

create policy "backup read own"   on storage.objects for select to authenticated
  using (bucket_id = 'pulse-backups' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "backup insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'pulse-backups' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "backup update own" on storage.objects for update to authenticated
  using (bucket_id = 'pulse-backups' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'pulse-backups' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "backup delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'pulse-backups' and (storage.foldername(name))[1] = auth.uid()::text);
```

Free tier limits: 1 GB storage, 50 MB per file. Photos make the quota the practical limit; the app shows "storage full" calmly and the file export remains.

## Threat model

Protects against: server or cloud-drive operator, database leak, a Supabase employee, network observers, tampering or swapping of stored objects (detected, restore refused), a stolen backup file without the secret (offline guessing is slowed by Argon2id; a recovery phrase has 128 bits).

Does not protect against: a weak user-chosen passphrase; malware or someone unlocked on the phone (the data key is in the keystore and the database is readable while the app runs); someone who has the recovery phrase; a rooted device. Metadata is visible to the server: that the user has a backup, object count, sizes (approximate data volume) and upload times; names reveal nothing. An attacker with write access can delete or roll back backups (availability, and the older-snapshot case); they cannot forge content. **Forget the secret and lose the phrase, and the backup is unrecoverable by design.**

## Unverified in this environment

No Android SDK, Xcode or live Supabase project was available. Not verified: the WorkManager/BGTask registration (including the `Info.plist` and `AppDelegate.swift` entries), the Supabase provider against real Storage, share sheet and file picker on devices, Argon2id timing on a real phone (pure Dart in an isolate; lower the cost in `KdfParams.production` if too slow), and native sqlite3mc builds for mobile. Everything else is covered by unit, database and widget tests with real encrypted SQLite files.
