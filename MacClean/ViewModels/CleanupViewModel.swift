import Foundation
import Observation

enum ViewPhase {
    case idle
    case scanning(progress: ScanProgress)
    case results
    case cleaning(progress: CleanProgress)
    case complete(summary: CleanupSummary)
    case error(message: String)
}

@MainActor
@Observable
final class CleanupViewModel {

    var phase: ViewPhase = .idle
    var scanItems: [ScanItem] = []
    var selectedItems = Set<UUID>()
    var sortBy: SortOption = .sizeDesc
    private(set) var categoriesCompleted = 0
    private(set) var totalCategories = 0
    private(set) var lastSummary: CleanupSummary?

    enum SortOption: String, CaseIterable, Sendable {
        case sizeDesc = "按大小降序"
        case sizeAsc = "按大小升序"
        case name = "按名称"
        case category = "按分类"
    }

    private let scanService = ScanService()
    private let cleanupService = CleanupService()

    // MARK: - 派生数据

    var sortedScanItems: [ScanItem] {
        switch sortBy {
        case .sizeDesc: return scanItems.sorted { $0.sizeBytes > $1.sizeBytes }
        case .sizeAsc: return scanItems.sorted { $0.sizeBytes < $1.sizeBytes }
        case .name: return scanItems.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .category: return scanItems.sorted { $0.category.displayName < $1.category.displayName }
        }
    }

    var totalBytes: Int64 { scanItems.reduce(0) { $0 + $1.sizeBytes } }
    var selectedBytes: Int64 { scanItems.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes } }
    var selectedCount: Int { selectedItems.count }

    func groupedItems() -> [(group: String, categories: [(category: CleanupCategory, items: [ScanItem])])] {
        let groups = ["Application Caches", "System Data", "macOS"]
        return groups.compactMap { groupName in
            let groupItems = sortedScanItems.filter { $0.category.group == groupName }
            guard !groupItems.isEmpty else { return nil }
            let byCategory = Dictionary(grouping: groupItems) { $0.category }
            let categories = byCategory
                .map { (category: $0.key, items: $0.value) }
                .sorted { $0.category.displayName < $1.category.displayName }
            return (groupName, categories)
        }
    }

    // MARK: - 扫描

    func startScan(plans: [ScanPlan] = ScanPlan.standard) async {
        reset()
        scanService.resetCancellation()
        totalCategories = plans.count
        phase = .scanning(progress: ScanProgress(phase: "准备扫描…", totalCategories: plans.count))

        let (stream, continuation) = AsyncStream<ScanItem>.makeStream(bufferingPolicy: .unbounded)

        let consumer = Task { @MainActor [weak self] in
            for await item in stream {
                self?.append(item)
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for plan in plans {
                group.addTask { [scanService] in
                    for await item in plan.makeStream(scanService) {
                        continuation.yield(item)
                    }
                    await self.markCategoryCompleted(plan.name)
                }
            }
        }

        continuation.finish()
        await consumer.value

        // 取消后不能把 phase 覆盖回 results，否则界面会把半截结果当成完整结果。
        guard !scanService.isCancelled, !Task.isCancelled else { return }
        phase = .results
        applyDefaultSelection()
    }

    private func markCategoryCompleted(_ name: String) {
        guard !scanService.isCancelled else { return }
        categoriesCompleted += 1
        phase = .scanning(progress: ScanProgress(
            phase: "已完成：\(name)",
            currentItem: name,
            filesScanned: scanItems.count,
            bytesFound: totalBytes,
            categoriesCompleted: categoriesCompleted,
            totalCategories: totalCategories
        ))
    }

    private func append(_ item: ScanItem) {
        scanItems.append(item)
        phase = .scanning(progress: ScanProgress(
            phase: "扫描中…",
            currentItem: item.displayName,
            filesScanned: scanItems.count,
            bytesFound: totalBytes,
            categoriesCompleted: categoriesCompleted,
            totalCategories: totalCategories
        ))
    }

    private func applyDefaultSelection() {
        let autoSelect = UserDefaults.standard.bool(forKey: SettingsKey.autoSelectSafeItems)
        if autoSelect {
            selectedItems = Set(scanItems.filter { $0.riskLevel == .safe && $0.isRemovable }.map(\.id))
        } else {
            selectedItems = []
        }
    }

    func cancelScan() {
        scanService.cancel()
        phase = .idle
    }

    // MARK: - 清理

    func startCleanup() async {
        let items = scanItems.filter { selectedItems.contains($0.id) }
        guard !items.isEmpty else {
            phase = .error(message: "没有选中任何项目")
            return
        }

        cleanupService.reset()
        phase = .cleaning(progress: CleanProgress(phase: "准备清理…", totalItems: items.count))

        let options = CleanupOptions.current
        for await event in cleanupService.clean(items: items, options: options) {
            switch event {
            case .progress(let progress):
                phase = .cleaning(progress: progress)
            case .finished(let summary):
                lastSummary = summary
                CleanupHistory.shared.record(summary: summary)
                phase = .complete(summary: summary)
                // 已删除的条目从列表移除
                let removedIDs = Set(items.filter { !FileManager.default.fileExists(atPath: $0.url.path) }.map(\.id))
                scanItems.removeAll { removedIDs.contains($0.id) }
                selectedItems.subtract(removedIDs)
            }
        }
    }

    func cancelCleanup() {
        cleanupService.cancel()
        phase = .idle
    }

    // MARK: - 选择

    func toggleItem(_ id: UUID) {
        if selectedItems.contains(id) { selectedItems.remove(id) } else { selectedItems.insert(id) }
    }

    func selectAll() { selectedItems = Set(scanItems.filter(\.isRemovable).map(\.id)) }
    func selectNone() { selectedItems = [] }
    func selectSafeOnly() {
        selectedItems = Set(scanItems.filter { $0.riskLevel == .safe && $0.isRemovable }.map(\.id))
    }

    func reset() {
        phase = .idle
        scanItems = []
        selectedItems = []
        lastSummary = nil
        categoriesCompleted = 0
    }
}
