import Foundation

/// 一次特权批量删除的结果。
struct PrivilegedBatchResult: Sendable {
    let removedPaths: [String]
    let freedBytes: Int64
    let failures: [CleanupFailure]
    let cancelled: Bool

    static let empty = PrivilegedBatchResult(removedPaths: [], freedBytes: 0, failures: [], cancelled: false)
}

/// 特权操作服务。
///
/// 安全要点：
/// - 路径先过 CleanupPolicy，再写入一个 0600 权限的 NUL 分隔清单文件；
/// - 交给 root 的 shell 命令是**常量字符串**，只包含清单文件路径（UUID 生成），
///   因此不存在路径拼接到 shell 造成的命令注入；
/// - 每次批量操作只弹一次授权框。
final class PrivilegeService: Sendable {

    private var fileManager: FileManager { .default }

    /// 批量删除需要管理员权限的条目。
    func removeItems(_ items: [ScanItem], options: CleanupOptions) async -> PrivilegedBatchResult {
        var accepted: [ScanItem] = []
        var failures: [CleanupFailure] = []

        for item in items {
            let decision = CleanupPolicy.evaluateForCleanup(item.url, category: item.category)
            guard decision.isAllowed else {
                let reason = decision.reason ?? "安全策略拒绝"
                AppLog.denied(item.url.path, reason: reason)
                failures.append(CleanupFailure(path: item.url.path, reason: reason, isPolicyDenied: true))
                continue
            }
            guard item.isRemovable else {
                failures.append(CleanupFailure(
                    path: item.url.path,
                    reason: item.notRemovableReason ?? "标记为不可删除",
                    isPolicyDenied: true
                ))
                continue
            }
            accepted.append(item)
        }

        guard !accepted.isEmpty else {
            return PrivilegedBatchResult(removedPaths: [], freedBytes: 0, failures: failures, cancelled: false)
        }

        let listURL = fileManager.temporaryDirectory
            .appendingPathComponent("macclean-" + UUID().uuidString + ".list")

        var payload = Data()
        for item in accepted {
            payload.append(Data(item.url.path.utf8))
            payload.append(0)
        }

        guard fileManager.createFile(
            atPath: listURL.path,
            contents: payload,
            attributes: [.posixPermissions: 0o600]
        ) else {
            let failure = CleanupFailure(path: listURL.path, reason: "无法创建特权清理清单文件")
            return PrivilegedBatchResult(removedPaths: [], freedBytes: 0, failures: failures + [failure], cancelled: false)
        }
        defer { try? fileManager.removeItem(at: listURL) }

        // 常量命令 + 仅含 UUID 的清单路径，无路径拼接。
        let command = "/usr/bin/xargs -0 -n 64 /bin/rm -rf -- < " + listURL.path
        let outcome = await runPrivileged(command: command)

        switch outcome {
        case .cancelled:
            return PrivilegedBatchResult(removedPaths: [], freedBytes: 0, failures: failures, cancelled: true)
        case .failed(let message):
            failures.append(CleanupFailure(path: "特权清理", reason: message))
            return PrivilegedBatchResult(removedPaths: [], freedBytes: 0, failures: failures, cancelled: false)
        case .succeeded:
            var removed: [String] = []
            var freed: Int64 = 0
            for item in accepted {
                if fileManager.fileExists(atPath: item.url.path) {
                    failures.append(CleanupFailure(path: item.url.path, reason: "特权删除后文件仍然存在"))
                } else {
                    removed.append(item.url.path)
                    freed += item.sizeBytes
                }
            }
            return PrivilegedBatchResult(removedPaths: removed, freedBytes: freed, failures: failures, cancelled: false)
        }
    }

    enum PrivilegedOutcome: Sendable {
        case succeeded
        case cancelled
        case failed(String)
    }

    /// 以管理员权限执行一段**由本 App 常量拼接**的 shell 命令。
    func runPrivileged(command: String) async -> PrivilegedOutcome {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"" + escaped + "\" with administrator privileges"

        do {
            let result = try await Process.run(
                executable: "/usr/bin/osascript",
                arguments: ["-e", script],
                timeout: 600
            )
            if result.succeeded { return .succeeded }
            let message = result.combinedOutput
            if message.contains("User canceled") || message.contains("(-128)") {
                return .cancelled
            }
            AppLog.privileged.error("privileged command failed: \(message, privacy: .public)")
            return .failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// 是否已经具备管理员权限（sudo -n 探测）。
    func hasAdministratorRights() async -> Bool {
        guard let result = try? await Process.run(
            executable: "/usr/bin/sudo",
            arguments: ["-n", "true"],
            timeout: 10
        ) else { return false }
        return result.succeeded
    }
}