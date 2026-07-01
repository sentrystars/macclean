import Foundation

actor TrashService {
    private let fileManager = FileManager.default

    func getTrashSize() -> Int64 {
        fileManager.trashSize()
    }

    func getTrashContents() -> [URL] {
        let trashURL = URL.homeDirectory.appendingPathComponent(AppConstants.trashPath)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        ) else { return [] }
        return contents
    }

    func emptyTrash() async throws -> CleanupResult {
        let trashURL = URL.homeDirectory.appendingPathComponent(AppConstants.trashPath)
        guard fileManager.fileExists(atPath: trashURL.path) else {
            return CleanupResult(category: .trash, bytesFreed: 0, itemsRemoved: 0)
        }

        let size = fileManager.trashSize()

        // Remove all items in trash
        let contents = try fileManager.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: nil
        )
        for url in contents {
            try? fileManager.removeItem(at: url)
        }

        return CleanupResult(
            category: .trash,
            bytesFreed: size,
            itemsRemoved: contents.count
        )
    }

    func secureEmptyTrash() async throws -> CleanupResult {
        // For secure empty, we use `srm` if available, otherwise fall back to standard
        if Process.commandExists("srm") {
            let trashURL = URL.homeDirectory.appendingPathComponent(AppConstants.trashPath)
            let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)
            let size = fileManager.trashSize()

            for url in contents {
                _ = try? await Process.runAsync(executable: "/usr/bin/srm", arguments: ["-rf", url.path])
            }

            return CleanupResult(
                category: .trash,
                bytesFreed: size,
                itemsRemoved: contents.count
            )
        } else {
            return try await emptyTrash()
        }
    }
}
