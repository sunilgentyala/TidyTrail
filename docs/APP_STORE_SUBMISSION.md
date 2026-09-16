# App Store submission checklist

This repo automates the build/test/upload steps. Everything below requires
your own Apple Developer account and can't be done by CI or by me on your
behalf - Apple requires the account owner to do these (several involve 2FA
or accepting legal agreements).

The repo itself, the app icon, the landing page, and the privacy policy page
are already done - see "Things already done for you" below. What's left is
entirely Apple-account-side steps 1-6.

## 1. One-time Apple Developer Portal setup

1. Sign in at https://developer.apple.com/account.
2. Register the App ID `com.sunilgentyala.tidytrail` (Certificates,
   Identifiers & Profiles > Identifiers > +). No special capabilities are
   needed - TidyTrail doesn't use push notifications, iCloud, etc.
3. Note your **Team ID** (top right of the Developer Portal, or
   Membership page) - you'll add it as a GitHub secret below.

## 2. Create the app record in App Store Connect

1. Go to https://appstoreconnect.apple.com > Apps > + > New App.
2. Platform: iOS. Bundle ID: `com.sunilgentyala.tidytrail`. SKU: anything
   unique, e.g. `tidytrail-001`.
3. Fill in the required listing info later (step 5) - the record just needs
   to exist for TestFlight uploads to have somewhere to land.

## 3. Create an App Store Connect API key (for headless CI uploads)

1. App Store Connect > Users and Access > Integrations > App Store Connect
   API > + (Team Keys).
2. Role: App Manager (or Admin). Download the `.p8` key file **once** -
   Apple won't let you download it again.
3. Note the **Key ID** and **Issuer ID** shown on that page.
4. Base64-encode the key file's contents (needed for the
   `APP_STORE_CONNECT_KEY_CONTENT` secret):
   - macOS/Linux: `base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'`
   - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8"))`

## 4. Set up code signing with fastlane match (one-time, needs a Mac)

`match` stores your signing certificate and provisioning profile encrypted
in a private git repo, so CI can use them without you re-signing manually
every time. The **first** run has to happen interactively on a Mac (a cloud
Mac works fine) because Apple's cert-generation flow expects a real login:

1. Create a new **private** GitHub repo, e.g. `tidytrail-certs` (empty, just
   for match to store encrypted certs in).
2. On a Mac (or cloud Mac session), from this repo's directory:
   ```bash
   bundle install
   bundle exec fastlane match appstore
   ```
   It will ask for your Apple ID, a password to encrypt the certs
   (this becomes `MATCH_PASSWORD`), and the git URL of the certs repo
   (this becomes `MATCH_GIT_URL`, e.g. `https://github.com/sunilgentyala/tidytrail-certs.git`).
3. After that, CI can reuse those certs in `readonly` mode indefinitely
   (already configured in `fastlane/Fastfile`) - no further Mac needed
   unless the certificate expires (yearly) or you add a new device.

## 5. Add GitHub Actions secrets

In this repo: Settings > Secrets and variables > Actions > New repository
secret. Add:

| Secret | Value |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | Key ID from step 3 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from step 3 |
| `APP_STORE_CONNECT_KEY_CONTENT` | base64 `.p8` contents from step 3 |
| `MATCH_GIT_URL` | private certs repo URL from step 4 |
| `MATCH_PASSWORD` | the password you chose in step 4 |
| `APPLE_TEAM_ID` | Team ID from step 1 |
| `FASTLANE_APPLE_ID` | your Apple ID email |

## 6. Run the release workflow

Actions tab > "Release to TestFlight" > Run workflow. This builds, signs,
and uploads a build to TestFlight. From there:

1. App Store Connect > TestFlight - add yourself as an internal tester,
   confirm the build installs and works on a real device.
2. Fill in the App Store listing: screenshots (required sizes per device
   class), description, keywords, support URL, and **privacy policy URL** -
   use `https://sunilgentyala.github.io/TidyTrail/privacy.html` (already
   written and live once GitHub Pages is enabled - see below). For the
   privacy "nutrition label" (App Store Connect > App Privacy): TidyTrail
   makes no network requests and collects nothing, so this should be a
   straightforward "Data Not Collected" declaration - confirm that's still
   accurate before submitting if you've changed the code since.
3. Submit for review from App Store Connect.

## Things already done for you

- App icon: a real 1024x1024 icon is in place at
  `Sources/TidyTrail/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  (generated, not a placeholder). Replace it if you want different branding.
- Privacy policy: written and published at
  `docs/privacy.html` → `https://sunilgentyala.github.io/TidyTrail/privacy.html`.
- Landing page: `https://sunilgentyala.github.io/TidyTrail/` - useful for the
  App Store listing's "marketing URL" field.

## Things only you can decide/provide

- App Store screenshots (need a real device or simulator with the built app
  running - can't be produced without a Mac).
- Final review of the App Store description/marketing copy and keywords.
- Whether the free-tier "Data Not Collected" privacy label still matches the
  code if you add any feature later (e.g. crash reporting, analytics).
