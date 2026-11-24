# Install Pulse for free (Android and iPhone)

Everything here costs nothing: GitHub Actions free minutes, a free Apple ID, no developer accounts. The backend (when you use one) is Oracle Always Free plus Supabase free; nothing in these builds needs it.

## Android (APK)
Every push and pull request runs `CI` (`.github/workflows/ci.yml`) on Linux: `flutter analyze`, `flutter test` (includes the device-free smoke test in `test/smoke/`) and an APK build.
1. GitHub repo > Actions > **CI** > pick the latest green run > download the **Pulse-android-apk** artifact (zip) and unzip it.
2. Copy `app-release.apk` to the phone (USB, Drive, email to yourself), open it, and allow *Install unknown apps* for the app you opened it from.
3. Open Pulse. SMS and notification capture ask for their permissions in the Connect step.

Signing: `android/app/build.gradle.kts` signs the release build with the **debug keystore**, so the APK installs directly with no secrets in the repo. Updates install over the top only while every APK came from a debug keystore of the same machine: the CI runner makes a new one each run, so installing a later CI build over an earlier one fails with a signature conflict. Uninstall first (this deletes the app data, so use *Backup* first), or build once on your own PC with `flutter build apk --release`, which reuses your stable `~/.android/debug.keystore`. A real release keystore is only needed for Google Play.

Two free iPhone routes. If you can borrow a Mac, use route A (simplest). Otherwise use route B from Windows.

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
GitHub repo > Actions > **iOS unsigned IPA (free sideload)** > Run workflow (branch `main`). After about 10-15 minutes open the run and download the **Pulse-unsigned-ipa** artifact (a zip containing `Pulse-unsigned.ipa`). Unzip it. Artifacts are kept 14 days. The workflow runs `flutter build ios --release --no-codesign`, then zips `Runner.app` into `Payload/Runner.app` inside `Pulse-unsigned.ipa`.

## 2. One-time Windows setup
1. Install **iTunes** and **iCloud** from apple.com (the direct downloads, not the Microsoft Store versions; Sideloadly needs them for the USB driver).
2. Install **Sideloadly** from sideloadly.io (AltStore also works, but Sideloadly is simpler for one app).
3. Use a free Apple ID (a spare one is wise: you type its password into Sideloadly; turn on two-factor and use the code it asks for).

## 3. Install
1. Plug in the iPhone, tap **Trust this computer**.
2. Open Sideloadly, select your iPhone at the top left, drag in `Pulse-unsigned.ipa`, enter the Apple ID, click **Start** and enter the 2FA code and the Apple ID password when asked. Leave *Advanced options* alone unless it reports a bundle ID clash; then change the bundle ID to something unique such as `com.yourname.pulse`.
3. On the iPhone: Settings > Privacy & Security > **Developer Mode** > on, then restart. (The switch only appears after the first sideload attempt.)
4. Settings > General > **VPN & Device Management** > tap your Apple ID > **Trust**.
5. Open Pulse.

## Limits of the free route
- The signature **expires every 7 days**. Re-sign on a fixed day, for example every Sunday evening: plug the phone in, open Sideloadly, drag in the same (or a newer) .ipa and click Start with the same Apple ID and bundle ID. Your data stays: re-signing over the installed app does not wipe it. Don't delete the app, and don't change the bundle ID between re-signs (that installs a second, empty copy). After 7 days without re-signing the app will not open until you do. Sideloadly's *Auto-refresh* (keep it running on the PC, phone on the same Wi-Fi) can do this for you.
- Free Apple IDs can have **3 sideloaded apps** at once and create about 10 new app IDs a week.
- **Friends** can't use your signing. Each friend must sideload the .ipa themselves with their own Apple ID and computer. This is fine for one or two people, poor for a wider beta.
- No push notifications or other special entitlements.

## When to pay
TestFlight ($99/yr) removes the 7-day expiry and lets friends install from a link. See `docs/TESTFLIGHT.md` and the TestFlight workflow, which stays ready for later.

## AltStore instead of Sideloadly
Install AltServer on Windows, install AltStore on the phone, then in AltStore > My Apps > **+** choose the .ipa. AltServer refreshes it in the background while the PC is on and on the same Wi-Fi.

## Free-minutes budget
GitHub Free gives a private repo **2,000 Actions minutes a month**. Linux minutes count 1x, macOS 10x. Approximate costs with the caches in place:

| Workflow | Runner | Runs when | Cost per run | Per month |
|---|---|---|---|---|
| `CI` (analyze + test, APK) | ubuntu | every push to main and PR | about 12-15 min | 30 runs is about 450 min |
| `Android emulator smoke` | ubuntu | manual only | about 20 min | use sparingly |
| `iOS unsigned IPA` | macos | manual or tag `v*` | about 12 min x 10 = 120 | at most 3-4 builds |
| `TestFlight` | macos | skipped until `IOS_BUNDLE_ID` is set | 0 until set up | n/a |

Keep it free: rebuild the iPhone IPA only when you need a new version (a re-sign every 7 days reuses the **same** .ipa; it does not need a new build), and run the emulator job only when you suspect a launch crash. Old runs in a superseded PR are cancelled automatically. Public repos have no minute limit. Check usage under GitHub > Settings > Billing > Usage. If you go over, Actions stops (it does not bill you) unless you have set a spending limit above $0, so leave that at $0.

## Native code compile check
The Kotlin capture code (SMS receiver, notification listener) compiles in every `CI` APK build. The Swift App Intent inbox (`ios/Runner/ShortcutCapture.swift`) compiles in the iOS build. If either breaks, the build log shows the compiler error; paste it back to fix.

## Smoke tests
- `test/smoke/app_smoke_test.dart` (runs in `flutter test`, no device): boots the real app on an in-memory database and walks first run, tour, start fresh, add cards, a simulated tap with the right/wrong-card note, Home, Settings > Privacy, Review, Budget and Wealth. Any framework exception fails it.
- `Android emulator smoke` workflow (manual): installs the debug APK on an API 30 emulator, launches it, and uploads `logcat.txt`, `launch.png` and `summary.txt` as the **emulator-smoke** artifact. It fails if logcat shows a crash or the process is gone.
