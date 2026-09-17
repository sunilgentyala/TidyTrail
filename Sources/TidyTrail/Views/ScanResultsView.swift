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
                            Text("Scanning… \(viewModel.scannedCount) files found")
                            Spacer()
                            Button("Cancel") { viewModel.cancelScan() }
                        }
                    }
                }

                if !viewModel.isScanning && viewModel.scannedItems.isEmpty && !viewModel.recentFolders.isEmpty {
                    Section("Recent Folders") {
                        ForEach(viewModel.recentFolders) { bookmark in
                            Button(bookmark.displayName) { viewModel.rescan(bookmark) }
                                .swipeActions {
                                    Button("Forget", role: .destructive) { viewModel.forgetFolder(bookmark) }
                                }
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
                    Section {
                        ForEach(Array(viewModel.duplicateGroups.enumerated()), id: \.offset) { _, group in
                            ForEach(group.dropFirst(), id: \.url) { item in
                                FileRowView(
                                    item: item,
                                    isSelected: viewModel.selectedForDeletion.contains(item.url),
                                    onToggle: { viewModel.toggleSelection(item) }
                                )
                            }
                        }
                    } header: {
                        HStack {
                            Text("Duplicates (keeping the newest copy)")
                            Spacer()
                            Button("Select All") { viewModel.selectAllDuplicates() }
                                .font(.caption)
                                .textCase(nil)
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

                if viewModel.scannedItems.isEmpty && !viewModel.isScanning && viewModel.recentFolders.isEmpty {
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
                    viewModel.pickedFolder(url)
                }
            }
            .confirmationDialog(
                "Move \(viewModel.selectedForDeletion.count) file(s) to Trash?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Move to Trash", role: .destructive) {
                    viewModel.deleteSelected()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A log will be written to Files > TidyTrail Logs first. Files move to the Trash tab, recoverable for 30 days, rather than being deleted right away.")
            }
        }
    }
}

#Preview {
    ScanResultsView()
}
