import Foundation
import TidyTrailCore

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var scannedItems: [FileItem] = []
    @Published var duplicateGroups: [[FileItem]] = []
    @Published var selectedForDeletion: Set<URL> = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var lastLogURL: URL?

    private let scanner = StorageScanner()
    private let duplicateFinder = DuplicateFinder()

    var largeFiles: [FileItem] {
        Array(scannedItems.sorted { $0.size > $1.size }.prefix(50))
    }

    var totalScannedBytes: Int64 {
        scannedItems.reduce(0) { $0 + $1.size }
    }

    func scan(folder url: URL) {
        isScanning = true
        errorMessage = nil
        Task {
            do {
                let items = try scanner.scan(rootURL: url)
                let duplicates = try duplicateFinder.findDuplicates(in: items)
                scannedItems = items
                duplicateGroups = duplicates
            } catch {
                errorMessage = error.localizedDescription
            }
            isScanning = false
        }
    }

    func toggleSelection(_ item: FileItem) {
        if selectedForDeletion.contains(item.url) {
            selectedForDeletion.remove(item.url)
        } else {
            selectedForDeletion.insert(item.url)
        }
    }

    func deleteSelected() {
        let itemsToDelete = scannedItems.filter { selectedForDeletion.contains($0.url) }
        guard !itemsToDelete.isEmpty else { return }

        let logsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TidyTrail Logs", isDirectory: true)
        let logger = DeletionLogger(logsDirectory: logsDir)

        Task {
            do {
                let result = try logger.deleteWithLog(items: itemsToDelete)
                lastLogURL = result.logURL
                let deletedURLs = Set(itemsToDelete.map { $0.url })
                scannedItems.removeAll { deletedURLs.contains($0.url) }
                selectedForDeletion.subtract(deletedURLs)
                duplicateGroups = try duplicateFinder.findDuplicates(in: scannedItems)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
