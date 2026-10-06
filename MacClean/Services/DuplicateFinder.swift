import CryptoKit
import Foundation
import os

/// 重复文件查找。
///
/// 算法：按大小分桶 → 只对同尺寸的候选计算 SHA-256 → 哈希相同即判定重复。
/// 只扫描用户标准文件夹，并且只允许把结果**移入废纸篓**。
final class DuplicateFinder: Sendable {

    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)
    private var fileManager: FileManager { .default }

    func cancel() { cancelFlag.withLock { $0 = true } }
    func resetCancellation() { cancelFlag.withLock { $0 = false } }
    private var isCancelled: Bool { cancelFlag.withLock { $0 } }

    static var defaultRoots: [URL] {
        ["Downloads", "Documents", "Desktop", "Movies", "Music", "Pictures"]
            .map { URL(fileURLWithPath: CleanupPolicy.home($0)) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func findDuplicates(roots: [URL], minimumSize: Int64 = 1_048_576) -> AsyncStream<DuplicateGroup> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task.detached(priority: .utility) { [self] in
                resetCancellation()

                let buckets = collectCandidates(roots: roots, minimumSize: minimumSize)
                let candidates = buckets.values.filter { $0.count > 1 }.flatMap { $0 }

                var byHash: [String: [DuplicateFile]] = [:]
                for file in candidates {
                    if isCancelled { break }
                    guard let digest = Self.sha256(of: file.url) else { continue }
                    byHash[digest, default: []].append(file)
                }

                let groups = byHash
                    .filter { $0.value.count > 1 }
                    .map { key, value in
                        DuplicateGroup(
                            id: key,
                            sizeBytes: value[0].sizeBytes,
                            files: value.sorted { ($0.modified ?? .distantFuture) < ($1.modified ?? .distantFuture) }
                        )
                    }
                    .sorted { $0.wastedBytes > $1.wastedBytes }

                for group in groups {
                    if isCancelled { break }
                    continuation.yield(group)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// 收集候选文件（按大小分桶）。
    func collectCandidates(roots: [URL], minimumSize: Int64) -> [Int64: [DuplicateFile]] {
        var buckets: [Int64: [DuplicateFile]] = [:]

        for root in roots {
            if isCancelled { break }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                if isCancelled { return buckets }
                guard let values = try? url.resourceValues(forKeys: [
                    .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey,
                ]),
                    values.isRegularFile == true,
                    values.isSymbolicLink != true,
                    let size = values.fileSize,
                    Int64(size) >= minimumSize
                else { continue }

                guard CleanupPolicy.evaluateUserSelectedFile(url).isAllowed else { continue }

                buckets[Int64(size), default: []].append(DuplicateFile(
                    url: url,
                    sizeBytes: Int64(size),
                    modified: values.contentModificationDate
                ))
            }
        }
        return buckets
    }

    /// 流式计算 SHA-256，避免把大文件整体读入内存。
    static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            guard let chunk = try? handle.read(upToCount: 1_048_576), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// 把选中的重复文件移入废纸篓（可恢复）。
    func moveToTrash(_ urls: [URL]) async -> (moved: [String], failures: [CleanupFailure], bytes: Int64) {
        var moved: [String] = []
        var failures: [CleanupFailure] = []
        var bytes: Int64 = 0

        for url in urls {
            let decision = CleanupPolicy.evaluateUserSelectedFile(url)
            guard decision.isAllowed else {
                failures.append(CleanupFailure(path: url.path, reason: decision.reason ?? "安全策略拒绝", isPolicyDenied: true))
                continue
            }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            do {
                try fileManager.moveToTrash(url)
                moved.append(url.path)
                bytes += size
            } catch {
                AppLog.failed(url.path, error: error.localizedDescription)
                failures.append(CleanupFailure(path: url.path, reason: error.localizedDescription))
            }
        }
        return (moved, failures, bytes)
    }
}
