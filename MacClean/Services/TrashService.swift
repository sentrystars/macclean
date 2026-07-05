import Foundation

actor TrashService {
    private let fileManager = FileManager.default

    func getTrashSize() -> Int64 {
        fileManager.trashSize()
    }

    func getTrashContents() async -> [ScanItem] {
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? URL.homeDirectory.appendingPathComponent(AppConstants.trashPath)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: trashURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        ) else {
            // Fallback: use ls to list trash contents
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/ls")
            task.arguments = ["-1a", trashURL.path]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try? task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            let names = output.split(separator: "\n").map(String.init).filter { $0 != "." && $0 != ".." }
            return names.compactMap { name -> ScanItem? in
                let url = trashURL.appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }
                let size = isDir.boolValue
                    ? fileManager.directorySize(at: url, skipPackageDescendants: false)
                    : ((try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0)
                let modDate = (try? fileManager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
                return ScanItem(
                    url: url,
                    category: .trash,
                    subcategory: name,
                    sizeBytes: size,
                    isDirectory: isDir.boolValue,
                    lastModified: modDate
                )
            }
        }

        return contents.compactMap { url -> ScanItem? in
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }

            // For directories, use du-based recursive size; for files, use direct attribute
            let size: Int64
            if isDir.boolValue {
                size = fileManager.directorySize(at: url, skipPackageDescendants: false)
            } else {
                size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            }

            let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

            return ScanItem(
                url: url,
                category: .trash,
                subcategory: url.lastPathComponent,
                sizeBytes: size,
                isDirectory: isDir.boolValue,
                lastModified: modDate
            )
        }
        .sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func emptyTrash() async throws -> CleanupResult {
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? URL.homeDirectory.appendingPathComponent(AppConstants.trashPath)
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
            let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
                ?? URL.homeDirectory.appendingPathComponent(AppConstants.trashPath)
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
