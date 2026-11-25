# Household planning

A couple or family manages money jointly while everything stays on-device first and end-to-end encrypted. It reuses the sync machinery (`docs/SYNC.md`): the same change-log merge, hybrid clocks, segment codec and transport interface, with a separate log, a separate key and a strict privacy gate. Free: no new paid service; `qr_flutter` (BSD) draws the invite QR and `mobile_scanner` (BSD) reads it.

## What the user sees

- **Settings > Household**: start a household, join with a code (scan the QR in the app, or paste), members, invite (QR and code), remove a member, change the household code, "Share my items", shared bills (rent, internet, the helper, split by a slider or equally), sync status, leave.
- **Mine / Partner's / Shared** on a transaction (Transaction detail > Household), a Wealth row (account, card balance, asset, loan: tap it) and a goal (Goal detail), plus a **Private** switch. The sheet is the same everywhere (`features/household/ownership_widgets.dart`).
- **Budget > Mine | Joint**: household spend against joint category limits, who spent it (by member and Shared), shared bills with each person's share, shared goals.
- **Wealth > Mine | Joint**: joint net worth, by person, and the list of what is counted.

The toggles appear only once there is a household; nothing changes for a single user.

## Ownership model

Seven tables carry `owner` (default `me`) and `is_private` (default false): `accounts`, `transactions`, `assets`, `liabilities`, `savings_goals` (schema v6), `jewellery_items` and `fund_holdings` (schema v12). `owner` is `me`, `shared` or another member's id. Stored locally as `me` and converted to the member's real id when it leaves the phone (and back), so an owner means the same thing on every phone.

Net worth lines come from the Wealth list; an `account:`/`card:` row takes its ownership from the account, an asset or loan row from its own table, a `jewel:` row from the piece and a `fund:` row from the holding (set on the piece's or fund's detail screen). Rows with no ownership columns (stocks and ETFs, `stock:`) are treated as Private, and so is any line whose ownership cannot be found. Jewellery and funds that existed before v12 were migrated as Private, so the upgrade shares nothing; new ones start as Mine (shared while "Share my items" is on, like a new account) until marked Private.

## Joint views (`lib/core/household/household_engine.dart`, pure)

- **Visible in a joint view**: not Private, and mine only while "Share my items" is on. Shared and the other members' items are always visible. This is the single rule behind every number, so both phones agree.
- **Joint net worth** = shared + every member's visible items. **Mine** = everything I own (Private included) + my equal share of shared items (largest-remainder split, no fils lost). Reuses `computeNetWorth`; currencies without a rate are reported, not summed.
- **By-member spending**: debits in the month, not excluded, AED, grouped by owner (a member, or Shared), biggest first.
- **Shared budget**: joint limits per category (`household_limits`) against all visible spending in that category in the month.
- **Bills**: `household_bills` with a split in basis points; `splitMinor` gives exact shares; next due date clamps to short months.

## Sharing protocol

A **household log** is a second instance of the sync engine:

| | Personal sync | Household log |
| --- | --- | --- |
| Object names | `sync/<device>/<seq>.seg` | `household/<household id>/<device>/<seq>.seg` |
| Key | HKDF(`sync.segments`) of the backup data key | HKDF(`household.segments`) of a random 32-byte **household key** |
| AAD | object name | object name (the namespace is part of it) |
| Participants | one user's phones | the members' phones |

`SegmentCodec` and `SyncEngine` gained a `namespace` and a key `purpose`; the defaults keep personal sync byte-for-byte unchanged. A household segment can never be opened with the personal key or the other way round (tested).

**What goes in the log** (allow-list in `household_scope.dart`):

| Table | Written by | Columns |
| --- | --- | --- |
| `transactions` | each member, about their own and shared items; this month and the previous one only | category, amount, currency, direction, merchant (clean), date, excluded, owner |
| `lines` (net worth) | same | name, liability, value, currency, owner |
| `goals` | same | name, kind, icon, target, current, progress, date, paused, owner |
| `members`, `bills`, `limits` | any member (these are the household's, edited by anyone) | name / amount, due day, split, category / limit |

Never in the log: notes, tags, raw merchant text, account ids, statement lines, card numbers, anything not listed, and **anything marked Private**. The gate (`exportRow`) is pure and runs on every row on its way out; unit tests and the two-member simulation assert that private rows never appear in the encrypted log (decrypted with the household key) nor in the other phone's data, and that the server only holds ciphertext. If an item becomes Private or stops being shared, it disappears from the snapshot, the engine records a tombstone, and the other phones delete their copy. Making it visible again re-creates it.

**Personal rows are mirrored, not merged.** The other members' transactions, lines and goals arrive in a read-only `household_mirror` table, never in your own ledger. They cannot double count, cannot be edited by mistake, never enter your personal sync log, and are wiped on leaving. Shared tables (`members`, `bills`, `limits`) are real local tables merged per field (last writer wins), so either member can edit a bill.

**Invite**: `PULSE-HH1-XXXXX-...` = base32 of version, 16-byte household id, 32-byte key and a 4-byte checksum (a typo is caught before anything is created). It is shown as text and a QR on the inviting phone only; it does not pass through any server. The joining phone reads the QR in the app (`mobile_scanner`; camera permission is asked only on tapping Scan QR code, nothing is stored or uploaded, and anything that is not an intact invite is ignored) or takes the pasted text; the paste field always works, also when the camera is denied or unavailable. Anyone holding the code can read the household log, so the UI says to pass it in person or over a trusted channel. The key is kept in the keystore (iOS Keychain this-device-only, Android Keystore), never in the database or in backups.

**Joining**: the new phone stores the key, creates its member row, and its first sync reads the log before comparing its own data (the engine's bootstrap), so it adopts the household's members, bills and limits first; then its own shareable rows go out.

**Removing a member and re-keying**: any member can remove another (Members > Remove), or change the code without removing anyone (Household > Change household code, for after someone left or a code leaked). The remover's phone:

1. marks the removed member's row `removed_by` in the *old* log and syncs once (best effort, offline is fine), so the others learn who is changing the code;
2. creates a **new household id and a new random key**, deletes the removed member locally, gives their items assigned to them back to "mine", wipes the mirror and the old log state, and starts a log under the new id;
3. shows the new invite code (text and QR) to hand to the remaining members in person or over a channel they trust.

A remaining member's phone shows "<name> changed the household code" and **Enter the new code** (scan or paste). Adopting keeps their member id, name, bills and everything of theirs, deletes removed members' rows, switches to the new id and key, rebuilds the mirror from the new log and syncs. Their private items stay off the new log exactly as before (the gate runs on every row). The new code never goes through the old log (the removed member could read it). The removed member's key opens only the old log, and nobody reads or writes it any more: a tested guarantee that nothing written after the re-key can be decrypted with the old key or purpose. If the removed phone does sync the old log it sees it was removed, stops pushing and offers Leave (it keeps everything of its own).

**Leaving**: the phone removes its member row, runs a last sync offering none of its own rows (so every row it wrote is tombstoned and the others' mirrors drop them), then forgets the household, the key and the log state, and puts every `owner` back to `me` (Private flags are kept). Everything of the user's stays on the phone.

## Transport

`SyncTransport` is reused unchanged.

| Transport | Status |
| --- | --- |
| `MemorySyncTransport` (shared "server") | Implemented; used by the two-member simulation. |
| `SupabaseHouseholdTransport` (`pulse-households` bucket, `<household id>/household/<household id>/<device>/<seq>.seg`) | **Compiled but NOT tested against a real Supabase project.** |

Members are different Supabase users, so the per-user policies of `docs/BACKUP.md` do not apply. Proposed policy (also untested): the random household id is the capability, and the objects are ciphertext.

```sql
insert into storage.buckets (id, name, public, file_size_limit)
values ('pulse-households', 'pulse-households', false, 5242880)
on conflict (id) do nothing;

create policy "household read"   on storage.objects for select to authenticated
  using (bucket_id = 'pulse-households');
create policy "household insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'pulse-households' and (storage.foldername(name))[1] ~ '^[0-9a-f]{32}$');
create policy "household update" on storage.objects for update to authenticated
  using (bucket_id = 'pulse-households') with check (bucket_id = 'pulse-households');
```

This lets any signed-in user list and read any household's ciphertext if they can guess a 128-bit id and path (they cannot decrypt it). Tighten it (for example a `households` table the server checks membership against) before relying on it; that needs server-visible membership, which the E2E design avoids on purpose.

## Schema v6 and sync

- `drift_schemas/drift_schema_v6.json`; `from5To6` adds the ten columns and five tables. Additive: existing rows are `me`, not private.
- v12 (`from11To12`): `owner` and `is_private` on `jewellery_items` and `fund_holdings` (existing rows set Private), and `household_members.removed_by`. Additive; `migration_v12_test.dart`. The `removed_by` column is allow-listed for the log like the other member columns.
- The ownership columns are on already allow-listed tables, so they sync to the user's own devices (a Private flag set on one phone applies on the other).
- New tables `household_configs`, `household_members`, `household_bills`, `household_limits`, `household_mirror` are **not** on the personal sync allow-list (the log is its own channel and its key lives on one phone). Tests: `migration_v6_test.dart`, `sync/drift_test.dart` (columns sync, household tables never do, a shared and a private transaction arrive marked).

## Analytics

Only through the schema gate: `household_created`, `household_member_joined`. No properties: no names, amounts, member counts or ids. Route `/household` added to the screen allow-list.

## Threat model

Protects against: the server, a storage leak and network observers (ciphertext only; tampered, truncated, renamed or re-keyed segments fail GCM and stop the sync as "integrity"); a member reading what the other marked Private (it never leaves their phone); accidental double counting. The server sees that a household exists, how many devices write, and segment counts, sizes and times.

Does not protect against: someone who has the invite code or the key; a member who keeps what they already saw after you leave or mark an item Private (withdrawal deletes their synced copy but cannot un-see it); a compromised phone; malware. A member's device can write anything into the shared tables (bills, limits, member names).

## Limits and what is left

- **Re-keying is manual and in person.** Removing someone or changing the code needs every remaining member to enter the new code; until they do, they keep writing to the old log (which the removed member can still read) and see a notice. Two members re-keying at the same time produce two competing households (agree on one, the other adopts its code). A removed member keeps everything they already saw and any copy of the old code. Leaving does not re-key by itself: someone must tap Change household code afterwards. Not tested with real phones or a real server.
- **One household per phone, one phone per member.** A second phone of the same person would be a second member; it would need its own invite. The key is not in backups, so a restored phone shows "needs a new invite".
- **The in-app QR scanner is unverified on devices.** `mobile_scanner` 7.5 (Android: CameraX plus the bundled ML Kit barcode model, which adds a few MB; iOS: Apple Vision) with the CAMERA permission and `NSCameraUsageDescription` already in the app for photos. The plugin ships its own R8 keep rules, but no Android release build (R8) or iOS build was run where this was written: build both once before relying on it. The scanner has no automated test (no camera in CI); only the code check is unit tested.
- **Real network unverified**: Supabase transport and policy, background sync (runs on local writes with a debounce and on resume only), two real phones.
- **Shared accounts**: if both members add the same joint account and mark it Shared, it is counted twice. No de-duplication.
- **Net worth lines are snapshots** of values computed on the owner's phone (balances, valuations, FX are AED only); no joint history chart. Stocks and ETFs cannot be shared yet. Non-AED amounts are left out of spending totals.
- **Window**: only this and the previous month of transactions are shared.
- **No per-member visibility levels** beyond "share my items" on/off and the per-item Private flag; bills have no "paid" state or reminders; no shared monthly check-in; goals show progress only (no joint contributions or pace).
- **The household log is never compacted** (same as personal sync).
- **Settings screen**: the existing server-backed "Family" screen is untouched and still a mock; this feature does not depend on it.
