# Mac app: getting a real one-click `.dmg`

TidyTrail for Mac (`TidyTrailMac` target) builds and packages into a `.dmg`
today with zero setup - see "What already works" below. Getting to a `.dmg`
that opens with **no Gatekeeper warning** needs one thing only your own Apple
Developer account can do: a Developer ID Application certificate plus
notarization. This can't be done by CI or by me on your behalf - Apple
requires the account owner (2FA, certificate issuance).

## What already works right now

Actions tab > "Build Mac App (.dmg)" > Run workflow. This:

1. Builds `TidyTrailMac` in Release configuration, ad-hoc signed
   (`CODE_SIGN_IDENTITY="-"`) - no certificate needed.
2. Packages `TidyTrail.app` into `TidyTrail.dmg` with an `Applications`
   shortcut alongside it (the standard drag-to-install layout).
3. Uploads it as a downloadable workflow artifact, and - if you fill in the
   `release_tag` input with an existing tag like `v1.1.0` - attaches it to
   that GitHub release too.

The catch: an ad-hoc signature satisfies App Sandbox/entitlements for a copy
that's already on the Mac, but it isn't notarized, so a copy downloaded from
the internet gets Gatekeeper's "Apple could not verify this app" warning.
Anyone who gets the `.dmg` can still open it via **right-click > Open**
(or `xattr -d com.apple.quarantine TidyTrail.app`), it's just not a silent
double-click for a stranger.

## Getting to zero-warning, one-click installs

### 1. One-time Apple Developer Portal setup

You need a **Developer ID Application** certificate - different from the
"Apple Distribution" / App Store certificate `fastlane match` already
manages for the iOS side (`docs/APP_STORE_SUBMISSION.md`), because Mac apps
distributed outside the Mac App Store use a different signing identity.

1. Sign in at https://developer.apple.com/account (same account/Team ID
   as the iOS setup).
2. Certificates, Identifiers & Profiles > Certificates > + > **Developer ID
   Application**. Follow the CSR flow (Keychain Access > Certificate
   Assistant > Request a Certificate From a Certificate Authority, on a Mac).
3. Download the resulting `.cer`, double-click to add it to your login
   keychain, then export it (with its private key) as a `.p12` from Keychain
   Access - you'll set a password on export.

### 2. Create an app-specific password for notarization

1. https://appleid.apple.com > Sign-In and Security > App-Specific Passwords
   > generate one, label it e.g. "TidyTrail notarization".
2. Note your **Team ID** (same one from the iOS setup, Developer Portal >
   Membership).

### 3. Add GitHub Actions secrets

Settings > Secrets and variables > Actions > New repository secret:

| Secret | Value |
|---|---|
| `MAC_DEVELOPER_ID_CERT_P12` | base64 of the `.p12` from step 1 - `base64 -i DeveloperID.p12 \| tr -d '\n'` on a Mac, or `[Convert]::ToBase64String([IO.File]::ReadAllBytes("DeveloperID.p12"))` in PowerShell |
| `MAC_DEVELOPER_ID_CERT_PASSWORD` | the password you set exporting the `.p12` |
| `MAC_DEVELOPER_ID_IDENTITY` | the certificate's full name, e.g. `Developer ID Application: Your Name (TEAMID1234)` - find it with `security find-identity -v -p codesigning` on a Mac that has it installed |
| `NOTARY_APPLE_ID` | your Apple ID email |
| `NOTARY_TEAM_ID` | Team ID from step 2 |
| `NOTARY_APP_SPECIFIC_PASSWORD` | the app-specific password from step 2 |

Once these exist, "Build Mac App (.dmg)" automatically signs with your
Developer ID, submits to Apple's notary service, staples the ticket, and
*then* packages the `.dmg` - so anyone who downloads it can just double-click
`TidyTrail.dmg` and drag the app to Applications with no warning.

## Things only you can decide/provide

- Whether to distribute the Mac app outside the App Store this way (as
  described here) or also submit it to the Mac App Store, which is a
  separate submission with its own listing, sandboxing review, and (like
  iOS) an App Store Connect record only you can create.
- The Mac app currently has no dedicated app icon design pass - it reuses
  the iPhone app's icon resized for macOS's icon sizes. Replace
  `Sources/TidyTrailMac/Assets.xcassets/AppIcon.appiconset` if you want
  distinct Mac branding (Apple's Big Sur+ icon style expects some padding
  baked into the source image; the current one is a direct resize).
