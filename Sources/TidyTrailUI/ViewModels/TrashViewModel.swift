import Foundation
import TidyTrailCore

@MainActor
final class TrashViewModel: ObservableObject {
    @Published var items: [TrashedItem] = []
    @Published var errorMessage: String?

    private let trashStore = AppStorageLocations.makeTrashStore()
    private let bookmarkStore = AppStorageLocations.makeBookmarkStore()

    /// Purges anything past its 30-day retention, then reloads what's left.
    func reload() {
        _ = try? trashStore.purgeExpired()
        items = trashStore.loadManifest().sorted { $0.trashedDate > $1.trashedDate }
    }

    func expirationDate(for item: TrashedItem) -> Date {
        trashStore.expirationDate(for: item)
    }

    /// Restores `item` to the folder it was trashed from, using that
    /// folder's remembered bookmark. Fails clearly if the folder was never
    /// bookmarked or can no longer be reopened, rather than guessing a
    /// different destination.
    func restore(_ item: TrashedItem) {
        guard let bookmarkID = item.folderBookmarkID,
              let bookmark = bookmarkStore.load().first(where: { $0.id == bookmarkID }) else {
            errorMessage = "\"\(item.name)\" can't be restored automatically - its original folder wasn't remembered. You can still find it in Files under TidyTrail Trash, or delete it forever."
            return
        }
        do {
            let (url, didStartAccessing) = try bookmark.resolve()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
            _ = try trashStore.restore(item, to: url)
            reload()
        } catch {
            errorMessage = "Couldn't restore \"\(item.name)\": \(error.localizedDescription)"
        }
    }

    func deleteForever(_ item: TrashedItem) {
        do {
            try trashStore.deleteForever(item)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
