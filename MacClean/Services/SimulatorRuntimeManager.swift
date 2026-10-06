import Foundation
import os

/// 模拟器运行时（iOS/watchOS/tvOS/visionOS 磁盘镜像）管理。
///
/// 安全约束：
/// - 只通过 simctl 操作，不直接删文件；
/// - 删除前校验标识符为 UUID 形状，且必须存在于**刚刚重新拉取**的运行时列表中；
/// - 默认不主动提权；仅在明确是权限失败时，用已验证的路径与 UUID 走一次管理员授权。
final class SimulatorRuntimeManager: Sendable {

    private var fileManager: FileManager { .default }
    private let developerDirLock = OSAllocatedUnfairLock(initialState: String?.none)

    // MARK: - 工具链定位

    /// 候选 Developer 目录（xcrun/simctl 所在）。
    static func developerDirCandidates() -> [String] {
        var candidates: [String] = []
        if let env = ProcessInfo.processInfo.environment["DEVELOPER_DIR"], !env.isEmpty {
            candidates.append(env)
        }
        candidates.append("/Applications/Xcode.app/Contents/Developer")
        candidates.append("/Applications/Xcode-beta.app/Contents/Developer")
        if let apps = try? FileManager.default.contentsOfDirectory(atPath: "/Applications") {
            for app in apps where app.hasPrefix("Xcode") && app.hasSuffix(".app") {
                candidates.append("/Applications/\(app)/Contents/Developer")
            }
        }
        // 去重保序
        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    /// 找到可用的 simctl 及其 Developer 目录。
    func resolveToolchain() -> (simctl: String, developerDir: String)? {
        if let cached = developerDirLock.withLock({ $0 }) {
            let path = cached + "/usr/bin/simctl"
            if fileManager.isExecutableFile(atPath: path) { return (path, cached) }
        }
        for dir in Self.developerDirCandidates() {
            let path = dir + "/usr/bin/simctl"
            if fileManager.isExecutableFile(atPath: path) {
                developerDirLock.withLock { $0 = dir }
                return (path, dir)
            }
        }
        return nil
    }

    var isAvailable: Bool { resolveToolchain() != nil }

    private func run(_ arguments: [String], timeout: TimeInterval = 120) async throws -> CommandResult {
        guard let toolchain = resolveToolchain() else {
            throw SimulatorError.xcodeUnavailable
        }
        return try await Process.run(
            executable: toolchain.simctl,
            arguments: arguments,
            timeout: timeout,
            environment: ["DEVELOPER_DIR": toolchain.developerDir]
        )
    }

    // MARK: - 查询

    func listRuntimes() async -> [SimulatorRuntime] {
        guard let result = try? await run(["runtime", "list", "-j"], timeout: 90), result.succeeded else {
            return []
        }
        if let runtimes = try? SimulatorRuntimeParser.parse(json: Data(result.standardOutput.utf8)),
           !runtimes.isEmpty {
            return runtimes
        }
        // 兜底：文本格式
        if let textResult = try? await run(["runtime", "list"], timeout: 60) {
            return SimulatorRuntimeParser.parse(text: textResult.standardOutput)
        }
        return []
    }

    func deviceSummary() async -> SimulatorDeviceSummary {
        guard let result = try? await run(["list", "devices", "-j"], timeout: 90), result.succeeded,
              let root = try? JSONSerialization.jsonObject(with: Data(result.standardOutput.utf8)) as? [String: Any],
              let devices = root["devices"] as? [String: Any]
        else { return .empty }

        var total = 0
        var unavailable = 0
        var booted = 0
        for (_, value) in devices {
            guard let list = value as? [[String: Any]] else { continue }
            for device in list {
                total += 1
                if let availability = device["availability"] as? String,
                   availability.lowercased().contains("unavailable") {
                    unavailable += 1
                }
                if let state = device["state"] as? String, state.caseInsensitiveCompare("Booted") == .orderedSame {
                    booted += 1
                }
            }
        }
        return SimulatorDeviceSummary(total: total, unavailable: unavailable, booted: booted)
    }

    // MARK: - 删除

    /// 删除单个运行时（返回释放的字节数）。
    func deleteRuntime(_ runtime: SimulatorRuntime) async -> Result<Int64, Error> {
        guard SimulatorRuntimeParser.isSafeIdentifier(runtime.identifier) else {
            return .failure(SimulatorError.unknownRuntime(runtime.identifier))
        }
        // 必须仍然存在于最新列表中，避免拿陈旧/伪造的标识符执行命令
        let current = await listRuntimes()
        guard let fresh = current.first(where: { $0.identifier == runtime.identifier }) else {
            return .failure(SimulatorError.unknownRuntime(runtime.identifier))
        }
        guard fresh.isDeletable else {
            return .failure(SimulatorError.deleteFailed("该运行时不可删除（deletable = false）"))
        }

        do {
            let result = try await run(["runtime", "delete", runtime.identifier], timeout: 900)
            if result.succeeded {
                return .success(fresh.sizeBytes)
            }
            let message = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.looksLikePermissionFailure(message), let escalated = await deleteWithPrivileges(runtime.identifier) {
                return escalated
            }
            return .failure(SimulatorError.deleteFailed(message))
        } catch {
            return .failure(error)
        }
    }

    /// 清理不可用/已过期的运行时，返回释放字节数。
    func deleteUnusableOrOutdated() async -> Result<Int64, Error> {
        let before = await listRuntimes().reduce(Int64(0)) { $0 + $1.sizeBytes }
        do {
            let result = try await run(["runtime", "delete", "--unusable"], timeout: 900)
            guard result.succeeded else {
                return .failure(SimulatorError.deleteFailed(result.combinedOutput))
            }
            _ = try? await run(["runtime", "delete", "--outdated"], timeout: 900)
            let after = await listRuntimes().reduce(Int64(0)) { $0 + $1.sizeBytes }
            return .success(max(0, before - after))
        } catch {
            return .failure(error)
        }
    }

    /// 清理超过 N 天未使用的运行时，返回释放字节数。
    func deleteNotUsedSince(days: Int) async -> Result<Int64, Error> {
        let before = await listRuntimes().reduce(Int64(0)) { $0 + $1.sizeBytes }
        do {
            let result = try await run(["runtime", "delete", "--notUsedSinceDays", String(max(1, days))], timeout: 900)
            guard result.succeeded else {
                return .failure(SimulatorError.deleteFailed(result.combinedOutput))
            }
            let after = await listRuntimes().reduce(Int64(0)) { $0 + $1.sizeBytes }
            return .success(max(0, before - after))
        } catch {
            return .failure(error)
        }
    }

    private func deleteWithPrivileges(_ identifier: String) async -> Result<Int64, Error>? {
        guard SimulatorRuntimeParser.isSafeIdentifier(identifier),
              let toolchain = resolveToolchain()
        else { return nil }

        let command = "DEVELOPER_DIR=\"" + toolchain.developerDir + "\" \"" + toolchain.simctl
            + "\" runtime delete " + identifier
        let outcome = await PrivilegeService().runPrivileged(command: command)
        switch outcome {
        case .succeeded:
            return .success(0)
        case .cancelled:
            return .failure(SimulatorError.deleteFailed("已取消管理员授权"))
        case .failed(let message):
            return .failure(SimulatorError.deleteFailed(message))
        }
    }

    private static func looksLikePermissionFailure(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("permission denied")
            || lowered.contains("operation not permitted")
            || lowered.contains("not authorized")
            || lowered.contains("must be run as root")
    }
}
