import Foundation

enum ViewPhase: Equatable {
    case idle
    case scanning(progress: ScanProgress)
    case results(items: [ScanItem])
    case cleaning(progress: CleanProgress)
    case complete(results: [CleanupResult])
    case error(message: String)

    static func == (lhs: ViewPhase, rhs: ViewPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.results, .results): return true
        case (.cleaning, .cleaning): return true
        case (.complete, .complete): return true
        case (.error, .error): return true
        default: return false
        }
    }
}

@MainActor
@Observable
final class CleanupViewModel {
    var phase: ViewPhase = .idle
    var scanItems: [ScanItem] = []
    var selectedItems = Set<UUID>()
    var results: [CleanupResult] = []
    var sortBy: SortOption = .sizeDesc

    enum SortOption: String, CaseIterable {
        case sizeDesc = "Largest First"
        case sizeAsc = "Smallest First"
        case name = "By Name"
        case category = "By Category"
    }

    var sortedScanItems: [ScanItem] {
        switch sortBy {
        case .sizeDesc: return scanItems.sorted { $0.sizeBytes > $1.sizeBytes }
        case .sizeAsc: return scanItems.sorted { $0.sizeBytes < $1.sizeBytes }
        case .name: return scanItems.sorted { ($0.subcategory ?? $0.url.lastPathComponent) < ($1.subcategory ?? $1.url.lastPathComponent) }
        case .category: return scanItems.sorted { $0.category.displayName < $1.category.displayName }
        }
    }

    private let scanService = ScanService()
    private let cleanupService = CleanupService()

    // MARK: - Scan
    func startScan() async {
        phase = .scanning(progress: ScanProgress(
            phase: "Starting scan...",
            currentItem: "",
            filesScanned: 0,
            bytesFound: 0,
            categoriesCompleted: 0,
            totalCategories: 9
        ))

        scanItems = []
        var totalBytes: Int64 = 0
        var categoriesDone = 0

        // Application Caches
        await scanCategory({ await scanService.scanUserCaches().collect() }, name: "User Caches", totalBytes: &totalBytes, categoriesDone: &categoriesDone)
        await scanCategory({ await scanService.scanUserLogs().collect() }, name: "User Logs", totalBytes: &totalBytes, categoriesDone: &categoriesDone)
        await scanCategory({ await scanService.scanContainerCaches().collect() }, name: "Container Caches", totalBytes: &totalBytes, categoriesDone: &categoriesDone)

        let appCaches = await scanService.scanAppCaches()
        scanItems.append(contentsOf: appCaches)
        totalBytes += appCaches.reduce(0) { $0 + $1.sizeBytes }
        categoriesDone += 1

        // System Data
        let systemDataItems = await scanService.scanSystemData()
        scanItems.append(contentsOf: systemDataItems)
        totalBytes += systemDataItems.reduce(0) { $0 + $1.sizeBytes }
        categoriesDone += 1

        let vmItems = await scanService.scanClaudeVM()
        scanItems.append(contentsOf: vmItems)
        totalBytes += vmItems.reduce(0) { $0 + $1.sizeBytes }
        categoriesDone += 1

        let xcodeItems = await scanService.scanXcodeData()
        scanItems.append(contentsOf: xcodeItems)
        totalBytes += xcodeItems.reduce(0) { $0 + $1.sizeBytes }
        categoriesDone += 1

        // macOS
        let macItems = await scanService.scanMacOSSystem()
        scanItems.append(contentsOf: macItems)
        totalBytes += macItems.reduce(0) { $0 + $1.sizeBytes }
        categoriesDone += 1

        if let trashItem = await scanService.scanTrash() {
            scanItems.append(trashItem)
            totalBytes += trashItem.sizeBytes
        }
        categoriesDone += 1

        selectedItems = Set(scanItems.filter { $0.category.riskLevel != .warning }.map(\.id))

        phase = .results(items: scanItems)
    }

    private func scanCategory(_ scan: () async -> [ScanItem], name: String, totalBytes: inout Int64, categoriesDone: inout Int) async {
        let items = await scan()
        scanItems.append(contentsOf: items)
        totalBytes += items.reduce(0) { $0 + $1.sizeBytes }
        categoriesDone += 1
        phase = .scanning(progress: ScanProgress(
            phase: "Scanning \(name)...",
            currentItem: name,
            filesScanned: scanItems.count,
            bytesFound: totalBytes,
            categoriesCompleted: categoriesDone,
            totalCategories: 9
        ))
    }

    // MARK: - Cleanup
    func startCleanup() async {
        let itemsToClean = scanItems.filter { selectedItems.contains($0.id) }
        guard !itemsToClean.isEmpty else {
            phase = .error(message: "No items selected for cleanup")
            return
        }

        phase = .cleaning(progress: CleanProgress(
            phase: "Starting cleanup...",
            currentItem: "",
            itemsCleaned: 0,
            totalItems: itemsToClean.count,
            bytesFreed: 0
        ))

        results = []
        var totalFreed: Int64 = 0
        var cleaned = 0

        let stream = await cleanupService.removeItems(itemsToClean)
        for await progress in stream {
            phase = .cleaning(progress: progress)
            cleaned = progress.itemsCleaned
            totalFreed = progress.bytesFreed
        }

        // Handle special cleanups
        if itemsToClean.contains(where: { $0.category == .claudeVM }) {
            if let result = try? await cleanupService.cleanClaudeVM() {
                results.append(result)
            }
        }
        if itemsToClean.contains(where: { $0.category == .iosSimulators }) {
            if let result = try? await cleanupService.cleanIOSSimulators() {
                results.append(result)
            }
        }
        if itemsToClean.contains(where: { $0.category == .dnsCache }) {
            if let result = try? await cleanupService.flushDNSCache() {
                results.append(result)
            }
        }
        if itemsToClean.contains(where: { $0.category == .trash }) {
            let trashSvc = TrashService()
            if let result = try? await trashSvc.emptyTrash() {
                results.append(result)
            }
        }

        let summaryResult = CleanupResult(
            category: .userCaches,
            bytesFreed: totalFreed,
            itemsRemoved: cleaned
        )
        results.append(summaryResult)

        phase = .complete(results: results)

        // Record cleanup history
        let totalCleaned = results.reduce(0) { $0 + $1.bytesFreed }
        if totalCleaned > 0 {
            CleanupHistory.shared.recordCleanup(freed: totalFreed)
        }
    }

    func cancelScan() {
        Task { await scanService.cancel() }
        phase = .idle
    }

    func cancelCleanup() {
        Task { await cleanupService.cancel() }
        phase = .idle
    }

    func reset() {
        phase = .idle
        scanItems = []
        selectedItems = []
        results = []
    }

    func toggleItem(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
}

// MARK: - AsyncStream collector
extension AsyncStream where Element == ScanItem {
    func collect() async -> [Element] {
        var items: [Element] = []
        for await item in self {
            items.append(item)
        }
        return items
    }
}
