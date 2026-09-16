import Foundation

public struct FileItem: Identifiable, Hashable, Sendable {
    public let id: URL
    public let url: URL
    public let name: String
    public let size: Int64
    public let modificationDate: Date

    public init(url: URL, name: String, size: Int64, modificationDate: Date) {
        self.id = url
        self.url = url
        self.name = name
        self.size = size
        self.modificationDate = modificationDate
    }
}
