# Family vault (nominees and legacy)

A calm, on-device record of where a family would need to look if something happened to the owner: accounts, cards, loans, insurance, investments, property, crypto, subscriptions, digital accounts, where documents are kept, and a will / Emirates ID / passport note. Free: no new paid service, no new package (`cryptography` and `crypto` were already used by backup).

**This is an information aid, not a will and not legal advice.** See "Legal caveats".

## What the user sees

Settings > **Family vault** (also under Family > Planning ahead). No new tab.

- A gentle score: "Your family could find 7 of ~12 typical things." About 12 is the typical household (2 bank accounts, 1 card, 1 loan, 2 insurance, 1 investment, 1 property, 1 subscription, 1 digital, 1 documents, 1 identity; crypto only if you have it). What Pulse already tracks can raise a type's expectation by at most two.
- **Add these N items to your vault**: suggestions from bank accounts, cards, assets and liabilities, funds, confirmed recurring payments (subscriptions, insurance, loans by merchant name) and pay-down goals. Only names are copied (and a rough value for non-loans), never account numbers. Nothing is added until confirmed; an item already in the vault (same source, or same type and name) is not suggested again.
- Entries: type, institution, title, where to find it (free text), nominee named on the account itself, contact person, rough value in AED, optional photos of the papers (the same private attachments storage as Wealth documents).
- **People you trust**: name, relationship, contact, and what they may see (everything, or chosen entries). **Preview what Sara would see** shows exactly the sheet they would get.
- **Share emergency sheet**: a plain-text/markdown list through the share sheet. Photos are never included (the sealed file is the only way papers travel).
- **Release window** (60 / 90 / 180 days / 1 year) and a quiet in-app note when the window is close. Opening Pulse is the check-in.

## No secrets, by design (`lib/core/vault/input_guard.dart`)

The vault stores where things are, never the secret. Every free-text field (entries and people) is checked on screen as you type and again in `VaultService` before saving. Blocked: card numbers (13 to 19 digits passing Luhn, or four groups of four), full IBANs (valid mod 97 or UAE-shaped `AE` + 21 digits), "password: ...", passcodes, PIN/CVV/CVC/OTP followed by digits, and 12-word recovery phrases. Warned only: an Emirates ID number. Saying where a secret is kept ("password is in 1Password", "PIN known only to my husband") is allowed. It is a safety net, not a guarantee: a disguised secret can get through, and the screen says what not to write. Because secrets are not meant to exist here, entries and people sync like other ledger data.

## Storage and sync

Schema v10 adds `vault_entries` and `vault_nominees` (additive; nothing existing changes). Both are on the sync allow-list (`sync_scope.dart`); `vault_entries.photo_paths` is device-local like other file paths. Both tables are included in encrypted backups (every table is).

Per-device settings live in `app_settings`, which never syncs: check-in time, interval, owner name on the sheet, and the **owner's key share** (`vault.share1.<nominee id>`). Release secrets and the other shares are never stored: they are shown once when the file is sealed.

## Inactivity release (design)

Per trusted person the owner can seal an emergency file:

1. A random 128-bit **release secret** is generated for that person and split with **Shamir 2-of-3** over GF(256), implemented in pure Dart (`shamir.dart`): share 1 stays on the owner's phone (and so in her encrypted backup), share 2 goes to the nominee, share 3 is **escrow**, handed to someone else you trust (for example a spouse through the household channel, or kept with the backup). Shares print as `PVS1-2-02-....-CRC` so typing mistakes are caught.
2. The entries that person may see are encrypted with AES-256-GCM under a key from HKDF-SHA256 of the secret, a random salt, and associated data binding the file to that person. The file contains no plaintext names or values.
3. Any two shares open it; one share, the same share twice, a share from another file or a wrong share fail (the last by authentication, since Shamir itself cannot detect a wrong share). So no single party can open it: not the nominee, not the escrow holder, not the server holding the file. The owner can always open her own file with share 1 plus the escrow share.
4. A **claim code** (random, only its hash is given to a server) is handed to the nominee in advance. Once the owner has not opened the app for the interval, the nominee can present the code to a relay, receive the sealed file, and combine their share with the escrow share.

Making a new file creates a fresh secret and new codes; older codes stop opening the new file. Removing a person clears the owner share and disarms the relay.

### What is NOT built: the server half

Noticing that the owner has gone quiet, sending her reminders before it triggers, and handing the file over need a server or push/notification component. **None exists.** `InactivityRelay` (in `release.dart`) is the interface (arm, heartbeat, set interval, disarm, claim); `InMemoryInactivityRelay` is a faithful fake used by the simulation tests (heartbeat resets the countdown, early or wrongly-coded claims are refused, repeated wrong codes lock); the app ships `UnavailableInactivityRelay`, so the UI says plainly that automatic release is not switched on and that the owner hands the file and codes over herself. A real relay must: store only ciphertext and the claim-code hash, rate-limit claims, notify the owner (push/email) before and when a claim is made, and let the owner cancel. The reminders in the app today are in-app notes only; no local notification is scheduled.

## What is and is not protected

Protected: entries stay on the phone and in encrypted backup/sync (see BACKUP.md and SYNC.md); the sealed file and the relay learn nothing without two shares; the sheet and the sealed file only contain what a person is allowed to see; analytics carry only `vault_entry_added{type}` and `vault_exported{kind}` through the schema gate (never names, places, values or contacts).

Not protected:
- **Anyone with the unlocked phone** sees the vault. Photos sit in the app's private storage (OS-level file protection, and encrypted in backups); they are not separately encrypted inside the app.
- **The plain-text emergency sheet is plain text.** Whoever receives it can read it and forward it. Use the sealed file for anything you do not want read by whoever finds it.
- A **disguised secret** can pass the input guard.
- Two colluding share holders (nominee plus escrow) can open the file early, whenever they like, if they also have the file. The claim code and the relay only gate *who gets the file*, not who can open it once they have it.
- Shares or the claim code written down insecurely, a lost escrow share plus a lost owner share (the file becomes unopenable), a phone lost without backup.
- Papers (photos and PDFs) on entries a nominee may see are sealed inside the file too, up to 12 MB in total; any that do not fit are left out and the owner is told how many. They are decrypted only in the nominee's app (Family vault > Open a file someone left me), with the same two-of-three key codes. Nothing is stored on the nominee's phone or on a server. Older files without papers still open.
- Metadata: a relay would see that a file exists, its size, and claim times.

## Legal caveats

The vault helps a family *find* things. It does not transfer anything, appoint anyone, or say who inherits. A bank or insurer nominee is a contractual instruction that can differ from the heirs under succession law. In the UAE, succession for Muslims follows Sharia rules and for non-Muslims may follow the law of their nationality or a registered will (for example a DIFC or Abu Dhabi courts will); a nominee on an account is often treated as a custodian for the heirs, not the owner. Banks usually need a court order or certificate before releasing funds, whatever this app shows. Talk to a lawyer about a will and about what your nominations actually do. Handing someone your account details has its own risks and may be limited by your bank's terms.

## Tests

`test/vault/`: Shamir (field arithmetic, all subsets, thresholds, wrong and duplicate shares, text form), input guard, suggestions, completeness, sheet, seal and open round trips and tamper cases, the relay simulation with a clock, widget tests; `test/local/migration_v10_test.dart`; the vault sync test in `test/sync/drift_test.dart`.

## Limits

Not verified on a real device or with a real relay; no local notification for reminders; no per-entry encryption on the phone beyond the database key; each new emergency file means new codes; the sheet is unlocalised English.


## Automatic release (wired in the app, relay on the backend)

With `API_BASE_URL` set the app uses `HttpInactivityRelay` against the backend's `/v1/vault/relay` (see the backend repo): sealing a file arms the relay with the ciphertext and a hash of the claim code; every app open sends a heartbeat. A nominee with no account taps Family vault > Open a file someone left me > "Ask Pulse for the file" and types the release code. After the owner's silence interval a claim starts a 3 day waiting period (the owner can stop it by opening the app); after that the file is handed over and the nominee still needs two key codes to read it. Without `API_BASE_URL`, or if the server cannot be reached while sealing, the owner is told automatic release is off and hands the file over herself.

Owner warnings today are **local notifications** on the owner's phone (14 days before and the day before the release date, moved out by every app open). They cannot tell the owner that a nominee has *claimed*; that needs push from the server. Later step: Firebase Cloud Messaging (free) behind `PushSender` in the backend, with a device-token table. Not set up.

Not verified on a real device or against a deployed server.
