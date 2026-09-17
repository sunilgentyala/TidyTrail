# Installing TidyTrail

Which of these applies depends on where the app is right now: **pre-release**
(today) or **published** (after App Store review, see
[`APP_STORE_SUBMISSION.md`](APP_STORE_SUBMISSION.md)).

## Right now (pre-release): run it yourself via Xcode

Needs a Mac with Xcode. This repo is developed from Windows, so there is no
local build to hand you - build it on your own Mac or a cloud Mac:

```bash
git clone https://github.com/sunilgentyala/TidyTrail.git
cd TidyTrail
brew install xcodegen
xcodegen generate
open TidyTrail.xcodeproj
```

In Xcode:

1. Select the `TidyTrail` scheme.
2. **On the Simulator**: pick any iPhone simulator as the run destination and
   press ⌘R. No Apple ID needed.
3. **On your own iPhone**: connect it, select it as the run destination,
   then under the target's *Signing & Capabilities* tab set your personal
   team (Xcode > Settings > Accounts, add your free Apple ID if you haven't).
   Press ⌘R. The first run on-device will ask you to trust the developer
   profile on the phone: **Settings > General > VPN & Device Management**.
   A free Apple ID's signature expires after 7 days - just re-run from Xcode
   to renew it.

## Once a build is uploaded to TestFlight

After running the "Release to TestFlight" GitHub Actions workflow (see
`APP_STORE_SUBMISSION.md` for the one-time signing setup it needs):

1. Install **TestFlight** from the App Store on the iPhone.
2. In App Store Connect > TestFlight, add the tester's email as an internal
   or external tester (external testers need a build that passed Beta App
   Review first).
3. The tester accepts the email invite (or uses a public TestFlight link),
   opens it in TestFlight, and taps **Install**.

## Once published on the App Store

1. Open the **App Store** app on the iPhone.
2. Search "TidyTrail" (or open the direct App Store link once assigned).
3. Tap **Get**, authenticate with Face ID/Touch ID/Apple ID password.
4. The app installs to the Home Screen like any other App Store app -
   nothing else to configure.

TidyTrail asks for folder access only when you tap "Choose Folder" inside
the app (the standard iOS Files picker) - there is no separate permission
prompt to accept up front.

## Mac app

1. Actions tab > "Build Mac App (.dmg)" > Run workflow, then download
   `TidyTrail-dmg` from the finished run's artifacts (or, if the workflow
   was pointed at a release tag, from that release's assets).
2. Open `TidyTrail.dmg`, drag `TidyTrail.app` to the `Applications` shortcut
   next to it.
3. First launch: since this isn't yet notarized (see
   [`MAC_APP_DISTRIBUTION.md`](MAC_APP_DISTRIBUTION.md)), Gatekeeper will
   say it's from an unidentified developer - right-click `TidyTrail.app` >
   **Open** > Open, once. After that it opens normally.

TidyTrail for Mac asks for folder access only when you click "Choose
Folder…" (the standard `NSOpenPanel`) - same as the iPhone app, no upfront
permission prompt.
