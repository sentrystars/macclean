import Foundation

extension FileManager {
    /// 递归计算目录大小。
    ///
    /// 枚举器在权限不足时不会返回 nil，而是产出空结果，因此额外在
    /// 「目录非空但统计为 0」时回退到 du，避免把可清理项误判为 0 字节。
    func directorySize(at url: URL, skipPackageDescendants: Bool = true) -> Int64 {
        var options: DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if skipPackageDescendants {
            options.insert(.skipsPackageDescendants)
        }

        if let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .totalFileAllocatedSizeKey],
            options: options
        ) {
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      values.isRegularFile == true
                else { continue }
                total += Int64(values.fileSize ?? 0)
            }
            if total > 0 {
                return total
            }
        }

        // 回退：du（可处理部分权限受限场景）
        return duSize(at: url)
    }

    private func duSize(at url: URL) -> Int64 {
        guard let attributes = try? attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeDirectory
        else { return 0 }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return 0
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8),
              let kilobytes = Int64(output.trimmingCharacters(in: .whitespacesAndNewlines)
                  .components(separatedBy: "\t").first ?? "0")
        else { return 0 }
        return kilobytes * 1024
    }

    /// 删除到废纸篓（可恢复）。
    func moveToTrash(_ url: URL) throws {
        var resultingURL: NSURL?
        try trashItem(at: url, resultingItemURL: &resultingURL)
    }

    /// 可用空间（与 Finder 口径一致的 purgeable-aware 数值）。
    func availableCapacity(for url: URL) -> (total: Int64, free: Int64)? {
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ]) else { return nil }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        guard total > 0 else { return nil }
        return (total, free)
    }

    func trashSize() -> Int64 {
        let trashURL = urls(for: .trashDirectory, in: .userDomainMask).first
            ?? URL.homeDirectory.appendingPathComponent(".Trash")
        guard fileExists(atPath: trashURL.path) else { return 0 }
        // 废纸篓中的 app 包也必须完整统计
        return directorySize(at: trashURL, skipPackageDescendants: false)
    }

    func applicationSupportPath(for appName: String) -> URL {
        URL.homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent(appName)
    }
}
