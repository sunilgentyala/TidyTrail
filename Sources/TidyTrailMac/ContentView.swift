import SwiftUI

/// A sidebar-based shell instead of iOS's bottom TabView - more in line with
/// how a Mac utility app is expected to navigate between a small number of
/// sections.
struct ContentView: View {
    private enum SidebarItem: String, CaseIterable, Identifiable {
        case scan = "Scan"
        case trash = "Trash"
        case logs = "Logs"
        case storage = "Storage"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .scan: "magnifyingglass"
            case .trash: "trash"
            case .logs: "doc.text"
            case .storage: "internaldrive"
            }
        }
    }

    @State private var selection: SidebarItem? = .scan

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationTitle("TidyTrail")
        } detail: {
            switch selection ?? .scan {
            case .scan: ScanResultsView()
            case .trash: TrashView()
            case .logs: DeletionLogsView()
            case .storage: StorageOverviewView()
            }
        }
    }
}

#Preview {
    ContentView()
}
