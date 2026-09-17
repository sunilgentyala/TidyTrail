import SwiftUI
import TidyTrailCore

/// Shows device-wide free/used storage using the public volume capacity APIs.
/// This is informational only - Apple's app sandboxing does not let a
/// third-party app break this number down by other apps' data, so TidyTrail
/// does not claim to, on either platform.
struct StorageOverviewView: View {
    @State private var totalCapacity: Int64?
    @State private var availableCapacity: Int64?

    var body: some View {
        NavigationStack {
            List {
                Section("Device Storage") {
                    if let total = totalCapacity, let available = availableCapacity {
                        LabeledContent("Total capacity", value: ByteFormatter.string(fromBytes: total))
                        LabeledContent("Available", value: ByteFormatter.string(fromBytes: available))
                        LabeledContent("Used", value: ByteFormatter.string(fromBytes: total - available))
                    } else {
                        Text("Unavailable")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("TidyTrail can only report the volume total and clean folders you explicitly pick - it cannot see or clear other apps' data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Storage")
            .onAppear(perform: loadCapacity)
        }
    }

    private func loadCapacity() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        totalCapacity = values?.volumeTotalCapacity.map { Int64($0) }
        availableCapacity = values?.volumeAvailableCapacityForImportantUsage
    }
}

#Preview {
    StorageOverviewView()
}
