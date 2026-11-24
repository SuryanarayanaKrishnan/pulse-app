# Getting Pulse onto iPhones (TestFlight)

No Mac needed. GitHub builds the app on a macOS machine, signs it, and sends it to TestFlight.

## One-time setup (about 30 minutes, plus Apple approval time)

1. **Join the Apple Developer Program** at developer.apple.com/programs (US$99/year, can be paid from your iPhone's Apple Developer app). Approval can take from minutes to a couple of days.
2. **Pick a bundle id** that is unique to you, for example `com.yourname.pulse`. The placeholder `com.pulse.pulse` is likely taken.
3. **Register it**: developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > + > App IDs > App > enter the bundle id.
4. **Create the app**: appstoreconnect.apple.com > Apps > + > New App. Platform iOS, name "Pulse" (or a variant if taken), pick your bundle id, any SKU.
5. **Create an API key**: App Store Connect > Users and Access > Integrations > App Store Connect API > Team Keys > +. Name it "CI", access **Admin** (needed so Xcode can create signing certificates for you). Download the `.p8` file once, and note the **Key ID** and **Issuer ID** shown at the top.
6. **Find your Team ID**: developer.apple.com > Membership details.
7. **Add to GitHub** (repo > Settings > Secrets and variables > Actions):
   - Secrets: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (paste the full contents of the .p8 file, including the BEGIN/END lines).
   - Variable (Variables tab): `IOS_BUNDLE_ID` = your bundle id.

Never paste these values into chat or commit them.

## Ship a build

Repo > Actions > TestFlight > Run workflow. Takes roughly 15 minutes. The build shows up in App Store Connect > TestFlight after Apple finishes processing (10 to 30 minutes). Each run gets a new build number automatically.

## Install on your own iPhone

Install the TestFlight app, sign in with the same Apple ID, and add yourself under TestFlight > Internal Testing (up to 100 people on your App Store Connect team, no review needed).

## Share with friends and family

TestFlight > External Testing > create a group > enable **Public Link** > set a tester limit. Send them the link; they install TestFlight and tap it. The first build of each version goes through Beta App Review (usually under a day). Fill in the test information and a short "what to test" note first.

## Costs and limits

- Apple Developer Program: $99/year, unavoidable for any iPhone distribution.
- GitHub macOS runner minutes are billed at 10x. On the free plan you get about 200 macOS minutes a month, roughly 10 to 15 builds. Fine for a beta.
- TestFlight builds expire after 90 days.

## Heads up

The app currently runs on sample data, so no backend is needed for this build. Once real data and sign-in are wired up, the backend needs to be deployed and its URL passed into the build.
