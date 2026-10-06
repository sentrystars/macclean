import Foundation
import os

/// 应用卸载器。
///
/// 安全约束：
/// - 只扫描 /Applications 与 ~/Applications，且只处理非 com.apple.* 的应用；
/// - 一律**移到废纸篓**（可恢复），不做永久删除；
/// - 关联文件只在固定的一批用户级目录中按 bundle id / 应用名精确匹配，不做模糊匹配。
final class AppUninstaller: Sendable {

    private var fileManager: FileManager { .default }
    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)

    func cancel() { cancelFlag.withLock { $0 = true } }
    func resetCancellation() { cancelFlag.withLock { $0 = false } }
    private var isCancelled: Bool { cancelFlag.withLock { $0 } }

    // MARK: - 扫描

    func scanInstalledApps() -> AsyncStream<InstalledApp> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task.detached(priority: .userInitiated) { [self] in
                resetCancellation()
                for root in Self.applicationRoots {
                    guard let entries = try? FileManager.default.contentsOfDirectory(
                        at: root,
                        includingPropertiesForKeys: [.isDirectoryKey, .contentAccessDateKey],
                        options: [.skipsHiddenFiles]
                    ) else { continue }

                    for entry in entries {
                        if isCancelled { break }
                        guard entry.pathExtension == "app" else { continue }
                        guard let app = makeApp(from: entry) else { continue }
                        continuation.yield(app)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static var applicationRoots: [URL] {
        var roots = [URL(fileURLWithPath: "/Applications")]
        roots.append(URL.homeDirectory.appendingPathComponent("Applications"))
        return roots.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func makeApp(from bundleURL: URL) -> InstalledApp? {
        let bundle = Bundle(url: bundleURL)
        let info = bundle?.infoDictionary
        let bundleID = bundle?.bundleIdentifier
        let name = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let version = info?["CFBundleShortVersionString"] as? String
        let lastUsed = try? bundleURL.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate

        return InstalledApp(
            bundleURL: bundleURL,
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            sizeBytes: fileManager.directorySize(at: bundleURL),
            lastUsed: lastUsed,
            associatedFiles: []
        )
    }

    // MARK: - 关联文件

    /// 候选关联路径（相对用户主目录）。纯函数，便于测试。
    static func candidateRelativePaths(bundleIdentifier: String?, appName: String) -> [String] {
        var paths: [String] = []
        let identifiers = [bundleIdentifier, appName].compactMap { $0 }.filter { !$0.isEmpty }

        for identifier in identifiers {
            paths.append("Library/Application Support/\(identifier)")
            paths.append("Library/Caches/\(identifier)")
            paths.append("Library/Logs/\(identifier)")
        }
        if let bundleIdentifier {
            paths.append("Library/Preferences/\(bundleIdentifier).plist")
            paths.append("Library/Containers/\(bundleIdentifier)")
            paths.append("Library/Group Containers/\(bundleIdentifier)")
            paths.append("Library/Saved Application State/\(bundleIdentifier).savedState")
            paths.append("Library/WebKit/\(bundleIdentifier)")
            paths.append("Library/HTTPStorages/\(bundleIdentifier)")
            paths.append("Library/Application Scripts/\(bundleIdentifier)")
            paths.append("Library/LaunchAgents/\(bundleIdentifier).plist")
        }
        return Array(Set(paths)).sorted()
    }

    func associatedFiles(for app: InstalledApp) -> [AssociatedFile] {
        var results: [AssociatedFile] = []
        for relative in Self.candidateRelativePaths(bundleIdentifier: app.bundleIdentifier, appName: app.name) {
            let url = URL(fileURLWithPath: CleanupPolicy.home(relative))
            guard fileManager.fileExists(atPath: url.path) else { continue }
            guard !CleanupPolicy.isSymbolicLink(url) else { continue }
            let size = CleanupPolicy.evaluateAllowingUninstall(url).isAllowed
                ? sizeOf(url)
                : 0
            results.append(AssociatedFile(url: url, kind: Self.kind(for: relative), sizeBytes: size))
        }

        // LaunchAgents 里以 bundle id 开头的其它 plist
        if let bundleIdentifier = app.bundleIdentifier {
            let launchAgents = URL(fileURLWithPath: CleanupPolicy.home("Library/LaunchAgents"))
            if let entries = try? fileManager.contentsOfDirectory(at: launchAgents, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for entry in entries where entry.lastPathComponent.hasPrefix(bundleIdentifier) {
                    if results.contains(where: { $0.url == entry }) { continue }
                    results.append(AssociatedFile(url: entry, kind: "启动项", sizeBytes: sizeOf(entry)))
                }
            }
        }

        return results.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private static func kind(for relative: String) -> String {
        if relative.contains("Application Support") { return "支持文件" }
        if relative.contains("Caches") { return "缓存" }
        if relative.contains("Preferences") { return "偏好设置" }
        if relative.contains("Logs") { return "日志" }
        if relative.contains("Containers") { return "容器" }
        if relative.contains("Saved Application State") { return "窗口状态" }
        if relative.contains("WebKit") { return "网页数据" }
        if relative.contains("HTTPStorages") { return "网络存储" }
        if relative.contains("Application Scripts") { return "应用脚本" }
        if relative.contains("LaunchAgents") { return "启动项" }
        return "关联文件"
    }

    private func sizeOf(_ url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if isDirectory.boolValue {
            return fileManager.directorySize(at: url, skipPackageDescendants: true)
        }
        return (try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
    }

    // MARK: - 卸载

    /// 卸载：应用包 + 选中的关联文件，全部移入废纸篓。
    func uninstall(_ app: InstalledApp, associatedURLs: [URL]) async -> UninstallResult {
        var moved: [String] = []
        var failures: [CleanupFailure] = []
        var freed: Int64 = 0

        guard !app.isSystemApp else {
            return UninstallResult(
                appName: app.name,
                movedToTrash: [],
                failures: [CleanupFailure(path: app.bundleURL.path, reason: "系统自带应用不支持卸载", isPolicyDenied: true)],
                freedBytes: 0
            )
        }

        var targets: [(URL, Int64)] = [(app.bundleURL, app.sizeBytes)]
        let associatedSet = Set(associatedURLs.map(\.path))
        for file in app.associatedFiles where associatedSet.contains(file.url.path) {
            targets.append((file.url, file.sizeBytes))
        }

        for (url, size) in targets {
            if isCancelled { break }
            let decision = CleanupPolicy.evaluateAllowingUninstall(url)
            guard decision.isAllowed else {
                let reason = decision.reason ?? "安全策略拒绝"
                AppLog.denied(url.path, reason: reason)
                failures.append(CleanupFailure(path: url.path, reason: reason, isPolicyDenied: true))
                continue
            }
            do {
                try fileManager.moveToTrash(url)
                moved.append(url.path)
                freed += size
            } catch {
                AppLog.failed(url.path, error: error.localizedDescription)
                failures.append(CleanupFailure(path: url.path, reason: error.localizedDescription))
            }
        }

        AppLog.cleanup.notice("uninstall \(app.name, privacy: .public) moved=\(moved.count) failures=\(failures.count)")
        return UninstallResult(appName: app.name, movedToTrash: moved, failures: failures, freedBytes: freed)
    }
}
