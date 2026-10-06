import Foundation

/// 用户可配置项。全局使用 UserDefaults，视图层用 @AppStorage 绑定同一批 key。
enum SettingsKey {
    static let recycleInsteadOfDelete = "MacClean.recycleInsteadOfDelete"
    static let tempMaxAgeDays = "MacClean.tempMaxAgeDays"
    static let largeFileThresholdMB = "MacClean.largeFileThresholdMB"
    static let excludedPaths = "MacClean.excludedPaths"
    static let autoSelectSafeItems = "MacClean.autoSelectSafeItems"
    static let confirmBeforeClean = "MacClean.confirmBeforeClean"
    static let hideFullDiskAccessWarning = "MacClean.hideFullDiskAccessWarning"
    static let lowDiskAlertEnabled = "MacClean.lowDiskAlertEnabled"
    static let lowDiskThresholdGB = "MacClean.lowDiskThresholdGB"
    static let weeklyAutoCleanEnabled = "MacClean.weeklyAutoCleanEnabled"
    static let showMenuBarIcon = "MacClean.showMenuBarIcon"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            recycleInsteadOfDelete: false,
            tempMaxAgeDays: 1,
            largeFileThresholdMB: 500,
            autoSelectSafeItems: true,
            confirmBeforeClean: true,
            hideFullDiskAccessWarning: false,
            lowDiskAlertEnabled: false,
            lowDiskThresholdGB: 10,
            weeklyAutoCleanEnabled: false,
            showMenuBarIcon: true,
            excludedPaths: [String](),
        ])
    }
}

/// 传给清理服务的不可变配置快照（Sendable，可跨 actor 传递）。
struct CleanupOptions: Sendable, Equatable {
    var recycleInsteadOfDelete: Bool
    var tempMaxAgeDays: Int
    var excludedPaths: [String]
    var largeFileThresholdBytes: Int64

    static let standard = CleanupOptions(
        recycleInsteadOfDelete: false,
        tempMaxAgeDays: 1,
        excludedPaths: [],
        largeFileThresholdBytes: 500 * 1_048_576
    )

    static var current: CleanupOptions {
        let defaults = UserDefaults.standard
        let thresholdMB = defaults.integer(forKey: SettingsKey.largeFileThresholdMB)
        return CleanupOptions(
            recycleInsteadOfDelete: defaults.bool(forKey: SettingsKey.recycleInsteadOfDelete),
            tempMaxAgeDays: max(0, defaults.integer(forKey: SettingsKey.tempMaxAgeDays)),
            excludedPaths: defaults.stringArray(forKey: SettingsKey.excludedPaths) ?? [],
            largeFileThresholdBytes: Int64(thresholdMB <= 0 ? 500 : thresholdMB) * 1_048_576
        )
    }

    func isExcluded(_ url: URL) -> Bool {
        guard !excludedPaths.isEmpty else { return false }
        let path = url.standardizedFileURL.path
        return excludedPaths.contains { !$0.isEmpty && path.hasPrefix($0) }
    }
}