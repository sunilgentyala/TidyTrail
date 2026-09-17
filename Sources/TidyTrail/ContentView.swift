import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ScanResultsView()
                .tabItem { Label("Scan", systemImage: "magnifyingglass") }

            TrashView()
                .tabItem { Label("Trash", systemImage: "trash") }

            DeletionLogsView()
                .tabItem { Label("Logs", systemImage: "doc.text") }

            StorageOverviewView()
                .tabItem { Label("Storage", systemImage: "internaldrive") }
        }
    }
}

#Preview {
    ContentView()
}
