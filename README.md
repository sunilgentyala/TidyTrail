# TidyTrail

An iOS storage organizer that finds duplicate and large files in folders you
choose, and writes a plain-text log of exactly what it deleted - before it
deletes anything.

## What this app actually does (and doesn't)

iOS sandboxes every third-party app. There is no API that lets an app scan
"the whole phone," clear another app's cache, or sweep OS-level temp files -
Apple rejects apps that claim to (App Store Review Guideline 2.3.1, deceptive
functionality). So TidyTrail is scoped to what's actually possible and honest:

- You pick a folder via the standard Files picker (`UIDocumentPickerViewController`) -
  e.g. an "On My iPhone" folder, or an iCloud Drive folder.
- TidyTrail scans only that folder (recursively), finds exact duplicate files
  (by content hash, not just name/size) and the largest files.
- You choose what to delete. **Before deleting anything**, TidyTrail writes a
  text manifest of what's about to happen to `Files > On My iPhone > TidyTrail
  Logs`, then deletes, then rewrites that same log with the real outcome
  (`DELETED` or `FAILED: <reason>`) for every item.
- A Storage tab shows device-wide total/available capacity (public API), for
  context only - it cannot and does not claim to break that down by app.

Nothing here touches another app's data or the OS's own caches, because iOS
does not allow that.

## Architecture

- `Sources/TidyTrailCore` - a pure-Swift package (Foundation + CryptoKit only,
  no UIKit) with the scanning, duplicate-detection, and delete-then-log logic.
  Covered by real XCTest unit tests in `Tests/TidyTrailCoreTests`.
- `Sources/TidyTrail` - the SwiftUI app target (views, view models, UIKit
  document-picker bridge).
- `project.yml` - an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec.
  The `.xcodeproj` itself is generated, not committed; `project.yml` is the
  source of truth so the project stays diffable and editable outside Xcode.
- `.github/workflows/ci.yml` - runs `swift test` and a simulator build on
  every push, on a macOS GitHub Actions runner (this repo is developed from a
  Windows machine with no local Xcode - CI is the real build/test loop).
- `.github/workflows/release.yml` - manual-dispatch workflow that builds,
  signs, and uploads a build to TestFlight via fastlane. Requires one-time
  Apple signing setup - see `docs/APP_STORE_SUBMISSION.md`.

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

In development. Not yet submitted to the App Store - see
`docs/APP_STORE_SUBMISSION.md` for the remaining manual steps (App Store
Connect listing, screenshots, privacy details, signing credentials).

## License

MIT - see [LICENSE](LICENSE).
