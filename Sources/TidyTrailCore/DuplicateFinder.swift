import Foundation
import CryptoKit

/// Finds byte-for-byte identical files among a set of scanned items.
///
/// Only files that share an exact size are hashed, so a folder with mostly
/// unique files stays cheap to scan even though the comparison itself is
/// a full content hash rather than a name/date heuristic.
public struct DuplicateFinder: Sendable {
    public init() {}

    /// Returns groups of duplicate files, newest-modified first in each group.
    /// Zero-byte files are ignored since "empty file" is not a meaningful duplicate.
    /// iCloud placeholders that haven't been downloaded yet are ignored too -
    /// their content can't be hashed without forcing a download, so TidyTrail
    /// can't tell whether they're actually duplicates until the user opens them.
    public func findDuplicates(in items: [FileItem]) throws -> [[FileItem]] {
        let bySize = Dictionary(grouping: items.filter { $0.size > 0 && $0.isDownloaded }, by: \.size)
        var duplicateGroups: [[FileItem]] = []

        for (_, candidates) in bySize where candidates.count > 1 {
            var byHash: [String: [FileItem]] = [:]
            for item in candidates {
                let hash = try Self.hash(of: item.url)
                byHash[hash, default: []].append(item)
            }
            for group in byHash.values where group.count > 1 {
                duplicateGroups.append(group.sorted { $0.modificationDate > $1.modificationDate })
            }
        }
        return duplicateGroups
    }

    static func hash(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) // 1 MB at a time
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
