import SwiftUI

struct DeletionLogsView: View {
    @State private var logFiles: [URL] = []
    @State private var selectedLogContent: LogContent?

    private var logsDirectory: URL { AppStorageLocations.logsDirectory }

    var body: some View {
        NavigationStack {
            Group {
                if logFiles.isEmpty {
                    ContentUnavailableViewCompat()
                } else {
                    List(logFiles, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            selectedLogContent = LogContent(text: (try? String(contentsOf: url, encoding: .utf8)) ?? "Unable to read log.")
                        }
                    }
                }
            }
            .navigationTitle("Deletion Logs")
            .onAppear(perform: reload)
            .sheet(item: $selectedLogContent) { content in
                NavigationStack {
                    ScrollView {
                        Text(content.text)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("Log")
                }
            }
        }
    }

    private func reload() {
        let fm = FileManager.default
        logFiles = (try? fm.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil))?
            .sorted { $0.lastPathComponent > $1.lastPathComponent } ?? []
    }
}

private struct LogContent: Identifiable {
    let id = UUID()
    let text: String
}

private struct ContentUnavailableViewCompat: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No deletion logs yet")
                .font(.headline)
            Text("Logs appear here after you delete files from the Scan screen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
