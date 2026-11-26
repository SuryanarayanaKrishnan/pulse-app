# iPhone capture: shortcut links and what iOS forbids

Pulse has four capture paths on iPhone. All four are required parts of setup
(the user may "Skip for now" and is reminded on Home):

| Path | Trigger | Runs |
| --- | --- | --- |
| Apple Pay / Wallet | Wallet automation | Pulse Wallet Payment |
| Bank SMS | Message automation | Pulse Bank SMS |
| Screenshot and Back Tap | Back Tap, Action Button, share sheet | Capture to Pulse |
| Ask after shopping apps | App automation, "Is Closed" | Pulse Ask then Capture |

The actions themselves (Record Payment, Record Bank SMS, Capture to Pulse, Ask
then Capture) ship inside the app as App Intents
(`ios/Runner/ShortcutCapture.swift`) and appear in Shortcuts, Spotlight, Siri
and the Action Button picker with no setup. What users cannot get without
building it is the multi-action wrapper shortcuts below. iOS imports only
**signed** shortcuts from an iCloud share link, and we cannot sign without a
Mac or iPhone, so each wrapper is built once on a real iPhone and its link is
pasted into the build config.

## Build each shortcut once (surya, on an iPhone with Pulse installed)

For each shortcut: open Shortcuts, tap +, add the actions listed, name it
**exactly** as shown (the app runs and lists it by name), then tap the shortcut's
(i) / share, **Share > Copy iCloud Link**. Paste the link into the dart-define
shown, for example
`--dart-define=SHORTCUT_LINK_WALLET=https://www.icloud.com/shortcuts/abc123`
(CI secrets or `tool/` scripts, wherever other dart-defines live). Only links of
the form `https://www.icloud.com/shortcuts/<id>` are accepted; anything else is
treated as "not set" and the app falls back to hand-built steps.

Open each shortcut's (i) details and turn **off** "Show in Share Sheet" unless
stated, and leave "Pin in menu bar" off.

### 1. `Pulse Wallet Payment`  (`SHORTCUT_LINK_WALLET`)
Details: leave the accepted input type as Any.
Actions:
1. **Get Details of** `Shortcut Input`, detail **Amount**.
2. **Get Details of** `Shortcut Input`, detail **Merchant** (Name).
3. **Get Details of** `Shortcut Input`, detail **Card or Pass**.
4. **Record Payment** (Pulse): Amount = result of step 1, Merchant = result of
   step 2, Card = result of step 3.

VERIFY on device: when run from a Wallet automation, the exact detail names in
step 1-3 depend on what iOS offers for a Wallet transaction. If "Get Details"
does not list them, use the Wallet automation's own variables inside this
shortcut by instead building the Wallet automation with Record Payment directly
(the app shows that fallback when the link is empty) and tell us.

### 2. `Pulse Bank SMS`  (`SHORTCUT_LINK_BANK_SMS`)
Actions:
1. **Record Bank SMS** (Pulse): Message = `Shortcut Input`. Leave Sender empty.

(The action also works with no wrapper: it takes the previous action's output,
or the Message automation's Shortcut Input, automatically. The wrapper exists so
the guided flow is one "Run Shortcut" pick.)

### 3. `Capture to Pulse`  (`SHORTCUT_LINK_CAPTURE`)
Details: turn on **Show in Share Sheet**, accept Images.
Actions:
1. **Take Screenshot**
2. **Capture to Pulse** (Pulse), Screenshot = Screenshot.

Keep it to these two actions and test Back Tap. (Sending an image from the
share sheet works with the Pulse action alone, which takes the image directly.)

### 4. `Pulse Ask then Capture`  (`SHORTCUT_LINK_ASK_CAPTURE`)
Actions:
1. **Get Latest Screenshots**, Count 1.
2. **Ask then Capture** (Pulse), Screenshot = Latest Screenshots. (The action
   asks "Log that order?" itself; no Show Alert action is needed.)

After building all four, run each once from Shortcuts to be sure it saves without
prompting for extra input, then copy the links.

## Test each path on a device before release
- Wallet: set up the automation per the in-app steps, pay with a card, confirm
  the setup screen shows "It works".
- Bank SMS: text `Purchase of AED 12.00 at TEST using card ending 0000` (the
  in-app Bank SMS guide shows it). Within 30 seconds it should show "It works".
- Screenshot: Back Tap with a receipt on screen.
- Ask then capture: close a ticked shopping app with a fresh order screenshot.

## Real URL schemes the app uses
Only schemes Apple documents for Shortcuts:
- `shortcuts://` opens the Shortcuts app.
- `shortcuts://create-shortcut` opens a new shortcut editor.
- `shortcuts://run-shortcut?name=<name>` runs a shortcut by name (used by "Run
  it now" on the screenshot path).
- `https://www.icloud.com/shortcuts/<id>` opens the iOS "Add Shortcut" sheet.

There is **no** scheme for the Automation tab, for creating an automation, for
Back Tap or for Accessibility settings. We do not use `App-Prefs:` (private API,
App Store rejects it).

## What iOS strictly forbids automating
UI copy must never promise otherwise.
- An app cannot create a personal automation (Wallet, Message, App closed). The
  user taps Automation, +, the trigger, and Next themselves.
- An app cannot switch an automation from "Run After Confirmation" to "Run
  Immediately", nor turn off "Notify When Run". The user must do it per
  automation.
- An unsigned or hand-made `.shortcut` file cannot be imported. Only signed
  files or iCloud share links work, hence the one-time build above.
- Back Tap is bound only in Settings > Accessibility > Touch > Back Tap. Apps
  cannot set it or deep link to it. The Action Button likewise.
- An App Intent cannot take a screenshot. "Capture to Pulse" needs Take
  Screenshot (or an image from the share sheet or Get Latest Screenshots) before
  it.
- An app cannot read SMS or Wallet data itself on iOS; capture works only when a
  Shortcuts automation hands the text or transaction to the app.
- A Message automation may not fire for texts you send to yourself; the test
  hint says to have someone else send it if it fails.
