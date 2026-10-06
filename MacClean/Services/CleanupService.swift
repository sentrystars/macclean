import Foundation
import os

/// 清理服务。
///
/// 与旧实现的关键差异：
/// - 不再把失败计入成功；失败/被拒条目会完整回传给 UI；
/// - 删除前统一过 CleanupPolicy，拒绝的路径不会被删除，并给出原因；
/// - Claude VM 的 .zst 守卫移到删除入口，无法被绕过；
/// - 特权条目批量处理，只弹一次授权；
/// - 结束后返回按分类聚合的 CleanupSummary，避免上层重复计数或错标分类。
final class CleanupService: Sendable {

    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)
    func cancel() { cancelFlag.withLock { $0 = true } }
    func reset() { cancelFlag.withLock { $0 = false } }
    private var isCancelled: Bool { cancelFlag.withLock { $0 } }

    private var fileManager: FileManager { .default }
    private let privilegeService = PrivilegeService()

    // MARK: - 清理

    func clean(items: [ScanItem], options: CleanupOptions) -> AsyncStream<CleanupEvent> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task.detached(priority: .userInitiated) { [self] in
                let summary = await performClean(items: items, options: options) { event in
                    continuation.yield(event)
                }
                continuation.yield(.finished(summary))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func performClean(
        items: [ScanItem],
        options: CleanupOptions,
        emit: @Sendable (CleanupEvent) -> Void
    ) async -> CleanupSummary {
        let started = Date()
        let total = items.count
        var processed = 0
        var bytesFreed: Int64 = 0
        var tally: [CleanupCategory: (bytes: Int64, count: Int)] = [:]
        var failures: [CleanupFailure] = []
        var privilegedQueue: [ScanItem] = []

        func report(_ phase: String, _ current: String) {
            emit(.progress(CleanProgress(
                phase: phase,
                currentItem: current,
                itemsCleaned: processed,
                totalItems: total,
                bytesFreed: bytesFreed,
                failures: Array(failures.suffix(30))
            )))
        }

        report("准备清理…", "")

        for item in items {
            if isCancelled { break }
            processed += 1
            report("清理 " + item.displayName, item.displayName)

            if options.isExcluded(item.url) {
                failures.append(CleanupFailure(path: item.url.path, reason: "位于排除列表中", isPolicyDenied: true))
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

            let decision = CleanupPolicy.evaluate(item.url)
            guard decision.isAllowed else {
                let reason = decision.reason ?? "安全策略拒绝"
                AppLog.denied(item.url.path, reason: reason)
                failures.append(CleanupFailure(path: item.url.path, reason: reason, isPolicyDenied: true))
                continue
            }

            // Claude VM：只有在存在 .zst 压缩备份时才允许删除 rootfs.img
            if item.category == .claudeVM, item.url.lastPathComponent == "rootfs.img" {
                let backup = item.url.deletingLastPathComponent().appendingPathComponent("rootfs.img.zst")
                guard fileManager.fileExists(atPath: backup.path) else {
                    failures.append(CleanupFailure(
                        path: item.url.path,
                        reason: "缺少 rootfs.img.zst 备份，已跳过",
                        isPolicyDenied: true
                    ))
                    continue
                }
            }

            if decision.requiresPrivilege {
                privilegedQueue.append(item)
                continue
            }

            guard fileManager.fileExists(atPath: item.url.path) else {
                failures.append(CleanupFailure(path: item.url.path, reason: "项目已不存在"))
                continue
            }

            do {
                if options.recycleInsteadOfDelete {
                    try fileManager.moveToTrash(item.url)
                } else {
                    try fileManager.removeItem(at: item.url)
                }
                let stillExists = fileManager.fileExists(atPath: item.url.path)
                let freed = stillExists ? 0 : item.sizeBytes
                bytesFreed += freed
                var entry = tally[item.category, default: (bytes: 0, count: 0)]
                entry.bytes += freed
                entry.count += 1
                tally[item.category] = entry
            } catch {
                AppLog.failed(item.url.path, error: error.localizedDescription)
                failures.append(CleanupFailure(path: item.url.path, reason: error.localizedDescription))
            }
        }

        // 特权条目：批量、单次授权
        if !privilegedQueue.isEmpty && !isCancelled {
            report("请求管理员权限以清理系统文件…", "")
            let result = await privilegeService.removeItems(privilegedQueue, options: options)
            bytesFreed += result.freedBytes
            failures.append(contentsOf: result.failures)
            if result.cancelled {
                failures.append(CleanupFailure(path: "特权清理", reason: "用户取消了授权", isPolicyDenied: true))
            }
            for path in result.removedPaths {
                guard let item = privilegedQueue.first(where: { $0.url.path == path }) else { continue }
                var entry = tally[item.category, default: (bytes: 0, count: 0)]
                entry.bytes += item.sizeBytes
                entry.count += 1
                tally[item.category] = entry
            }
        }

        let results = tally
            .map { CleanupResult(category: $0.key, bytesFreed: $0.value.bytes, itemsRemoved: $0.value.count) }
            .sorted { $0.bytesFreed > $1.bytesFreed }

        let summary = CleanupSummary(
            results: results,
            failures: failures,
            freedBytes: bytesFreed,
            removedItems: tally.values.reduce(0) { $0 + $1.count },
            duration: Date().timeIntervalSince(started)
        )

        AppLog.cleanup.notice(
            "cleanup finished freed=\(bytesFreed) removed=\(summary.removedItems) failures=\(failures.count)"
        )
        return summary
    }

    // MARK: - 废纸篓

    /// 清空废纸篓内容（绝不删除 .Trash 目录本身）。
    func emptyTrash() async -> CleanupResult {
        let started = Date()
        let trash = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: CleanupPolicy.home(AppConstants.trashPath))

        guard fileManager.fileExists(atPath: trash.path),
              let contents = try? fileManager.contentsOfDirectory(
                at: trash,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: []
              )
        else {
            return CleanupResult(category: .trash, bytesFreed: 0, itemsRemoved: 0)
        }

        var freed: Int64 = 0
        var removed = 0
        var errors: [String] = []

        for url in contents {
            if isCancelled { break }
            let decision = CleanupPolicy.evaluate(url)
            guard decision.isAllowed else {
                errors.append(url.lastPathComponent + "：" + (decision.reason ?? "安全策略拒绝"))
                continue
            }
            let size = sizeOf(url)
            do {
                try fileManager.removeItem(at: url)
                freed += size
                removed += 1
            } catch {
                errors.append(url.lastPathComponent + "：" + error.localizedDescription)
            }
        }

        return CleanupResult(
            category: .trash,
            bytesFreed: freed,
            itemsRemoved: removed,
            errors: errors,
            duration: Date().timeIntervalSince(started)
        )
    }

    private func sizeOf(_ url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if isDirectory.boolValue {
            return fileManager.directorySize(at: url, skipPackageDescendants: false)
        }
        return (try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
    }
}
