import Foundation

public struct DeletionRecord: Sendable {
    public let item: FileItem
    public var outcome: Outcome

    public enum Outcome: Sendable, Equatable {
        case pending
        case trashed
        case failed(String)
    }

    public init(item: FileItem) {
        self.item = item
        self.outcome = .pending
    }
}

/// Writes a plain-text manifest of what is about to be moved to the trash
/// *before* touching anything, then moves each item and rewrites the same
/// manifest with the real outcome (trashed / failed + reason) for every entry.
///
/// The log always reflects what actually happened, not just what was planned,
/// so a failed move is never silently reported as successful. Items are moved
/// to `TrashStore`, not deleted outright - see that type for why.
public struct DeletionLogger: @unchecked Sendable {
    private let logsDirectory: URL
    private let trashStore: TrashStore
    private let fileManager: FileManager
    private let dateProvider: () -> Date

    public init(
        logsDirectory: URL,
        trashStore: TrashStore,
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.logsDirectory = logsDirectory
        self.trashStore = trashStore
        self.fileManager = fileManager
        self.dateProvider = dateProvider
    }

    @discardableResult
    public func ensureLogsDirectoryExists() throws -> URL {
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
        return logsDirectory
    }

    /// Moves `items` to the trash (see `TrashStore`) and writes a log of the
    /// outcome. `folderBookmarkID` identifies the folder they came from, so a
    /// later restore can put them back - pass `nil` if that folder wasn't
    /// bookmarked.
    public func trashWithLog(
        items: [FileItem],
        folderBookmarkID: UUID?
    ) throws -> (logURL: URL, records: [DeletionRecord]) {
        try ensureLogsDirectoryExists()

        var records = items.map { DeletionRecord(item: $0) }
        let plannedAt = dateProvider()
        let safeTimestamp = ISO8601DateFormatter().string(from: plannedAt).replacingOccurrences(of: ":", with: "-")
        let logURL = logsDirectory.appendingPathComponent("TidyTrail-\(safeTimestamp).txt")

        // Write the manifest of what's about to happen before touching any file.
        try write(records: records, plannedAt: plannedAt, to: logURL)

        for index in records.indices {
            do {
                try trashStore.moveToTrash(item: records[index].item, folderBookmarkID: folderBookmarkID)
                records[index].outcome = .trashed
            } catch {
                records[index].outcome = .failed(error.localizedDescription)
            }
        }

        // Rewrite the same log with what actually happened.
        try write(records: records, plannedAt: plannedAt, to: logURL)
        return (logURL, records)
    }

    private func write(records: [DeletionRecord], plannedAt: Date, to logURL: URL) throws {
        var lines: [String] = []
        lines.append("TidyTrail deletion log")
        lines.append("Planned at: \(ISO8601DateFormatter().string(from: plannedAt))")
        lines.append("Items: \(records.count)")
        let totalBytes = records.reduce(Int64(0)) { $0 + $1.item.size }
        lines.append("Total size: \(ByteFormatter.string(fromBytes: totalBytes))")
        lines.append("Trashed items are recoverable from the Trash tab for \(Int(trashStore.retentionInterval / 86400)) days.")
        lines.append("")

        for record in records {
            let status: String
            switch record.outcome {
            case .pending: status = "PENDING"
            case .trashed: status = "TRASHED"
            case .failed(let reason): status = "FAILED (\(reason))"
            }
            lines.append("[\(status)] \(record.item.url.path)")
            lines.append("    size: \(ByteFormatter.string(fromBytes: record.item.size)), modified: \(record.item.modificationDate)")
        }

        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: logURL, atomically: true, encoding: .utf8)
    }
}
