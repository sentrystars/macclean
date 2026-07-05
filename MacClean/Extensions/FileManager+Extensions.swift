import Foundation

extension FileManager {
    func directorySize(at url: URL, skipPackageDescendants: Bool = true) -> Int64 {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if skipPackageDescendants {
            options.insert(.skipsPackageDescendants)
        }

        // Primary: FileManager enumeration
        if let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: options
        ) {
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      resourceValues.isRegularFile == true,
                      let fileSize = resourceValues.fileSize
                else { continue }
                total += Int64(fileSize)
            }
            return total
        }

        // Fallback: use du command for system paths with permission issues
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        task.arguments = ["-sk", url.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8),
           let kbSize = Int64(output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t").first ?? "0") {
            return kbSize * 1024
        }
        return 0
    }

    func safeRemoveItem(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }

    func trashSize() -> Int64 {
        // Use the proper macOS API to find the Trash directory
        let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? URL.homeDirectory.appendingPathComponent(".Trash")
        guard fileExists(atPath: trashURL.path) else { return 0 }
        // Trash must NOT skip package descendants — app bundles need full enumeration
        return directorySize(at: trashURL, skipPackageDescendants: false)
    }

    func applicationSupportPath(for appName: String) -> URL {
        URL.homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent(appName)
    }
}
