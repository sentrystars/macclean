import AppKit
import Foundation

/// 隐私清理：只处理 PrivacyCatalog 中显式枚举的路径，且一律移入废纸篓。
final class PrivacyCleaner: Sendable {

    private var fileManager: FileManager { .default }

    /// 已在运行、需要先退出的应用（用于阻止在不安全状态下清理浏览器数据库）。
    @MainActor
    func runningBlocker(for target: PrivacyTarget) -> String? {
        guard !target.requiredClosedBundleIDs.isEmpty else { return nil }
        for app in NSWorkspace.shared.runningApplications {
            if let bundleID = app.bundleIdentifier, target.requiredClosedBundleIDs.contains(bundleID) {
                return app.localizedName ?? bundleID
            }
        }
        return nil
    }

    struct TargetSize: Sendable {
        let targetID: String
        let bytes: Int64
        let existingPaths: [String]
    }

    func size(of target: PrivacyTarget) -> TargetSize {
        var total: Int64 = 0
        var existing: [String] = []
        for url in target.urls {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            guard CleanupPolicy.evaluatePrivacy(url).isAllowed else { continue }
            existing.append(url.path)
            var isDirectory: ObjCBool = false
            _ = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            total += isDirectory.boolValue
                ? fileManager.directorySize(at: url)
                : ((try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0)
        }
        return TargetSize(targetID: target.id, bytes: total, existingPaths: existing)
    }

    func clean(_ targets: [PrivacyTarget]) async -> (moved: [String], failures: [CleanupFailure], bytes: Int64) {
        var moved: [String] = []
        var failures: [CleanupFailure] = []
        var bytes: Int64 = 0

        for target in targets {
            for url in target.urls {
                guard fileManager.fileExists(atPath: url.path) else { continue }
                let decision = CleanupPolicy.evaluatePrivacy(url)
                guard decision.isAllowed else {
                    let reason = decision.reason ?? "安全策略拒绝"
                    AppLog.denied(url.path, reason: reason)
                    failures.append(CleanupFailure(path: url.path, reason: reason, isPolicyDenied: true))
                    continue
                }
                var isDirectory: ObjCBool = false
                _ = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
                let size = isDirectory.boolValue
                    ? fileManager.directorySize(at: url)
                    : ((try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0)
                do {
                    try fileManager.moveToTrash(url)
                    moved.append(url.path)
                    bytes += size
                } catch {
                    AppLog.failed(url.path, error: error.localizedDescription)
                    failures.append(CleanupFailure(path: url.path, reason: error.localizedDescription))
                }
            }
        }
        return (moved, failures, bytes)
    }
}
