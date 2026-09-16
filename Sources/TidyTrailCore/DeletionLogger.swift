import Foundation

public struct DeletionRecord: Sendable {
    public let item: FileItem
    public var outcome: Outcome

    public enum Outcome: Sendable, Equatable {
        case pending
        case deleted
        case failed(String)
    }

    public init(item: FileItem) {
        self.item = item
        self.outcome = .pending
    }
}

/// Writes a plain-text manifest of what is about to be deleted *before*
/// deleting anything, then deletes each item and rewrites the same manifest
/// with the real outcome (deleted / failed + reason) for every entry.
///
/// The log always reflects what actually happened, not just what was planned,
/// so a failed deletion is never silently reported as successful.
public struct DeletionLogger: @unchecked Sendable {
    private let logsDirectory: URL
    private let fileManager: FileManager
    private let dateProvider: () -> Date

    public init(
        logsDirectory: URL,
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.logsDirectory = logsDirectory
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

    public func deleteWithLog(items: [FileItem]) throws -> (logURL: URL, records: [DeletionRecord]) {
        try ensureLogsDirectoryExists()

        var records = items.map { DeletionRecord(item: $0) }
        let plannedAt = dateProvider()
        let safeTimestamp = ISO8601DateFormatter().string(from: plannedAt).replacingOccurrences(of: ":", with: "-")
        let logURL = logsDirectory.appendingPathComponent("TidyTrail-\(safeTimestamp).txt")

        // Write the manifest of what's about to happen before touching any file.
        try write(records: records, plannedAt: plannedAt, to: logURL)

        for index in records.indices {
            let url = records[index].item.url
            do {
                try fileManager.removeItem(at: url)
                records[index].outcome = .deleted
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
        lines.append("")

        for record in records {
            let status: String
            switch record.outcome {
            case .pending: status = "PENDING"
            case .deleted: status = "DELETED"
            case .failed(let reason): status = "FAILED (\(reason))"
            }
            lines.append("[\(status)] \(record.item.url.path)")
            lines.append("    size: \(ByteFormatter.string(fromBytes: record.item.size)), modified: \(record.item.modificationDate)")
        }

        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: logURL, atomically: true, encoding: .utf8)
    }
}
