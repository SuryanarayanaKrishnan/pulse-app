# Indian mutual funds: live NAVs and importing holdings

Status: implemented on the phone (PR "live prices" and PR "CAS import"). Free public sources only: no paid API, plan or signup is used or needed.

## The honest answer on "extract holdings using PAN"

**There is no free API that returns a person's mutual fund holdings from a PAN alone, and Pulse does not pretend to have one.**
A PAN is an identifier, not a credential. Holdings are held by the registrars (CAMS, KFintech) and depositories (NSDL, CDSL), who release them only with the investor's own authorisation: a statement emailed to the address on record, or an OTP-consented data share. Any service that appears to do "PAN only" is either (a) driving that same email/OTP flow for you or (b) a licensed participant in a regulated data-sharing scheme. We are neither.

The site Surya mentioned (an Indian aggregator that shows all holdings) is almost certainly in category (b): it holds a licence and a registrar/Account Aggregator integration. See "Programmatic routes we cannot use" below. It cannot be integrated by us.

## What is free and allowed

| Need | Source | How we use it |
|---|---|---|
| NAV of every Indian fund | AMFI public file `https://portal.amfiindia.com/spages/NAVAll.txt` (also `NAVOpen.txt`, and a NAV history form limited to 90 days per request) | The phone downloads it directly, caches it (6 h), parses it, and shows the NAV with its date. No account or key. AMFI's page lists the files; its Terms of Use are at `amfiindia.com/terms-of-use`: confirm before release (see Unverified). |
| What you hold, per fund | CAS (consolidated account statement) from CAMS or KFintech, free, emailed as a password-protected PDF | The investor requests it on the registrar's own site (PAN + email typed there, never in Pulse), then opens the PDF in Pulse. Parsed on the phone. |
| Demat holdings (stocks) | NSDL / CDSL e-CAS, free, PDF; password is normally the PAN in capitals | Detected, not parsed yet: Pulse says "this is a demat statement". Possible follow-up using the same on-device pipeline. |
| US stock closes | Stooq daily CSV | Last close only, labelled delayed. |
| Gold | Existing Pulse price snapshot (`/v1/prices/snapshot`) or the bundled demo value | Unchanged. No free, terms-clean on-device gold feed was found. |

### Requesting the CAS (what the guide screen tells the user)
1. Open the CAMS or KFintech statement page (links in the app; AMFI's own "Download CAS" page links to both: `https://www.camsonline.com/Investors/Statements/Consolidated-Account-Statement`, `https://mfs.kfintech.com/investor/General/ConsolidatedAccountStatement`). Either one returns funds from both registrars.
2. Enter PAN and the email registered with the funds. Choose **Detailed**, period from the start (e.g. 1990 to today), include zero-balance folios, and set a password for the PDF.
3. The registrar emails the PDF to the address on record (so someone who only knows your PAN gets nothing).
4. Save the PDF, choose it in Pulse, type the password.

Password: on the CAMS/KFintech request form the investor sets it, so Pulse asks for "the password you set". Some guides suggest PAN in capitals, and NSDL/CDSL statements use the PAN; the password prompt mentions that but never pre-fills or stores anything.

### Programmatic routes we cannot use
- **MF Central (mfcentral.com)**, run by CAMS and KFintech: lets an investor log in and download the same CAS. Its API for apps is OTP-consent based and for registered partners; in September 2025 the press reported AMFI asking MF Central to stop sharing investor data directly with fintech apps, pointing them to investor-downloaded statements, or to the Account Aggregator route for licensed PMS/RIA firms (Business Standard, 18 Sep 2025, based on unnamed sources). Treat the status as in flux; either way it needs a commercial arrangement.
- **RBI Account Aggregator**: data flows only between a Financial Information Provider and a registered **Financial Information User (FIU)**, with the customer's consent through an AA app. Becoming an FIU requires registration with a regulator (RBI/SEBI/IRDAI/PFRDA) and onboarding with an AA. Not available to Pulse.

## Privacy and legal rules the code follows
- **PAN is sensitive personal data.** The statement is processed **on the device only**: text extraction (pdfrx), parsing and matching all run locally. Nothing from the statement (PDF, text, PAN, email, name, address, holdings) is sent to any server, including the Pulse backend, analytics or crash reports.
- **The parser never reads the PAN, email, name or address** into its result (tested). Folio numbers and units are the only identifiers kept in memory during review.
- **The PDF password is held in a text field and in memory for one call.** It is not stored, logged or put in a URL. Pulse does not store the PAN at all. If a PAN-saving option is ever added it must be an explicit opt-in, in the encrypted store, with a delete button.
- **Only holdings are saved**: scheme (AMFI code), units, average cost, NAV and date, and an optional SIP amount/day. Transactions and the PDF are discarded after the preview.
- The only network calls are public GETs (AMFI file, Stooq CSV) that carry nothing about the user, through a separate HTTP client with no auth header.
- Respect terms of use: one AMFI download per 6 hours at most (caching), no scraping of registrar pages, no automation of the CAMS/KFintech forms (the user submits them in their own browser).
- The pre-existing backend endpoint `POST /v1/funds/cas/import` uploads the PDF and its PAN-based password to the server. The app does **not** call it. Recommendation for the pulse-api owners: remove it, or at least document it as legacy, because it contradicts the on-device rule. No backend change is required for this feature.

## Recommended flow (as built)
1. Wealth > Add > Mutual fund > "Import a CAMS or KFintech statement" opens **Get your statement** (steps + deep links).
2. "I have the PDF" opens the file picker. A locked PDF triggers the **password sheet** (wrong password shows an inline error and can be retried).
3. The statement is parsed: folios, schemes, units, cost, NAV, transactions.
4. Each scheme is matched to an AMFI scheme by **ISIN (exact)**, else by name with a strict rule (every identifying word must be in the AMFI name; otherwise it is left unmatched rather than guessed). Same scheme in several folios is combined. Funds with zero units are skipped.
5. **Preview** shows each fund with units, NAV, value, whether it updates an existing holding, and amber flags for anything approximate: units that do not reconcile with the statement period, no cost on the statement, name-only match, unmatched fund (saved by hand, no live NAV), SIP inferred from a pattern.
6. SIP hints: a SIP is proposed when the statement labels instalments as SIP (2+ in a row about a month apart) or when 3+ equal purchases follow a monthly pattern, and the last one is within 45 days of the statement end. Labelled hints default on, pattern hints default off. The user can toggle each.
7. **Confirm** saves holdings (an existing holding of the same scheme is updated, not duplicated). NAVs then refresh daily from AMFI.

## Unverified (could not be checked from the build sandbox)
- I could not open amfiindia.com, stooq.com or the CAMS/KFintech pages from the sandbox (egress proxy). The AMFI file layout and URL come from AMFI's published NAV page and the long-standing `NAVAll.txt` format; the parser is tested on a synthetic file in that layout. Run once on a real device and compare a couple of NAVs.
- The CAS parser is built to the documented CAMS "detailed" text layout and tested on **synthetic** fixtures only (no real statements were used). Real PDFs can differ (wrapped lines, KFintech variations, other AMCs' section headings). Unrecognised lines are skipped with a warning and the preview shows what was read, so errors are visible rather than silent. Please try it with your own statement and send a redacted text dump of anything it misses.
- pdfrx text extraction of an encrypted PDF is reused from the existing bank-statement importer; it is not exercised against a real CAMS file in tests (a fake extractor is used).
- Stooq has been restricting some CSV downloads; if the daily CSV needs a key, US stocks keep their last price.
- AMFI/Stooq/registrar terms of use should be read by a human before release.
- NSDL/CDSL password rule (PAN in capitals) is from public guides, not tested.
