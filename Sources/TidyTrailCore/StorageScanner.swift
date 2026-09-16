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
    public func scan(rootURL: URL) throws -> [FileItem] {
        let didStartAccessing = rootURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ScanError.accessDenied(rootURL)
        }

        var items: [FileItem] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0)
            let modDate = values.contentModificationDate ?? Date.distantPast
            items.append(FileItem(url: fileURL, name: fileURL.lastPathComponent, size: size, modificationDate: modDate))
        }
        return items
    }
}
