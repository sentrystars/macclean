import Foundation

@MainActor
@Observable
final class DeepCleanViewModel {
    var deepItems: [ScanItem] = []
    var isScanning = false
    var isCleaning = false
    var results: [CleanupResult] = []
    var error: String?

    private let scanService = ScanService()
    private var isCancelled = false

    private let cleanupService = CleanupService()

    func scan() async {
        isScanning = true
        deepItems = []

        // Claude VM
        let vmItems = await scanService.scanClaudeVM()
        deepItems.append(contentsOf: vmItems)

        // Xcode
        let xcodeItems = await scanService.scanXcodeData()
        deepItems.append(contentsOf: xcodeItems)

        isScanning = false
    }

    func cleanSelected() async {
        isCleaning = true
        results = []

        for item in deepItems where item.isSelected {
            switch item.category {
            case .claudeVM:
                if let result = try? await cleanupService.cleanClaudeVM() {
                    results.append(result)
                }
            case .xcodeData:
                if let result = try? await cleanupService.removeItems([item]).collectFirst() {
                    results.append(result)
                }
            case .iosSimulators:
                if let result = try? await cleanupService.cleanIOSSimulators() {
                    results.append(result)
                }
            default:
                if let result = try? await cleanupService.removeItems([item]).collectFirst() {
                    results.append(result)
                }
            }
        }

        isCleaning = false
        await scan()
    }

    func cancel() {
        isCancelled = true
        Task { await scanService.cancel() }
        Task { await cleanupService.cancel() }
        isScanning = false
        isCleaning = false
    }

    func toggleItem(_ id: UUID) {
        if let idx = deepItems.firstIndex(where: { $0.id == id }) {
            deepItems[idx].isSelected.toggle()
        }
    }
}

extension AsyncStream where Element == CleanProgress {
    func collectFirst() async -> CleanupResult? {
        var lastProgress: CleanProgress?
        for await progress in self {
            lastProgress = progress
        }
        guard let p = lastProgress else { return nil }
        return CleanupResult(
            category: .userCaches,
            bytesFreed: p.bytesFreed,
            itemsRemoved: p.itemsCleaned
        )
    }
}
