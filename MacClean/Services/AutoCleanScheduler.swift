import Foundation
import os

/// 每周自动清理（默认关闭，需用户在设置中显式开启）。
///
/// 严格约束，避免"无人值守误删"：
/// - 只清理风险等级为 safe 且可删除的条目；
/// - 强制使用「移入废纸篓」，不做永久删除；
/// - 只覆盖用户级缓存/日志（不触碰系统路径）；
/// - 每次执行都会写入清理历史并记录日志。
@MainActor
@Observable
final class AutoCleanScheduler {

    static let shared = AutoCleanScheduler()

    private(set) var lastRun: Date?
    private var timer: Timer?
    private let interval: TimeInterval = 7 * 24 * 3600
    private let checkInterval: TimeInterval = 3600
    private let lastRunKey = "MacClean.lastAutoCleanDate"

    private init() {}

    func start() {
        lastRun = UserDefaults.standard.object(forKey: lastRunKey) as? Date
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            Task { @MainActor in await self.tick() }
        }
        Task { await tick() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 供设置界面手动触发一次。
    func runNow() async {
        await performAutoClean()
    }

    private func tick() async {
        guard UserDefaults.standard.bool(forKey: SettingsKey.weeklyAutoCleanEnabled) else { return }
        if let lastRun, Date().timeIntervalSince(lastRun) < interval { return }
        await performAutoClean()
    }

    private func performAutoClean() async {
        let plans = [
            ScanPlan(name: "用户缓存") { $0.scanUserCaches() },
            ScanPlan(name: "用户日志") { $0.scanUserLogs() },
            ScanPlan(name: "应用缓存") { $0.scanAppCaches() },
        ]

        let scanService = ScanService()
        scanService.resetCancellation()

        var items: [ScanItem] = []
        for plan in plans {
            for await item in plan.makeStream(scanService) {
                if item.riskLevel == .safe && item.isRemovable && !item.requiresPrivilege {
                    items.append(item)
                }
            }
        }

        guard !items.isEmpty else {
            UserDefaults.standard.set(Date(), forKey: lastRunKey)
            lastRun = Date()
            return
        }

        var options = CleanupOptions.current
        options.recycleInsteadOfDelete = true   // 强制可恢复
        let cleanupService = CleanupService()
        for await event in cleanupService.clean(items: items, options: options) {
            if case .finished(let summary) = event {
                CleanupHistory.shared.record(summary: summary)
                AppLog.cleanup.notice("auto clean finished removed=\(summary.removedItems) freed=\(summary.freedBytes)")
            }
        }

        UserDefaults.standard.set(Date(), forKey: lastRunKey)
        lastRun = Date()
        await StorageStore.shared.refresh(force: true)
    }
}
