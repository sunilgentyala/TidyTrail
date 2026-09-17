import Foundation

public struct FileItem: Identifiable, Hashable, Sendable {
    public let id: URL
    public let url: URL
    public let name: String
    public let size: Int64
    public let modificationDate: Date

    /// False only for an iCloud Drive placeholder that hasn't been downloaded
    /// to the device yet. TidyTrail never forces an iCloud download just to
    /// scan a file, so these are sized and shown but skipped for hashing.
    public let isDownloaded: Bool

    public init(url: URL, name: String, size: Int64, modificationDate: Date, isDownloaded: Bool = true) {
        self.id = url
        self.url = url
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
        self.isDownloaded = isDownloaded
    }
}
