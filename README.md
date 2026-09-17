<p align="center">
  <img src="docs/assets/banner.png" alt="TidyTrail — find duplicates and large files in folders you pick, with a deletion log written before anything is deleted." width="100%">
</p>

<p align="center">
  <a href="https://github.com/sunilgentyala/TidyTrail/actions/workflows/ci.yml"><img src="https://github.com/sunilgentyala/TidyTrail/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2016%2B%20%7C%20macOS%2013%2B-4C3DDB" alt="iOS 16+ and macOS 13+">
  <img src="https://img.shields.io/badge/Swift-5.9-0EA8A3" alt="Swift 5.9">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/status-pre--release-orange" alt="Pre-release">
  <img src="https://img.shields.io/badge/version-1.2.0-blue" alt="Version 1.2.0">
</p>

<p align="center"><b>sunilgentyala.com/TidyTrail</b></p>

A storage organizer for iPhone and Mac that finds duplicate and large files
in folders you choose, and writes a plain-text log of exactly what it moved
to Trash - before it touches anything. Built with only Foundation, CryptoKit,
and SwiftUI, so both apps share the exact same scanning/dedupe/trash logic
(`TidyTrailCore`) and only differ where the platforms genuinely do: how you
pick a folder, and how the screens are laid out.

Apple's yearly OS releases (this app targets iOS 16+ and macOS 13+, so it
already covers everything from those versions forward, including whatever
ships as the current iOS/macOS release) don't require special handling here
- TidyTrail is built entirely on stable, non-deprecated Foundation/SwiftUI/
CryptoKit APIs, so it keeps working across new OS versions the same way any
well-behaved app does, without version-specific workarounds.

## What this app actually does (and doesn't)

iOS sandboxes every third-party app, and a Mac App Sandbox app is under the
same restriction: neither has an API that lets an app scan "the whole
device," clear another app's cache, or sweep OS-level temp files - Apple
rejects App Store submissions that claim to (Guideline 2.3.1, deceptive
functionality). So TidyTrail is scoped to what's actually possible and honest,
on both platforms:

| | |
|---|---|
| **Pick a folder** | On iPhone: grant access via the standard Files picker (`UIDocumentPickerViewController`) - e.g. an "On My iPhone" folder, or an iCloud Drive folder. On Mac: the standard `NSOpenPanel`. Picked folders are bookmarked so you can rescan one later without picking again. |
| **Scan it** | Recursively finds exact duplicate files (by content hash, not just name/size) and the largest files in that folder, without blocking the UI and with a Cancel button for big folders. iCloud files that haven't been downloaded yet are sized but never force-downloaded or hashed - see below. |
| **Delete with a log, and a Trash** | Before anything moves, writes a text manifest to a Logs folder, then moves the files to a TidyTrail-owned **Trash** (not straight deletion) and rewrites that same log with the real outcome (`TRASHED` or `FAILED: <reason>`) for every item. Trashed files are restorable to their original folder for 30 days, then purged automatically - matching how Photos' Recently Deleted works. |
| **Storage screen** | Shows device/volume-wide total/available capacity (public API), for context only - it does not and cannot claim to break that down by app. |

### iCloud Drive files

A file that's still an iCloud placeholder (not downloaded to the device) is
listed and sized, but TidyTrail skips it when hashing for duplicates and
won't let you select it for deletion - only a fully local copy can be
verified byte-for-byte, and reading a placeholder would force iOS to
download it over the user's cellular/battery budget just to check. Open the
file once in Files to download it, and it becomes eligible on the next scan.

Nothing here touches another app's data or the OS's own caches, because
Apple's sandboxing does not allow that on either platform.

## Mac app

TidyTrail also builds as a native Mac app (`TidyTrailMac`) - same
`TidyTrailCore` scanning/trash/dedupe logic, a sidebar instead of iPhone's
bottom tabs, and `NSOpenPanel` instead of the Files picker. It's sandboxed
the same way (`com.apple.security.app-sandbox`) and only ever touches
folders you explicitly pick.

To get a `.dmg`: Actions tab > "Build Mac App (.dmg)" > Run workflow. This
works today with zero setup - see
[`docs/MAC_APP_DISTRIBUTION.md`](docs/MAC_APP_DISTRIBUTION.md) for what that
gives you out of the box (an ad-hoc-signed `.dmg`, drag-to-Applications, one
right-click to bypass Gatekeeper's "unidentified developer" warning) versus
what a one-time Developer ID + notarization setup (Apple-account-only, same
constraint as the iOS signing setup below) gets you: a `.dmg` that opens
with zero warnings on any Mac.

## Architecture

- **`Sources/TidyTrailCore`** - a pure-Swift package (Foundation + CryptoKit
  only, no UIKit/AppKit) with the scanning, duplicate-detection, trash/restore
  (`TrashStore`), folder bookmarking (`FolderBookmark`), and log-then-move
  logic, shared by both apps. Covered by real XCTest unit tests in
  `Tests/TidyTrailCoreTests`.
- **`Sources/TidyTrailUI`** - SwiftUI views and view models shared by both
  apps (scan results, trash, logs, storage) - anything that doesn't need a
  platform-specific file picker or navigation shell.
- **`Sources/TidyTrail`** - the iOS app target: `TabView` navigation, and the
  UIKit document-picker bridge.
- **`Sources/TidyTrailMac`** - the macOS app target: `NavigationSplitView`
  sidebar navigation, and the `NSOpenPanel`-based folder picker.
- **`project.yml`** - an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  spec defining both app targets. The `.xcodeproj` itself is generated, not
  committed; `project.yml` is the source of truth so the project stays
  diffable and editable outside Xcode.
- **`.github/workflows/ci.yml`** - runs `swift test` and a full simulator
  build (iOS) and device build (macOS) on every push, on a macOS GitHub
  Actions runner (this repo is developed from a Windows machine with no
  local Xcode - CI is the real build/test loop).
- **`.github/workflows/release.yml`** - manual-dispatch workflow that builds,
  signs, and uploads an iOS build to TestFlight via fastlane. Requires a
  one-time Apple signing setup - see
  [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md).
- **`.github/workflows/release-mac.yml`** - manual-dispatch workflow that
  builds and packages the Mac app as a `.dmg` - see
  [`docs/MAC_APP_DISTRIBUTION.md`](docs/MAC_APP_DISTRIBUTION.md).

## Building locally (requires macOS + Xcode)

```bash
brew install xcodegen
xcodegen generate
open TidyTrail.xcodeproj
```

Then pick either the `TidyTrail` scheme (iPhone) or `TidyTrailMac` scheme
(Mac) in Xcode's scheme selector.

## Running just the core logic tests (macOS, no simulator needed)

```bash
swift test
```

## Status

In development, pre-release. Not yet on the App Store. See
[`CHANGELOG.md`](CHANGELOG.md) for what changed each version, and:

- [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md) - remaining
  manual steps to publish the iOS app (App Store Connect listing, signing
  credentials, screenshots, privacy details).
- [`docs/MAC_APP_DISTRIBUTION.md`](docs/MAC_APP_DISTRIBUTION.md) - how to get
  a `.dmg` today, and what's needed for a zero-warning one-click install.
- [`docs/INSTALLATION.md`](docs/INSTALLATION.md) - how to install a build
  today (Xcode/simulator, TestFlight) and how end users will install it once
  published.

## License

MIT - see [LICENSE](LICENSE).
