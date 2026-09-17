# Changelog

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
