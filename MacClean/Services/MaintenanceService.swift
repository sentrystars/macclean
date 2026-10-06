import Foundation
import os

/// 系统维护动作：不依赖用户逐项勾选的整体操作。
final class MaintenanceService: Sendable {

    private let cleanupService = CleanupService()
    private let privilegeService = PrivilegeService()
    private var fileManager: FileManager { .default }

    func perform(_ kind: MaintenanceKind, options: CleanupOptions) async -> MaintenanceResult {
        switch kind {
        case .flushDNS: return await flushDNS()
        case .thinTimeMachineSnapshots: return await thinTimeMachineSnapshots()
        case .deleteUnavailableSimulators: return await deleteUnavailableSimulators()
        case .emptyTrash: return await emptyTrash()
        case .purgeMemory: return await purgeMemory()
        case .rebuildSpotlightIndex: return await rebuildSpotlightIndex()
        }
    }

    // MARK: - DNS

    func flushDNS() async -> MaintenanceResult {
        var messages: [String] = []
        var succeeded = true
        if let result = try? await Process.run(executable: "/usr/bin/dscacheutil", arguments: ["-flushcache"], timeout: 30) {
            if !result.succeeded { succeeded = false; messages.append(result.combinedOutput) }
        } else {
            succeeded = false
        }
        if let result = try? await Process.run(executable: "/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"], timeout: 30) {
            if !result.succeeded { succeeded = false; messages.append(result.combinedOutput) }
        }
        return MaintenanceResult(
            kind: .flushDNS,
            succeeded: succeeded,
            message: succeeded ? "DNS 缓存已刷新" : messages.joined(separator: "\n")
        )
    }

    // MARK: - Time Machine 本地快照

    func thinTimeMachineSnapshots() async -> MaintenanceResult {
        guard await Process.commandExists("tmutil") else {
            return MaintenanceResult(kind: .thinTimeMachineSnapshots, succeeded: false, message: "未找到 tmutil")
        }

        let snapshotsBefore = await DiagnosticService().getTimeMachineSnapshots()
        guard !snapshotsBefore.isEmpty else {
            return MaintenanceResult(kind: .thinTimeMachineSnapshots, succeeded: true, message: "没有本地快照需要清理")
        }

        let freeBefore = fileManager.availableCapacity(for: URL(fileURLWithPath: "/"))?.free ?? 0
        let target = max(snapshotsBefore.count, 1) * 1_073_741_824
        let command = "/usr/bin/tmutil thinlocalsnapshots / \(target) 4"
        let outcome = await privilegeService.runPrivileged(command: command)

        switch outcome {
        case .cancelled:
            return MaintenanceResult(kind: .thinTimeMachineSnapshots, succeeded: false, message: "用户取消了授权")
        case .failed(let message):
            return MaintenanceResult(kind: .thinTimeMachineSnapshots, succeeded: false, message: message)
        case .succeeded:
            let freeAfter = fileManager.availableCapacity(for: URL(fileURLWithPath: "/"))?.free ?? freeBefore
            let freed = max(0, freeAfter - freeBefore)
            return MaintenanceResult(
                kind: .thinTimeMachineSnapshots,
                succeeded: true,
                message: "已清理本地快照",
                freedBytes: freed
            )
        }
    }

    // MARK: - iOS 模拟器

    func deleteUnavailableSimulators() async -> MaintenanceResult {
        guard await Process.commandExists("xcrun") else {
            return MaintenanceResult(kind: .deleteUnavailableSimulators, succeeded: false, message: "未找到 xcrun（需要安装 Xcode）")
        }
        let simulatorPath = URL(fileURLWithPath: CleanupPolicy.home(AppConstants.coreSimulator))
        let before = fileManager.directorySize(at: simulatorPath)
        do {
            let result = try await Process.run(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "delete", "unavailable"],
                timeout: 300
            )
            let after = fileManager.directorySize(at: simulatorPath)
            guard result.succeeded else {
                return MaintenanceResult(kind: .deleteUnavailableSimulators, succeeded: false, message: result.combinedOutput)
            }
            return MaintenanceResult(
                kind: .deleteUnavailableSimulators,
                succeeded: true,
                message: "已删除不可用的模拟器运行时",
                freedBytes: max(0, before - after)
            )
        } catch {
            return MaintenanceResult(kind: .deleteUnavailableSimulators, succeeded: false, message: error.localizedDescription)
        }
    }

    // MARK: - 废纸篓

    func emptyTrash() async -> MaintenanceResult {
        let result = await cleanupService.emptyTrash()
        let succeeded = result.errors.isEmpty
        return MaintenanceResult(
            kind: .emptyTrash,
            succeeded: succeeded,
            message: succeeded
                ? "已清空废纸篓（\(result.itemsRemoved) 项）"
                : result.errors.joined(separator: "\n"),
            freedBytes: result.bytesFreed
        )
    }

    // MARK: - 内存

    func purgeMemory() async -> MaintenanceResult {
        guard await Process.commandExists("purge") else {
            return MaintenanceResult(kind: .purgeMemory, succeeded: false, message: "未找到 purge 命令")
        }
        let outcome = await privilegeService.runPrivileged(command: "/usr/bin/purge")
        switch outcome {
        case .succeeded:
            return MaintenanceResult(kind: .purgeMemory, succeeded: true, message: "内存缓存已释放")
        case .cancelled:
            return MaintenanceResult(kind: .purgeMemory, succeeded: false, message: "用户取消了授权")
        case .failed(let message):
            return MaintenanceResult(kind: .purgeMemory, succeeded: false, message: message)
        }
    }

    // MARK: - Spotlight

    func rebuildSpotlightIndex() async -> MaintenanceResult {
        guard await Process.commandExists("mdutil") else {
            return MaintenanceResult(kind: .rebuildSpotlightIndex, succeeded: false, message: "未找到 mdutil")
        }
        let outcome = await privilegeService.runPrivileged(command: "/usr/bin/mdutil -E /")
        switch outcome {
        case .succeeded:
            return MaintenanceResult(kind: .rebuildSpotlightIndex, succeeded: true, message: "已开始重建 Spotlight 索引")
        case .cancelled:
            return MaintenanceResult(kind: .rebuildSpotlightIndex, succeeded: false, message: "用户取消了授权")
        case .failed(let message):
            return MaintenanceResult(kind: .rebuildSpotlightIndex, succeeded: false, message: message)
        }
    }

    // MARK: - 完全磁盘访问

    /// 探测是否已获得「完全磁盘访问」权限（TCC 数据库不可读即视为未授权）。
    func hasFullDiskAccess() -> Bool {
        let probe = URL(fileURLWithPath: CleanupPolicy.home("Library/Application Support/com.apple.TCC/TCC.db"))
        guard fileManager.fileExists(atPath: probe.path) else { return false }
        if (try? FileHandle(forReadingFrom: probe)) != nil { return true }
        return false
    }
}
