# Changelog

## 1.2.0 - 2026-09-16

Adds a native Mac app alongside the existing iPhone app, in response to
"can this be a one-click .dmg install?" - iOS has no equivalent of a `.dmg`
(no way to install a third-party app outside TestFlight/App Store), so this
is a separate native macOS build of the same core logic rather than a
literal answer to that question for the iPhone app itself.

- **`TidyTrailMac` app target** (`Sources/TidyTrailMac`): a native SwiftUI
  Mac app - `NavigationSplitView` sidebar instead of iPhone's bottom tabs,
  `NSOpenPanel` instead of the Files picker - reusing `TidyTrailCore` and a
  new shared `Sources/TidyTrailUI` layer (scan results, trash, logs, storage
  screens) unchanged between platforms.
- Sandboxed the same way as the iOS app
  (`com.apple.security.app-sandbox` + user-selected read-write only) - the
  Mac app can't see or touch anything outside a folder you explicitly pick,
  same as the iPhone app.
- `FolderBookmark` (TidyTrailCore) now uses real `.withSecurityScope`
  bookmarks on macOS (the correct mechanism for a sandboxed Mac app's
  Powerbox-granted folder access to survive a relaunch), while keeping the
  plain-bookmark behavior iOS already used correctly.
- `AppStorageLocations` keeps its logs/trash/bookmarks under
  `~/Library/Application Support/TidyTrail` on Mac, rather than the iOS
  app's `~/Documents` convention, which would otherwise clutter a Mac
  user's real Documents folder.
- New `.github/workflows/release-mac.yml`: builds, ad-hoc signs, and
  packages `TidyTrail.app` into a `.dmg` today with no setup required, and
  will additionally notarize/staple once Developer ID credentials are added
  (see `docs/MAC_APP_DISTRIBUTION.md`) - the difference between "right-click
  to open" and a true zero-warning one-click install.
- CI now also builds the Mac target on every push (`mac-app-build` job),
  alongside the existing core-logic tests and iOS simulator build.

Targets iOS 16+ and macOS 13+ using only stable, non-deprecated Foundation/
SwiftUI/CryptoKit APIs, so it keeps building and running correctly across
newer OS versions without version-specific handling.

## 1.1.0 - 2026-09-16

Gap-driven pass after checking TidyTrail's v1.0.0 scope against how current
iPhone storage-cleaner apps (Cleaner Kit, Clever Cleaner, Files by Google's
duplicate/large-file tools, etc.) and Apple's own Photos "Recently Deleted"
handle deletion, iCloud content, and repeat scans. Every change below stays
inside what a sandboxed third-party app can honestly do - see the README's
"What this app actually does (and doesn't)" table, which is unchanged.

- **Trash instead of instant delete.** Deleting now moves files into a
  TidyTrail-owned Trash (new **Trash** tab) instead of removing them right
  away. Items are restorable to their original folder for 30 days (matching
  Photos' Recently Deleted window) before being purged for good. Every prior
  version deleted permanently on the spot with no way back - the single
  biggest gap versus how every mainstream cleaner app on the App Store now
  handles deletion.
- **iCloud placeholders are no longer mishandled.** Files not yet downloaded
  from iCloud Drive are sized and listed, but skipped for duplicate hashing
  and can't be selected for deletion (badged with a cloud icon) - TidyTrail
  never forces an iCloud download just to scan or delete a file.
- **Recent Folders + rescan.** Picked folders are now bookmarked, so you can
  rescan one from the Scan tab without walking through the folder picker
  again every time - and so a trashed file can find its way back to the
  right folder on restore.
- **Cancellable, non-blocking scans.** Scanning a large folder no longer
  blocks the UI thread; a live "N files found" counter and a Cancel button
  replace the old indeterminate spinner with no way to stop it.
- **"Select All" for duplicates.** One tap selects every duplicate except
  the newest copy in each group, instead of tapping each row individually.

### Fixed

- Scanning previously ran synchronously on the main actor inside
  `ScanViewModel`, so a large folder (lots of files, or large files needing
  hashing) could freeze the UI without any way to cancel. Scanning now runs
  off the main actor via a cancellable task.

## 1.0.0 - 2026-09-16

Initial release: folder picker, duplicate-by-content-hash detection,
largest-files list, delete-with-log, and device storage overview.
