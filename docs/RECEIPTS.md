# Email receipts (noon, Talabat, Careem)

Status: engine, matcher, storage and settings row are built. **Gmail access is
NOT configured**, so the Settings > Connected sources > Email receipts row is
off and disabled.

## What it does

Receipt emails are parsed on the phone (`lib/core/engine/receipts/`). A parsed
receipt is linked to a card charge that already exists, and enriches it:
item-level notes, fee and promo lines, a better category (groceries vs dining,
from line items) and a link to the email (its message id). The bank amount,
date and merchant are never changed. A receipt never creates spend: with no
matching charge it is held for 5 days (`holdDays`) and then offered for review.

Matching (`receipt_matcher.dart`): same card last 4 when both sides know it;
amount equals the total, or the total less a discount line, within AED 1 or
0.5%, or up to 15% above it (tip, VAT); date within 3 days; merchant similar;
debit only; a charge that already has a receipt is skipped. Two equally good
charges are ambiguous: nothing is linked and the user picks. Emails with no
amount (noon "order accepted") match on merchant and same-day time only and
never get an invented total. The "ENBD noon One Visa Card AED x" line in noon
emails is cashback, not a charge, and is kept separately.

## Privacy

* Raw email bodies are parsed and dropped: never stored, never synced.
* Stored: `transactions.receipt_ref` (message id) and `receipt_notes`
  (extracted text), schema v9, both synced like other transaction columns;
  held receipts as extracted fields in `app_settings` (device-local).
* Analytics: only `receipt_matched` with `merchant` in noon, talabat, careem,
  other (`event_schema.dart`). No order ids, items, venues or amounts.
* No paid services; nothing leaves the phone except the read-only Gmail
  request itself.

## Gmail: what the owner must do

`GmailReceiptSource` (`receipt_source.dart`) is a stub. To make it real:

1. Create a Google Cloud project and an OAuth client (Android and iOS) with
   only the scope `https://www.googleapis.com/auth/gmail.readonly`.
2. The app stays in Google's **testing** mode: only listed test users (max 100)
   can sign in, and refresh tokens expire after 7 days. Public use needs
   Google's restricted-scope verification and a security assessment, which is
   not planned.
3. Pass the client id at build time (`--dart-define=GMAIL_OAUTH_CLIENT_ID=...`).
   Never commit it with a secret; tokens must go in the platform keystore, not
   in code or the database.
4. Implement sign-in and `fetch` (list with `gmailReceiptQuery`, get each
   message, build `ReceiptMessage`) and set `isConfigured`; then call
   `ReceiptService.scan()` (not scheduled yet) and build a review screen for
   `dueForReview()`.

Search query (narrow on purpose; nothing else in the mailbox is read):

    (from:noon.com OR from:talabat.com OR from:careem.com)
    (subject:order OR subject:receipt OR subject:shipment OR subject:invoice)
    after:YYYY/MM/DD -category:promotions

## Fixtures and what is verified

* `test/fixtures/receipts/noon/`: five anonymised plain-text renderings of real
  noon emails (food order accepted x2, order confirmed, supermall order
  confirmed, shipment delivered). The noon parser is written against these.
  Other noon layouts (returns, partial shipments, HTML structure) are unseen.
* `test/fixtures/receipts/synthetic/`: INVENTED Talabat and Careem emails that
  imitate typical receipt structure. **No real Talabat or Careem receipt was
  available; those layouts are unverified** and their results carry
  `verified: false`.

## Merchant offers

`assets/merchant_offers.json` (version 1) holds INVENTED example offers (card x
merchant cashback). `merchantCardHint` (`merchant_offers.dart`) reuses
`checkCard` from the card value engine to say "right/wrong card for noon". All
output is labelled estimate, unverified. It is not yet shown in the UI.
