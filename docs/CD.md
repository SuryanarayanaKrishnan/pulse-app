# Continuous delivery (app)

Merge to `main` -> `CI` (analyze, test, release APK) -> `Release Android (testers)` publishes that same APK. Nothing is rebuilt, so the loop costs no extra minutes.

## Android
- Stable link: `https://github.com/<owner>/pulse-app/releases/download/android-latest/Pulse.apk` (rolling release `android-latest`, with a changelog of merged commits).
- Docs-only or workflow-only pushes are skipped.
- Testers need read access to the repo (it is private): add them as collaborators, or make the releases public later.
- Optional free channel: Firebase App Distribution. Create a Firebase project, register the Android app, add a `testers` group, then add repo secrets `FIREBASE_APP_ID` and `FIREBASE_SERVICE_ACCOUNT` (service account JSON). The workflow starts using them automatically; testers then get an email/app notification on each build.

## Backend connection and signing
- All builds read `deploy/app.defines.json` (`--dart-define-from-file`): API base URL, Supabase URL and the Supabase publishable key. These are public values meant to ship inside the app. If the VM's IP changes, update the URL there.
- CI signs the APK with a beta key kept only in the repo secrets `ANDROID_KEYSTORE_B64` (base64 keystore, alias `pulsebeta`) and `ANDROID_KEYSTORE_PASSWORD`, so every build installs over the previous one. Nothing key-related is committed. Without the secrets (fork PRs, local builds) the debug key is used and updates need an uninstall first (use Backup). Friends-and-family key only: Google Play needs its own.

## iOS
- macOS minutes cost 10x (about 150 of the 2,000 free minutes per build), so iOS does not build on every merge.
- `iOS unsigned IPA` runs Mon and Thu 02:00 UTC, builds only when app code changed since the last IPA, and stops after 8 scheduled runs a month. A `v*` tag or a manual run always builds.
- Output: rolling release `ios-latest` with `Pulse-unsigned.ipa`.
- Free Apple ID signing expires every 7 days. Re-run Sideloadly weekly, or use SideStore/AltStore, which refresh the app automatically while the phone is on the same Wi-Fi as a refresh helper. Both need a one-time setup on the phone and cost nothing; see their docs.

## Backend
See `pulse/docs/CD.md`: green CI on `main` deploys to the Oracle VM.
