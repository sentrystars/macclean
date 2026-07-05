import Foundation

actor DiagnosticService {
    private let fileManager = FileManager.default

    // MARK: - Disk Info
    func getStorageInfo() async throws -> StorageInfo {
        let home = NSHomeDirectory()
        let attrs = try fileManager.attributesOfFileSystem(forPath: home)

        let total = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        let used = total - free

        let trashBytes = fileManager.trashSize()
        let cacheBytes = await scanCacheSizes()

        return StorageInfo(
            totalBytes: total,
            usedBytes: used,
            freeBytes: free,
            trashBytes: trashBytes,
            cacheBytes: cacheBytes
        )
    }

    // MARK: - Time Machine Snapshots
    func getTimeMachineSnapshots() async throws -> [TimeMachineSnapshot] {
        guard Process.commandExists("tmutil") else { return [] }

        let output = try? await Process.runAsync(executable: "/usr/bin/tmutil", arguments: ["listlocalsnapshots", "/"])
        guard let output else { return [] }

        let lines = output.split(separator: "\n").filter { $0.contains("com.apple.TimeMachine") }
        return parseTimeMachineSnapshots(from: lines)
    }

    private nonisolated func parseTimeMachineSnapshots(from lines: [Substring]) -> [TimeMachineSnapshot] {
        var snapshots: [TimeMachineSnapshot] = []
        for line in lines {
            let parts = line.split(separator: ".")
            guard let dateStr = parts.last.map(String.init) else { continue }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let date = formatter.date(from: dateStr) ?? Date()
            snapshots.append(TimeMachineSnapshot(id: String(line), date: date, volume: "/", sizeBytes: nil))
        }
        return snapshots
    }

    // MARK: - Large Directories
    func getLargeDirectories(under path: URL, count: Int = 20) -> AsyncStream<ScanItem> {
        AsyncStream { continuation in
            Task {
                let dirs = self.scanLargeDirectories(at: path)
                for dir in dirs.prefix(count) {
                    let item = ScanItem(
                        url: dir.url,
                        category: .userCaches,
                        sizeBytes: dir.size,
                        isDirectory: true
                    )
                    continuation.yield(item)
                }
                continuation.finish()
            }
        }
    }

    private nonisolated func scanLargeDirectories(at path: URL) -> [(url: URL, size: Int64)] {
        guard let enumerator = FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var dirSizes: [URL: Int64] = [:]
        let baseComponents = path.pathComponents.count

        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            else { continue }

            if resourceValues.isDirectory == true { continue }

            // Add file size to all parent directories
            if let fileSize = resourceValues.fileSize {
                var parentURL = fileURL.deletingLastPathComponent()
                while parentURL.pathComponents.count > baseComponents {
                    dirSizes[parentURL, default: 0] += Int64(fileSize)
                    parentURL = parentURL.deletingLastPathComponent()
                }
            }
        }

        let result = dirSizes.map { ($0.key, $0.value) }
            .filter { $0.1 >= 50_000_000 } // >= 50MB
            .sorted { $0.1 > $1.1 }

        return result
    }

    // MARK: - App Storage Breakdown
    func getAppStorageBreakdown() -> AsyncStream<ScanItem> {
        AsyncStream { continuation in
            Task {
                let appSupportPath = URL.homeDirectory
                    .appendingPathComponent("Library")
                    .appendingPathComponent("Application Support")

                let apps = self.scanAppSupportDirectories(at: appSupportPath)
                for app in apps.prefix(20) {
                    let item = ScanItem(
                        url: app.url,
                        category: .appCaches,
                        subcategory: app.url.lastPathComponent,
                        sizeBytes: app.size,
                        isDirectory: true
                    )
                    continuation.yield(item)
                }
                continuation.finish()
            }
        }
    }

    private nonisolated func scanAppSupportDirectories(at path: URL) -> [(url: URL, size: Int64)] {
        guard let enumerator = FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let topLevelCount = path.pathComponents.count + 1
        var dirSizes: [URL: Int64] = [:]

        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            else { continue }

            // Top-level apps (directories at depth + 1 from path)
            if resourceValues.isDirectory == true, fileURL.pathComponents.count == topLevelCount {
                let size = FileManager.default.directorySize(at: fileURL)
                if size > 50_000_000 {
                    dirSizes[fileURL] = size
                }
            }
        }

        return dirSizes.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: - Private Helpers
    private func scanCacheSizes() async -> Int64 {
        let cachePath = URL.homeDirectory.appendingPathComponent("Library/Caches")
        guard fileManager.fileExists(atPath: cachePath.path) else { return 0 }
        return fileManager.directorySize(at: cachePath)
    }
}

enum DiagnosticError: Error, LocalizedError {
    case parseFailed
    case commandNotFound(String)

    var errorDescription: String? {
        switch self {
        case .parseFailed: return "Failed to parse disk information"
        case .commandNotFound(let cmd): return "Command not found: \(cmd)"
        }
    }
}
