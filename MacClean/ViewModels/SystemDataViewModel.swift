import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SystemDataViewModel {

    var buckets: [SystemDataBucket] = []
    var isScanning = false
    var snapshotCount = 0
    var error: String?

    private let analyzer = SystemDataAnalyzer()

    var sortedBuckets: [SystemDataBucket] {
        buckets.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    var totalBytes: Int64 { buckets.reduce(0) { $0 + $1.sizeBytes } }
    var cleanableBytes: Int64 {
        buckets.filter { $0.safety == .cleanable }.reduce(0) { $0 + $1.sizeBytes }
    }
    var reviewBytes: Int64 {
        buckets.filter { $0.safety == .review }.reduce(0) { $0 + $1.sizeBytes }
    }

    var storageInfo: StorageInfo? { StorageStore.shared.storageInfo }

    func analyze() async {
        isScanning = true
        error = nil
        buckets = []

        var collected: [SystemDataBucket] = []
        for await bucket in analyzer.analyze() {
            collected.append(bucket)
            buckets = collected
        }

        snapshotCount = await analyzer.snapshotCount()
        isScanning = false
        await StorageStore.shared.refresh()
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
