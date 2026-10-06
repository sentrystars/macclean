import Foundation

/// 磁盘诊断：容量、快照、大目录、大文件。
final class DiagnosticService: Sendable {

    private var fileManager: FileManager { .default }

    // MARK: - 磁盘容量

    func getStorageInfo() async throws -> StorageInfo {
        let home = URL.homeDirectory
        guard let capacity = fileManager.availableCapacity(for: home) else {
            throw DiagnosticError.capacityUnavailable
        }

        // 并行统计废纸篓与缓存，避免串行叠加耗时
        async let trashBytes = Task.detached(priority: .utility) { [fileManager] in
            fileManager.trashSize()
        }.value
        async let cacheBytes = Task.detached(priority: .utility) { [fileManager] in
            let caches = URL(fileURLWithPath: CleanupPolicy.home("Library/Caches"))
            return fileManager.fileExists(atPath: caches.path) ? fileManager.directorySize(at: caches) : 0
        }.value

        let used = max(0, capacity.total - capacity.free)
        return StorageInfo(
            totalBytes: capacity.total,
            usedBytes: used,
            freeBytes: capacity.free,
            trashBytes: await trashBytes,
            cacheBytes: await cacheBytes
        )
    }

    // MARK: - 卷

    /// 所有可浏览的已挂载卷（含外置盘）。
    func getVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
            .volumeIsBrowsableKey,
        ]
        let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url -> VolumeInfo? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            guard values.volumeIsBrowsable != false else { return nil }
            let total = Int64(values.volumeTotalCapacity ?? 0)
            guard total > 0 else { return nil }
            let free = values.volumeAvailableCapacityForImportantUsage
                ?? Int64(values.volumeAvailableCapacity ?? 0)
            return VolumeInfo(
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                totalBytes: total,
                freeBytes: free,
                isRemovable: values.volumeIsRemovable ?? false,
                isInternal: values.volumeIsInternal ?? false
            )
        }
        .sorted { $0.totalBytes > $1.totalBytes }
    }

    // MARK: - Time Machine 快照

    func getTimeMachineSnapshots() async -> [TimeMachineSnapshot] {
        guard await Process.commandExists("tmutil") else { return [] }
        guard let result = try? await Process.run(
            executable: "/usr/bin/tmutil",
            arguments: ["listlocalsnapshots", "/"],
            timeout: 60
        ) else { return [] }
        return Self.parseTimeMachineSnapshots(result.standardOutput)
    }

    /// 解析 tmutil 输出。形如：com.apple.TimeMachine.2024-01-01-123456.local
    static func parseTimeMachineSnapshots(_ output: String) -> [TimeMachineSnapshot] {
        output.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.contains("com.apple.TimeMachine") else { return nil }

            var parts = line.components(separatedBy: ".")
            // 去掉结尾的 .local / .backup 等后缀
            if let last = parts.last, ["local", "backup", "com"].contains(last.lowercased()) {
                parts.removeLast()
            }
            guard let stamp = parts.last else { return nil }

            let date = Self.snapshotFormatter.date(from: stamp)
            return TimeMachineSnapshot(
                id: line,
                date: date ?? Date.distantPast,
                volume: "/",
                sizeBytes: nil
            )
        }
    }

    private static let snapshotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    // MARK: - 大目录

    func getLargeDirectories(under path: URL, minimumSize: Int64 = 50_000_000, count: Int = 20, entryLimit: Int = 500_000) -> AsyncStream<ScanItem> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                let directories = Self.scanLargeDirectories(at: path, minimumSize: minimumSize, entryLimit: entryLimit)
                for entry in directories.prefix(count) {
                    continuation.yield(ScanItem(
                        url: entry.url,
                        category: .userCaches,
                        subcategory: entry.url.lastPathComponent,
                        sizeBytes: entry.size,
                        isDirectory: true,
                        isSelected: false,
                        riskLevel: .caution
                    ))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func scanLargeDirectories(at path: URL, minimumSize: Int64, entryLimit: Int = 500_000) -> [(url: URL, size: Int64)] {
        guard let enumerator = FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var directorySizes: [String: Int64] = [:]
        var urls: [String: URL] = [:]
        let baseDepth = path.pathComponents.count
        var visited = 0

        while let fileURL = enumerator.nextObject() as? URL {
            visited += 1
            if visited > entryLimit { break }
            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let fileSize = values.fileSize
            else { continue }

            var parent = fileURL.deletingLastPathComponent()
            var chain: [String] = []
            while parent.pathComponents.count > baseDepth {
                let key = parent.path
                chain.append(key)
                parent = parent.deletingLastPathComponent()
            }
            // 顶层目录只统计一次链，避免 O(n²) 的重复删除组件计算
            for key in chain {
                directorySizes[key, default: 0] += Int64(fileSize)
                if urls[key] == nil { urls[key] = URL(fileURLWithPath: key) }
            }
        }

        return directorySizes
            .filter { $0.value >= minimumSize }
            .sorted { $0.value > $1.value }
            .compactMap { key, size in
                guard let url = urls[key] else { return nil }
                return (url, size)
            }
    }

    // MARK: - 大文件

    func getLargeFiles(minimumSize: Int64, limit: Int = 200) -> AsyncStream<ScanItem> {
        let roots = AppConstants.largeFileSearchPaths.map { URL(fileURLWithPath: CleanupPolicy.home($0)) }
        return ScanService().scanLargeFiles(under: roots, minimumSize: minimumSize, limit: limit)
    }

    // MARK: - 应用占用

    func getAppStorageBreakdown(minimumSize: Int64 = 50_000_000, count: Int = 20) -> AsyncStream<ScanItem> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                let support = URL.homeDirectory
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Application Support")
                guard let children = try? FileManager.default.contentsOfDirectory(
                    at: support,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    continuation.finish()
                    return
                }

                var results: [(url: URL, size: Int64)] = []
                for child in children {
                    guard (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                    let size = FileManager.default.directorySize(at: child)
                    if size >= minimumSize {
                        results.append((child, size))
                    }
                }

                for entry in results.sorted(by: { $0.size > $1.size }).prefix(count) {
                    continuation.yield(ScanItem(
                        url: entry.url,
                        category: .appCaches,
                        subcategory: entry.url.lastPathComponent,
                        sizeBytes: entry.size,
                        isDirectory: true,
                        isSelected: false,
                        riskLevel: .caution
                    ))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum DiagnosticError: Error, LocalizedError {
    case capacityUnavailable

    var errorDescription: String? {
        switch self {
        case .capacityUnavailable: return "无法读取磁盘容量信息"
        }
    }
}