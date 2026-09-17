import Foundation

/// Scans a single user-granted directory (e.g. a folder picked via
/// UIDocumentPickerViewController) and lists the regular files inside it.
///
/// TidyTrail never touches anything outside a folder the user explicitly
/// picked - iOS does not allow third-party apps to enumerate other apps'
/// storage or OS-level caches, and TidyTrail does not pretend otherwise.
public struct StorageScanner: Sendable {
    public init() {}

    public enum ScanError: Error, LocalizedError {
        case accessDenied(URL)

        public var errorDescription: String? {
            switch self {
            case .accessDenied(let url):
                return "TidyTrail was not granted access to \(url.lastPathComponent)."
            }
        }
    }

    /// Recursively scans `rootURL` and returns every regular file found.
    /// `rootURL` must be a URL the caller already has read access to.
    ///
    /// - Parameters:
    ///   - progress: called with a running count of files found so far, from
    ///     whatever thread the scan runs on - callers hop back to the main
    ///     actor themselves before touching UI state with it.
    ///   - isCancelled: polled between files so a long scan of a big folder
    ///     can be stopped from the UI instead of running to completion.
    public func scan(
        rootURL: URL,
        progress: ((Int) -> Void)? = nil,
        isCancelled: (() -> Bool)? = nil
    ) throws -> [FileItem] {
        let didStartAccessing = rootURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [
            .isRegularFileKey, .fileSizeKey, .contentModificationDateKey,
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ScanError.accessDenied(rootURL)
        }

        var items: [FileItem] = []
        for case let fileURL as URL in enumerator {
            if isCancelled?() == true {
                throw CancellationError()
            }

            let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0)
            let modDate = values.contentModificationDate ?? Date.distantPast
            let isDownloaded = Self.isContentAvailableLocally(values)
            items.append(FileItem(
                url: fileURL,
                name: fileURL.lastPathComponent,
                size: size,
                modificationDate: modDate,
                isDownloaded: isDownloaded
            ))
            progress?(items.count)
        }
        return items
    }

    /// A plain local file is always "downloaded". An iCloud Drive item only
    /// counts as available once its downloading status is `.current` or
    /// `.downloaded` - TidyTrail must not treat a placeholder as readable,
    /// since reading one would force iOS to fetch it from iCloud on the
    /// user's cellular/battery budget without them asking for that.
    static func isContentAvailableLocally(_ values: URLResourceValues) -> Bool {
        guard values.isUbiquitousItem == true else { return true }
        switch values.ubiquitousItemDownloadingStatus {
        case .current, .downloaded:
            return true
        default:
            return false
        }
    }
}
