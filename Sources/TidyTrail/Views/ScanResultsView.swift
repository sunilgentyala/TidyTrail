import SwiftUI
import TidyTrailCore

struct ScanResultsView: View {
    @StateObject private var viewModel = ScanViewModel()
    @State private var isShowingPicker = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isScanning {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Scanning…")
                        }
                    }
                }

                if !viewModel.scannedItems.isEmpty {
                    Section("Overview") {
                        LabeledContent("Files scanned", value: "\(viewModel.scannedItems.count)")
                        LabeledContent("Total size", value: ByteFormatter.string(fromBytes: viewModel.totalScannedBytes))
                    }
                }

                if !viewModel.duplicateGroups.isEmpty {
                    Section("Duplicates (keeping the newest copy)") {
                        ForEach(Array(viewModel.duplicateGroups.enumerated()), id: \.offset) { _, group in
                            ForEach(group.dropFirst(), id: \.url) { item in
                                FileRowView(
                                    item: item,
                                    isSelected: viewModel.selectedForDeletion.contains(item.url),
                                    onToggle: { viewModel.toggleSelection(item) }
                                )
                            }
                        }
                    }
                }

                if !viewModel.largeFiles.isEmpty {
                    Section("Largest files") {
                        ForEach(viewModel.largeFiles, id: \.url) { item in
                            FileRowView(
                                item: item,
                                isSelected: viewModel.selectedForDeletion.contains(item.url),
                                onToggle: { viewModel.toggleSelection(item) }
                            )
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                if viewModel.scannedItems.isEmpty && !viewModel.isScanning {
                    Section {
                        Text("Choose a folder to scan. TidyTrail can only see files you explicitly pick - iOS does not allow apps to scan the whole device.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("TidyTrail")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Choose Folder") { isShowingPicker = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete (\(viewModel.selectedForDeletion.count))") {
                        isShowingDeleteConfirmation = true
                    }
                    .disabled(viewModel.selectedForDeletion.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingPicker) {
                FolderPickerView { url in
                    viewModel.scan(folder: url)
                }
            }
            .confirmationDialog(
                "Delete \(viewModel.selectedForDeletion.count) file(s)?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete and Log", role: .destructive) {
                    viewModel.deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A text log of what was deleted will be written to Files > TidyTrail Logs before anything is removed.")
            }
        }
    }
}

#Preview {
    ScanResultsView()
}
