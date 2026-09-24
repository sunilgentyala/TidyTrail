# Security Policy

## Reporting a vulnerability

Please report security issues privately through GitHub's
[private vulnerability reporting](https://github.com/sunilgentyala/TidyTrail/security/advisories/new)
rather than a public issue. You should get an acknowledgement within 5
business days.

## Supported versions

Only the latest release receives security fixes.

## Security model

TidyTrail (iPhone and Mac) only touches folders the user explicitly picks.
It makes no network connections and collects no data.

| Area | Control |
|---|---|
| File access | iOS: document-picker grants + security-scoped bookmarks. macOS: App Sandbox with `user-selected.read-write` only. |
| Deleting | Files are moved into an app-owned trash, not deleted; permanent deletion only after 30 days or an explicit "Delete Forever". |
| Trash manifest | Treated as untrusted (it's in the file-shared Documents folder on iOS). Every entry must be a single path component; anything else is ignored and never used for delete/restore. |
| Deletion log | Written before any file is moved, rewritten with real outcomes; control characters in file names are escaped so entries can't be forged. |
| iCloud | Undownloaded placeholders are never read or hashed, so a scan never triggers downloads. |

## Verifying a Mac `.dmg`

```bash
shasum -a 256 -c TidyTrail.dmg.sha256
gh attestation verify TidyTrail.dmg --repo sunilgentyala/TidyTrail
```

The `.dmg` is ad-hoc signed until Developer ID signing and notarization
are configured (see `docs/MAC_APP_DISTRIBUTION.md`).

## Development process

Every push/PR runs the core XCTest suite plus full iOS and macOS builds on
GitHub-hosted macOS runners. Actions are pinned to commit SHAs, workflows
default to a read-only token, and Dependabot keeps actions and gems current.
