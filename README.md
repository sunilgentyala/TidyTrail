<p align="center">
  <img src="docs/assets/banner.png" alt="TidyTrail — find duplicates and large files in folders you pick, with a deletion log written before anything is deleted." width="100%">
</p>

<p align="center">
  <a href="https://github.com/sunilgentyala/TidyTrail/actions/workflows/ci.yml"><img src="https://github.com/sunilgentyala/TidyTrail/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2016%2B-4C3DDB" alt="iOS 16+">
  <img src="https://img.shields.io/badge/Swift-5.9-0EA8A3" alt="Swift 5.9">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/status-pre--release-orange" alt="Pre-release">
  <img src="https://img.shields.io/badge/version-1.1.0-blue" alt="Version 1.1.0">
</p>

<p align="center"><b>sunilgentyala.com/TidyTrail</b></p>

An iOS storage organizer that finds duplicate and large files in folders you
choose, and writes a plain-text log of exactly what it deleted - before it
deletes anything.

## What this app actually does (and doesn't)

iOS sandboxes every third-party app. There is no API that lets an app scan
"the whole phone," clear another app's cache, or sweep OS-level temp files -
Apple rejects apps that claim to (App Store Review Guideline 2.3.1, deceptive
functionality). So TidyTrail is scoped to what's actually possible and honest:

| | |
|---|---|
| **Pick a folder** | Grant access to one folder via the standard Files picker (`UIDocumentPickerViewController`) - e.g. an "On My iPhone" folder, or an iCloud Drive folder. Picked folders are bookmarked so you can rescan one later without picking again. |
| **Scan it** | Recursively finds exact duplicate files (by content hash, not just name/size) and the largest files in that folder, without blocking the UI and with a Cancel button for big folders. iCloud files that haven't been downloaded yet are sized but never force-downloaded or hashed - see below. |
| **Delete with a log, and a Trash** | Before anything moves, writes a text manifest to `Files > On My iPhone > TidyTrail Logs`, then moves the files to a TidyTrail-owned **Trash tab** (not straight deletion) and rewrites that same log with the real outcome (`TRASHED` or `FAILED: <reason>`) for every item. Trashed files are restorable to their original folder for 30 days, then purged automatically - matching how Photos' Recently Deleted works. |
| **Storage tab** | Shows device-wide total/available capacity (public API), for context only - it does not and cannot claim to break that down by app. |

### iCloud Drive files

A file that's still an iCloud placeholder (not downloaded to the device) is
listed and sized, but TidyTrail skips it when hashing for duplicates and
won't let you select it for deletion - only a fully local copy can be
verified byte-for-byte, and reading a placeholder would force iOS to
download it over the user's cellular/battery budget just to check. Open the
file once in Files to download it, and it becomes eligible on the next scan.

Nothing here touches another app's data or the OS's own caches, because iOS
does not allow that.

## Architecture

- **`Sources/TidyTrailCore`** - a pure-Swift package (Foundation + CryptoKit
  only, no UIKit) with the scanning, duplicate-detection, trash/restore
  (`TrashStore`), folder bookmarking (`FolderBookmark`), and log-then-move
  logic. Covered by real XCTest unit tests in `Tests/TidyTrailCoreTests`.
- **`Sources/TidyTrail`** - the SwiftUI app target (views, view models, UIKit
  document-picker bridge).
- **`project.yml`** - an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  spec. The `.xcodeproj` itself is generated, not committed; `project.yml` is
  the source of truth so the project stays diffable and editable outside Xcode.
- **`.github/workflows/ci.yml`** - runs `swift test` and a full simulator
  build on every push, on a macOS GitHub Actions runner (this repo is
  developed from a Windows machine with no local Xcode - CI is the real
  build/test loop).
- **`.github/workflows/release.yml`** - manual-dispatch workflow that builds,
  signs, and uploads a build to TestFlight via fastlane. Requires a one-time
  Apple signing setup - see [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md).

## Building locally (requires macOS + Xcode)

```bash
brew install xcodegen
xcodegen generate
open TidyTrail.xcodeproj
```

## Running just the core logic tests (macOS, no simulator needed)

```bash
swift test
```

## Status

In development, pre-release. Not yet on the App Store. See
[`CHANGELOG.md`](CHANGELOG.md) for what changed each version, and:

- [`docs/APP_STORE_SUBMISSION.md`](docs/APP_STORE_SUBMISSION.md) - remaining
  manual steps to publish (App Store Connect listing, signing credentials,
  screenshots, privacy details).
- [`docs/INSTALLATION.md`](docs/INSTALLATION.md) - how to install a build
  today (Xcode/simulator, TestFlight) and how end users will install it once
  published.

## License

MIT - see [LICENSE](LICENSE).
