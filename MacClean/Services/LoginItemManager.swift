import Foundation

/// 启动项管理：读取 LaunchAgents / LaunchDaemons，并支持启停用户级启动项。
///
/// 出于安全考虑，本服务**不删除** /Library 下的启动项，只做只读展示与 Finder 定位；
/// 用户级启动项可以启停，也可以移入废纸篓。
final class LoginItemManager: Sendable {

    private var fileManager: FileManager { .default }

    static var userAgentDirectory: URL {
        URL(fileURLWithPath: CleanupPolicy.home("Library/LaunchAgents"))
    }

    static let globalAgentDirectory = URL(fileURLWithPath: "/Library/LaunchAgents")
    static let globalDaemonDirectory = URL(fileURLWithPath: "/Library/LaunchDaemons")

    func listItems() async -> [LoginItem] {
        let loadedLabels = await loadedLabels()
        var items: [LoginItem] = []

        items += readItems(in: Self.userAgentDirectory, scope: .userAgent, loaded: loadedLabels)
        items += readItems(in: Self.globalAgentDirectory, scope: .globalAgent, loaded: loadedLabels)
        items += readItems(in: Self.globalDaemonDirectory, scope: .globalDaemon, loaded: loadedLabels)

        return items.sorted {
            if $0.scope != $1.scope { return $0.scope.rawValue < $1.scope.rawValue }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    private func readItems(in directory: URL, scope: LoginItemScope, loaded: Set<String>) -> [LoginItem] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries.compactMap { url in
            guard url.pathExtension == "plist" else { return nil }
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { return nil }

            let label = (plist["Label"] as? String) ?? url.deletingPathExtension().lastPathComponent
            let program = (plist["Program"] as? String)
                ?? (plist["ProgramArguments"] as? [String])?.first
            let runAtLoad = (plist["RunAtLoad"] as? Bool) ?? false

            return LoginItem(
                plistURL: url,
                label: label,
                program: program,
                runAtLoad: runAtLoad,
                scope: scope,
                isLoaded: loaded.contains(label)
            )
        }
    }

    /// 一次性获取已加载的 label 集合，避免逐个 launchctl print。
    private func loadedLabels() async -> Set<String> {
        guard let result = try? await Process.run(
            executable: "/bin/launchctl",
            arguments: ["list"],
            timeout: 30
        ), result.succeeded else { return [] }

        var labels = Set<String>()
        for line in result.standardOutput.split(separator: "\n").dropFirst() {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            if parts.count >= 3 {
                labels.insert(String(parts[2]).trimmingCharacters(in: .whitespaces))
            }
        }
        return labels
    }

    /// 启停用户级启动项。
    func setEnabled(_ item: LoginItem, enabled: Bool) async -> Result<Void, Error> {
        guard item.canToggle else {
            return .failure(LaunchctlError.unsupported("全局/系统级启动项需要在「系统设置 → 通用 → 登录项」中管理"))
        }
        let domain = "gui/\(getuid())"
        do {
            if enabled {
                _ = try await Process.runChecked(executable: "/bin/launchctl", arguments: ["bootstrap", domain, item.plistURL.path], timeout: 30)
            } else {
                _ = try await Process.runChecked(executable: "/bin/launchctl", arguments: ["bootout", domain, item.plistURL.path], timeout: 30)
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// 删除用户级启动项（移入废纸篓，可恢复）。
    func remove(_ item: LoginItem) async -> Result<Void, Error> {
        guard item.scope == .userAgent else {
            return .failure(LaunchctlError.unsupported("出于安全考虑，暂不支持删除全局/系统级启动项"))
        }
        let decision = CleanupPolicy.evaluateAllowingUninstall(item.plistURL)
        guard decision.isAllowed else {
            return .failure(LaunchctlError.unsupported(decision.reason ?? "安全策略拒绝"))
        }
        do {
            try fileManager.moveToTrash(item.plistURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}

enum LaunchctlError: Error, LocalizedError {
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let message): return message
        }
    }
}
