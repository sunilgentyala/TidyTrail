import Foundation

public enum ByteFormatter {
    public static func string(fromBytes bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
