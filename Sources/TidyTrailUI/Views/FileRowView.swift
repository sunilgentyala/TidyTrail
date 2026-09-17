import SwiftUI
import TidyTrailCore

struct FileRowView: View {
    let item: FileItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: checkmarkSymbolName)
                    .foregroundStyle(item.isDownloaded ? (isSelected ? .blue : .secondary) : .secondary)
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .lineLimit(1)
                        if !item.isDownloaded {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if item.isDownloaded {
                        Text(ByteFormatter.string(fromBytes: item.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(ByteFormatter.string(fromBytes: item.size)) - open it once to check for duplicates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isDownloaded)
    }

    private var checkmarkSymbolName: String {
        guard item.isDownloaded else { return "circle.dashed" }
        return isSelected ? "checkmark.circle.fill" : "circle"
    }
}
