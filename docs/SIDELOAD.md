# Run Pulse on your iPhone for free

Two free routes. If you can borrow a Mac, use route A (simplest). Otherwise use route B from Windows.

## Route A: with a friend's Mac (no GitHub build needed)
One-time setup on the Mac, about an hour mostly waiting on downloads:
1. Install **Xcode** from the Mac App Store, open it once and accept the licence and extra components.
2. Install Flutter (flutter.dev/install/macos), then run `flutter doctor` and fix what it flags (CocoaPods etc.).
3. Xcode > Settings > Accounts > **+** > sign in with your free Apple ID (a spare one is wise).
4. Clone the repo, run `flutter pub get`, then `open ios/Runner.xcworkspace`. In Runner > Signing & Capabilities tick *Automatically manage signing*, choose your Apple ID as Team, and change the Bundle Identifier to something unique like `com.yourname.pulse`.
5. Plug in the iPhone, tap **Trust**. On the iPhone enable Settings > Privacy & Security > **Developer Mode** (appears once Xcode sees the phone), restart.
6. Run `flutter run --release -d <your iPhone>` (see `flutter devices`). Then on the phone: Settings > General > **VPN & Device Management** > trust your Apple ID.

Same free-account limits apply: the app expires after **7 days** (run step 6 again with the phone plugged in to refresh; your data stays) and you can have 3 sideloaded apps. Always use `--release`; debug builds stop working when the cable is unplugged.

## Route B: from Windows (fallback)

No Apple Developer Program ($99/yr) needed. You build an unsigned app on GitHub, then sign it yourself with a free Apple ID using Sideloadly.

## 1. Get the .ipa
GitHub repo > Actions > **iOS unsigned IPA (free sideload)** > Run workflow. After about 10-15 minutes open the run and download the **Pulse-unsigned-ipa** artifact (a zip containing `Pulse-unsigned.ipa`). Unzip it.

Cost: macOS runner minutes count 10x, and a private repo on the free plan gets 2,000 minutes a month, so about 200 macOS minutes: roughly 10-15 builds. The job is manual-only, so it never runs by itself.

## 2. One-time Windows setup
1. Install **iTunes** and **iCloud** from apple.com (the direct downloads, not the Microsoft Store versions; Sideloadly needs them for the USB driver).
2. Install **Sideloadly** from sideloadly.io (AltStore also works, but Sideloadly is simpler for one app).
3. Use a free Apple ID. A spare one is wise, because you type its password into Sideloadly.

## 3. Install
1. Plug in the iPhone, tap **Trust this computer**.
2. Open Sideloadly, drag in `Pulse-unsigned.ipa`, enter the Apple ID, click **Start**.
3. On the iPhone: Settings > Privacy & Security > **Developer Mode** > on, then restart. (The switch only appears after the first sideload attempt.)
4. Settings > General > **VPN & Device Management** > tap your Apple ID > **Trust**.
5. Open Pulse.

## Limits of the free route
- The signature **expires every 7 days**. Reopen Sideloadly and click Start again with the phone plugged in (same Apple ID) to refresh. Keep your data: re-signing the same app does not wipe it. Don't delete the app.
- Free Apple IDs can have **3 sideloaded apps** at once and create about 10 new app IDs a week.
- **Friends** can't use your signing. Each friend must sideload the .ipa themselves with their own Apple ID and computer. This is fine for one or two people, poor for a wider beta.
- No push notifications or other special entitlements.

## When to pay
TestFlight ($99/yr) removes the 7-day expiry and lets friends install from a link. See `docs/TESTFLIGHT.md` and the TestFlight workflow, which stays ready for later.
