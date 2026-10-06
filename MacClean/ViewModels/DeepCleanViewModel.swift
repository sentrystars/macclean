import Foundation
import Observation

@MainActor
@Observable
final class DeepCleanViewModel {

    var deepItems: [ScanItem] = []
    var isScanning = false
    var isCleaning = false
    var summary: CleanupSummary?
    var error: String?
    var maintenanceResults: [MaintenanceResult] = []
    var runningMaintenance: MaintenanceKind?

    private let scanService = ScanService()
    private let cleanupService = CleanupService()
    private let maintenanceService = MaintenanceService()

    /// 深度清理覆盖的范围（不含用户缓存，那属于缓存清理）。
    static let deepPlans: [ScanPlan] = [
        ScanPlan(name: "系统数据") { service in service.scanSystemData(options: .current) },
        ScanPlan(name: "macOS 系统") { $0.scanMacOSSystem() },
        ScanPlan(name: "Claude VM") { $0.scanClaudeVM() },
        ScanPlan(name: "Xcode 数据") { $0.scanXcodeData() },
        ScanPlan(name: "容器缓存") { $0.scanContainerCaches() },
    ]

    var totalBytes: Int64 { deepItems.reduce(0) { $0 + $1.sizeBytes } }
    var selectedBytes: Int64 { deepItems.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes } }
    var selectedCount: Int { deepItems.filter(\.isSelected).count }

    // MARK: - 扫描

    func scan() async {
        isScanning = true
        error = nil
        summary = nil
        deepItems = []
        scanService.resetCancellation()

        for plan in Self.deepPlans {
            if scanService.isCancelled { break }
            for await item in plan.makeStream(scanService) {
                deepItems.append(item)
            }
        }

        deepItems.sort { $0.sizeBytes > $1.sizeBytes }
        isScanning = false
    }

    // MARK: - 清理

    func cleanSelected() async {
        let items = deepItems.filter { $0.isSelected }
        guard !items.isEmpty else {
            error = "没有选中任何项目"
            return
        }

        isCleaning = true
        error = nil
        cleanupService.reset()

        let options = CleanupOptions.current
        for await event in cleanupService.clean(items: items, options: options) {
            if case .finished(let result) = event {
                summary = result
                CleanupHistory.shared.record(summary: result)
                let removedIDs = Set(items.filter { !FileManager.default.fileExists(atPath: $0.url.path) }.map(\.id))
                deepItems.removeAll { removedIDs.contains($0.id) }
            }
        }

        isCleaning = false
    }

    func cancel() {
        scanService.cancel()
        cleanupService.cancel()
        isScanning = false
        isCleaning = false
    }

    // MARK: - 维护动作

    func runMaintenance(_ kind: MaintenanceKind) async {
        runningMaintenance = kind
        error = nil
        let result = await maintenanceService.perform(kind, options: .current)
        maintenanceResults.insert(result, at: 0)
        if !result.succeeded {
            error = result.message
        }
        if kind == .emptyTrash && result.succeeded {
            // 废纸篓清空后同步刷新数量
            deepItems.removeAll { $0.category == .trash }
        }
        runningMaintenance = nil
    }

    // MARK: - 选择

    func toggleItem(_ id: UUID) {
        guard let index = deepItems.firstIndex(where: { $0.id == id }) else { return }
        deepItems[index].isSelected.toggle()
    }

    func selectAll() {
        for index in deepItems.indices where deepItems[index].isRemovable {
            deepItems[index].isSelected = true
        }
    }

    func deselectAll() {
        for index in deepItems.indices { deepItems[index].isSelected = false }
    }

    func reset() {
        deepItems = []
        summary = nil
        error = nil
        isScanning = false
        isCleaning = false
        maintenanceResults = []
    }
}