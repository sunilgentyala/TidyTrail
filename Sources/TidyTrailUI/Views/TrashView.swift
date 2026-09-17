import SwiftUI
import TidyTrailCore

struct TrashView: View {
    @StateObject private var viewModel = TrashViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.items.isEmpty {
                    EmptyTrashPlaceholder()
                } else {
                    List(viewModel.items) { item in
                        TrashRowView(
                            item: item,
                            expirationDate: viewModel.expirationDate(for: item),
                            onRestore: { viewModel.restore(item) },
                            onDeleteForever: { viewModel.deleteForever(item) }
                        )
                    }
                }
            }
            .navigationTitle("Trash")
            .onAppear(perform: viewModel.reload)
            .alert(
                "Couldn't complete that",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in if !isPresented { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

private struct TrashRowView: View {
    let item: TrashedItem
    let expirationDate: Date
    let onRestore: () -> Void
    let onDeleteForever: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name).lineLimit(1)
            Text("\(ByteFormatter.string(fromBytes: item.size)) - removed for good \(expirationDate, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Restore", action: onRestore)
                    .buttonStyle(.bordered)
                Button("Delete Forever", role: .destructive, action: onDeleteForever)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyTrashPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "trash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Trash is empty")
                .font(.headline)
            Text("Files you delete from the Scan screen stay here for 30 days so you can restore them, before they're removed for good.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    TrashView()
}
