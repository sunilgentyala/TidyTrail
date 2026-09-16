import SwiftUI
import TidyTrailCore

struct FileRowView: View {
    let item: FileItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                VStack(alignment: .leading) {
                    Text(item.name)
                        .lineLimit(1)
                    Text(ByteFormatter.string(fromBytes: item.size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
