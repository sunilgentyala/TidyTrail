import AppKit
import SwiftUI

/// The Mac equivalent of iOS's `UIDocumentPickerViewController` sheet: an
/// `NSOpenPanel` restricted to picking one folder. Unlike the iOS picker,
/// this is a blocking modal, so there's no separate sheet-presentation state
/// to manage - the button just runs the panel and reports the result.
struct FolderPickerButton: View {
    var onPick: (URL) -> Void

    var body: some View {
        Button("Choose Folder…") {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"
            panel.message = "Pick a folder for TidyTrail to scan."
            if panel.runModal() == .OK, let url = panel.url {
                onPick(url)
            }
        }
    }
}
