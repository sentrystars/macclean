import Foundation
import os
import UserNotifications

/// 系统通知：目前用于低磁盘空间提醒。
final class NotificationService: Sendable {

    private let lastAlertKey = "MacClean.lastLowDiskAlert"
    private let throttleInterval: TimeInterval = 24 * 3600

    @MainActor
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            AppLog.diagnostics.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 若可用空间低于阈值则发通知（24 小时内只提醒一次）。
    @MainActor
    func notifyIfDiskLow(freeBytes: Int64, thresholdBytes: Int64) async {
        guard freeBytes > 0, freeBytes < thresholdBytes else { return }

        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: lastAlertKey) as? Date,
           Date().timeIntervalSince(last) < throttleInterval {
            return
        }
        defaults.set(Date(), forKey: lastAlertKey)

        let content = UNMutableNotificationContent()
        content.title = "磁盘空间不足"
        content.body = "剩余可用空间仅 \(FileSizeFormatter.string(from: freeBytes))，建议立即清理缓存与废纸篓。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "macclean.lowdisk.\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            AppLog.diagnostics.notice("low disk notification posted free=\(freeBytes)")
        } catch {
            AppLog.diagnostics.error("notification post failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
