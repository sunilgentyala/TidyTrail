import Foundation
import TidyTrailCore

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var scannedItems: [FileItem] = []
    @Published var duplicateGroups: [[FileItem]] = []
    @Published var selectedForDeletion: Set<URL> = []
    @Published var isScanning = false
    @Published var scannedCount = 0
    @Published var errorMessage: String?
    @Published var lastLogURL: URL?
    @Published var recentFolders: [FolderBookmark] = []

    private let scanner = StorageScanner()
    private let duplicateFinder = DuplicateFinder()
    private let trashStore = AppStorageLocations.makeTrashStore()
    private let bookmarkStore = AppStorageLocations.makeBookmarkStore()
    private var currentFolderBookmarkID: UUID?
    private var scanTask: Task<Void, Never>?

    init() {
        recentFolders = bookmarkStore.load()
    }

    var largeFiles: [FileItem] {
        Array(scannedItems.sorted { $0.size > $1.size }.prefix(50))
    }

    var totalScannedBytes: Int64 {
        scannedItems.reduce(0) { $0 + $1.size }
    }

    /// Every duplicate except the newest copy in each group - i.e. what
    /// "Select All Duplicates" would add to the selection.
    var selectableDuplicateCount: Int {
        duplicateGroups.reduce(0) { $0 + max($1.count - 1, 0) }
    }

    /// Called after the folder picker hands back a URL: remembers it as a
    /// bookmark so it can be rescanned (or restored into) without picking
    /// again, then scans it.
    func pickedFolder(_ url: URL) {
        let bookmark = try? FolderBookmark.make(for: url)
        if let bookmark {
            recentFolders = (try? bookmarkStore.remember(bookmark)) ?? recentFolders
        }
        performScan(folderBookmarkID: bookmark?.id) { (url, {}) }
    }

    /// Re-opens a previously bookmarked folder and scans it again.
    func rescan(_ bookmark: FolderBookmark) {
        performScan(folderBookmarkID: bookmark.id) {
            let (url, didStartAccessing) = try bookmark.resolve()
            return (url, { if didStartAccessing { url.stopAccessingSecurityScopedResource() } })
        }
    }

    func forgetFolder(_ bookmark: FolderBookmark) {
        recentFolders = (try? bookmarkStore.forget(id: bookmark.id)) ?? recentFolders
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    /// Runs `resolve` and the scan itself off the main actor so a big folder
    /// never blocks the UI thread, and supports cancellation mid-scan.
    /// `resolve` returns the folder URL to scan plus a cleanup closure run
    /// once the scan (or its cancellation/failure) is finished.
    private func performScan(
        folderBookmarkID: UUID?,
        resolve: @escaping @Sendable () throws -> (url: URL, cleanup: @Sendable () -> Void)
    ) {
        scanTask?.cancel()
        isScanning = true
        errorMessage = nil
        scannedCount = 0
        currentFolderBookmarkID = folderBookmarkID

        let scanner = self.scanner
        let duplicateFinder = self.duplicateFinder

        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let (url, cleanup) = try resolve()
                defer { cleanup() }

                let items = try scanner.scan(
                    rootURL: url,
                    progress: { count in
                        guard count % 20 == 0 else { return }
                        Task { @MainActor in self.scannedCount = count }
                    },
                    isCancelled: { Task.isCancelled }
                )
                let duplicates = try duplicateFinder.findDuplicates(in: items)
                await MainActor.run {
                    self.scannedItems = items
                    self.duplicateGroups = duplicates
                    self.isScanning = false
                }
            } catch is CancellationError {
                await MainActor.run { self.isScanning = false }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    func toggleSelection(_ item: FileItem) {
        guard item.isDownloaded else { return }
        if selectedForDeletion.contains(item.url) {
            selectedForDeletion.remove(item.url)
        } else {
            selectedForDeletion.insert(item.url)
        }
    }

    /// Selects every duplicate except the newest copy in each group -
    /// `duplicateGroups` is already sorted newest-first per group.
    func selectAllDuplicates() {
        selectedForDeletion.formUnion(duplicateGroups.flatMap { $0.dropFirst().map(\.url) })
    }

    func deleteSelected() {
        let itemsToDelete = scannedItems.filter { selectedForDeletion.contains($0.url) }
        guard !itemsToDelete.isEmpty else { return }

        let logger = DeletionLogger(logsDirectory: AppStorageLocations.logsDirectory, trashStore: trashStore)
        let folderBookmarkID = currentFolderBookmarkID

        Task {
            do {
                let result = try logger.trashWithLog(items: itemsToDelete, folderBookmarkID: folderBookmarkID)
                lastLogURL = result.logURL
                let trashedURLs = Set(result.records.compactMap { record -> URL? in
                    guard case .trashed = record.outcome else { return nil }
                    return record.item.url
                })
                scannedItems.removeAll { trashedURLs.contains($0.url) }
                selectedForDeletion.subtract(trashedURLs)
                duplicateGroups = try duplicateFinder.findDuplicates(in: scannedItems)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
