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
        isCancelled = false
        error = nil
        deepItems = []

        // System Data
        let systemDataItems = await scanService.scanSystemData()
        deepItems.append(contentsOf: systemDataItems)
        if isCancelled { isScanning = false; return }

        // macOS System
        let macItems = await scanService.scanMacOSSystem()
        deepItems.append(contentsOf: macItems)
        if isCancelled { isScanning = false; return }

        // Claude VM
        let vmItems = await scanService.scanClaudeVM()
        deepItems.append(contentsOf: vmItems)
        if isCancelled { isScanning = false; return }

        // Xcode
        let xcodeItems = await scanService.scanXcodeData()
        deepItems.append(contentsOf: xcodeItems)
        if isCancelled { isScanning = false; return }

        // Container Caches (large)
        var containerItems: [ScanItem] = []
        for await item in await scanService.scanContainerCaches() {
            containerItems.append(item)
        }
        deepItems.append(contentsOf: containerItems)

        isScanning = false
    }

    func cleanSelected() async {
        isCleaning = true
        isCancelled = false
        results = []

        // Group by category for batch operations
        let selected = deepItems.filter { $0.isSelected && !isCancelled }
        let grouped = Dictionary(grouping: selected) { $0.category }

        for (category, items) in grouped {
            if isCancelled { break }
            switch category {
            case .claudeVM:
                if let result = try? await cleanupService.cleanClaudeVM() { results.append(result) }
            case .iosSimulators:
                if let result = try? await cleanupService.cleanIOSSimulators() { results.append(result) }
            case .dnsCache:
                if let result = try? await cleanupService.flushDNSCache() { results.append(result) }
            default:
                if let result = try? await cleanupService.removeItems(items).collectFirst() { results.append(result) }
            }
            // Remove cleaned items from the list
            deepItems.removeAll { items.map(\.id).contains($0.id) }
        }

        // Refresh scan after cleaning
        if !isCancelled {
            await scan()
        }

        if isCancelled {
            results = []
            error = "Cleanup was cancelled"
        }

        isCleaning = false
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
