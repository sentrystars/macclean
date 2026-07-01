import Foundation

extension FileManager {
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

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

    func safeRemoveItem(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }

    func trashSize() -> Int64 {
        let home = URL.homeDirectory
        let trashURL = home.appendingPathComponent(".Trash")
        guard fileExists(atPath: trashURL.path) else { return 0 }
        return directorySize(at: trashURL)
    }

    func applicationSupportPath(for appName: String) -> URL {
        URL.homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent(appName)
    }
}
