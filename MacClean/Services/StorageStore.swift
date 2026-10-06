import Foundation
import Observation

/// 全局磁盘信息仓库：侧栏与仪表盘共享同一份数据，避免重复全量扫描。
@MainActor
@Observable
final class StorageStore {

    static let shared = StorageStore()

    private(set) var storageInfo: StorageInfo?
    private(set) var isRefreshing = false
    private(set) var error: String?
    private(set) var lastRefreshed: Date?

    /// 缓存有效期，避免每次进入页面都重新枚举缓存目录与废纸篓。
    private let minimumInterval: TimeInterval = 30
    private let diagnostics = DiagnosticService()
    private var inFlight: Task<Void, Never>?

    private init() {}

    func refresh(force: Bool = false) async {
        if let lastRefreshed, !force, Date().timeIntervalSince(lastRefreshed) < minimumInterval {
            return
        }
        if let inFlight {
            await inFlight.value
            return
        }

        let task = Task { [diagnostics] in
            do {
                let info = try await diagnostics.getStorageInfo()
                self.storageInfo = info
                self.error = nil
                self.lastRefreshed = Date()

                if UserDefaults.standard.bool(forKey: SettingsKey.lowDiskAlertEnabled) {
                    let thresholdGB = max(1, UserDefaults.standard.integer(forKey: SettingsKey.lowDiskThresholdGB))
                    await NotificationService().notifyIfDiskLow(
                        freeBytes: info.freeBytes,
                        thresholdBytes: Int64(thresholdGB) * 1_073_741_824
                    )
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
        inFlight = task
        isRefreshing = true
        await task.value
        inFlight = nil
        isRefreshing = false
    }
}