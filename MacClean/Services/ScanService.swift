import Foundation

actor ScanService {
    private let fileManager = FileManager.default
    private var isCancelled = false

    func cancel() { isCancelled = true }

    // MARK: - Core Scanning
    func scanPath(
        _ url: URL,
        category: CleanupCategory,
        subcategory: String? = nil
    ) -> AsyncStream<ScanItem> {
        AsyncStream { continuation in
            guard !self.isCancelled else {
                continuation.finish()
                return
            }

            guard fileManager.fileExists(atPath: url.path) else {
                continuation.finish()
                return
            }

            // For directories, scan children
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
                continuation.finish()
                return
            }

            if isDir.boolValue {
                self.scanDirectory(url, category: category, subcategory: subcategory) { item in
                    if !self.isCancelled {
                        continuation.yield(item)
                    }
                }
            } else {
                let attrs = try? fileManager.attributesOfItem(atPath: url.path)
                let size = attrs?[.size] as? Int64 ?? 0
                let modDate = attrs?[.modificationDate] as? Date
                let item = ScanItem(
                    url: url,
                    category: category,
                    subcategory: subcategory,
                    sizeBytes: size,
                    isDirectory: false,
                    lastModified: modDate
                )
                if !self.isCancelled {
                    continuation.yield(item)
                }
            }
            continuation.finish()
        }
    }

    private func scanDirectory(
        _ url: URL,
        category: CleanupCategory,
        subcategory: String?,
        yield: (ScanItem) -> Void
    ) {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        var totalSize: Int64 = 0
        var fileCount = 0

        for case let fileURL as URL in enumerator {
            if isCancelled { return }
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let fileSize = resourceValues.fileSize
            else { continue }

            totalSize += Int64(fileSize)
            fileCount += 1
        }

        if totalSize > 0 {
            let item = ScanItem(
                url: url,
                category: category,
                subcategory: subcategory,
                sizeBytes: totalSize,
                isDirectory: true,
                lastModified: (try? fileManager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            )
            yield(item)
        }
    }

    // MARK: - User Caches
    func scanUserCaches() -> AsyncStream<ScanItem> {
        scanPath(
            URL.homeDirectory.appendingPathComponent(AppConstants.userCachePath),
            category: .userCaches
        )
    }

    // MARK: - User Logs
    func scanUserLogs() -> AsyncStream<ScanItem> {
        scanPath(
            URL.homeDirectory.appendingPathComponent(AppConstants.userLogsPath),
            category: .userLogs
        )
    }

    // MARK: - App Caches
    func scanAppCaches() async -> [ScanItem] {
        var items: [ScanItem] = []

        // Claude
        let claudePath = URL.homeDirectory.appendingPathComponent(AppConstants.claudeAppSupport)
        items += await scanAppCacheDir(claudePath, appName: "Claude-3p", category: .appCaches)

        // OpenAI Atlas
        let atlasPath = URL.homeDirectory.appendingPathComponent(AppConstants.openaiAtlas)
        items += await scanAppCacheDir(atlasPath, appName: "OpenAI Atlas", category: .appCaches)

        // Codex
        let codexPath = URL.homeDirectory.appendingPathComponent(AppConstants.codex)
        items += await scanAppCacheDir(codexPath, appName: "Codex", category: .appCaches)

        // Windsurf
        let windsurfPath = URL.homeDirectory.appendingPathComponent(AppConstants.windsurf)
        items += await scanAppCacheDir(windsurfPath, appName: "Windsurf", category: .appCaches)

        // VS Code
        let vscodePath = URL.homeDirectory.appendingPathComponent(AppConstants.vscode)
        items += await scanAppCacheDir(vscodePath, appName: "VS Code", category: .appCaches)

        // Bilibili
        let bilibiliPath = URL.homeDirectory.appendingPathComponent(AppConstants.bilibili)
        items += await scanAppCacheDir(bilibiliPath, appName: "Bilibili", category: .appCaches)

        // Brave
        let bravePath = URL.homeDirectory.appendingPathComponent(AppConstants.brave)
        items += await scanAppCacheDir(bravePath, appName: "Brave", category: .appCaches)

        // Chrome
        let chromePath = URL.homeDirectory.appendingPathComponent(AppConstants.chrome)
        items += await scanAppCacheDir(chromePath, appName: "Chrome", category: .appCaches)

        return items
    }

    private func scanAppCacheDir(_ path: URL, appName: String, category: CleanupCategory) async -> [ScanItem] {
        guard fileManager.fileExists(atPath: path.path) else { return [] }

        // Look for common cache subdirectories
        let cacheDirs = ["Cache", "Caches", "GPUCache", "Code Cache", "DawnWebGPUCache", "DawnGraphiteCache",
                         "CachedData", "browser-data", "Default"]

        var items: [ScanItem] = []
        for dirName in cacheDirs {
            let dirPath = path.appendingPathComponent(dirName)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: dirPath.path, isDirectory: &isDir), isDir.boolValue {
                let size = fileManager.directorySize(at: dirPath)
                if size > 0 {
                    items.append(ScanItem(
                        url: dirPath,
                        category: category,
                        subcategory: appName,
                        sizeBytes: size,
                        isDirectory: true
                    ))
                }
            }
        }
        return items
    }

    // MARK: - Claude VM
    func scanClaudeVM() async -> [ScanItem] {
        let vmBundle = URL.homeDirectory.appendingPathComponent(AppConstants.claudeVMBundle)
        guard fileManager.fileExists(atPath: vmBundle.path) else { return [] }

        var items: [ScanItem] = []
        for img in ["rootfs.img", "sessiondata.img"] {
            let imgPath = vmBundle.appendingPathComponent(img)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: imgPath.path, isDirectory: &isDir), !isDir.boolValue {
                let attrs = try? fileManager.attributesOfItem(atPath: imgPath.path)
                let size = attrs?[.size] as? Int64 ?? 0
                if size > 0 {
                    items.append(ScanItem(
                        url: imgPath,
                        category: .claudeVM,
                        subcategory: "Claude VM",
                        sizeBytes: size,
                        isDirectory: false
                    ))
                }
            }
        }
        return items
    }

    // MARK: - Xcode Data
    func scanXcodeData() async -> [ScanItem] {
        var items: [ScanItem] = []

        let paths: [(String, String)] = [
            (AppConstants.xcodeDerivedData, "DerivedData"),
            (AppConstants.xcodeDeviceSupport, "Device Support"),
            (AppConstants.xcodeArchives, "Archives"),
        ]

        for (relativePath, label) in paths {
            let fullPath = URL.homeDirectory.appendingPathComponent(relativePath)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath.path, isDirectory: &isDir), isDir.boolValue {
                let size = fileManager.directorySize(at: fullPath)
                if size > 0 {
                    items.append(ScanItem(
                        url: fullPath,
                        category: .xcodeData,
                        subcategory: label,
                        sizeBytes: size,
                        isDirectory: true
                    ))
                }
            }
        }

        // CoreSimulator size
        let simPath = URL.homeDirectory.appendingPathComponent(AppConstants.coreSimulator)
        if fileManager.fileExists(atPath: simPath.path) {
            let size = fileManager.directorySize(at: simPath)
            if size > 0 {
                items.append(ScanItem(
                    url: simPath,
                    category: .iosSimulators,
                    subcategory: "Simulators",
                    sizeBytes: size,
                    isDirectory: true
                ))
            }
        }

        return items
    }

    // MARK: - Container Caches
    func scanContainerCaches() -> AsyncStream<ScanItem> {
        AsyncStream { continuation in
            Task {
                let containersPath = URL.homeDirectory
                    .appendingPathComponent(AppConstants.containersPath)
                guard let containers = try? fileManager.contentsOfDirectory(
                    at: containersPath,
                    includingPropertiesForKeys: nil
                ) else {
                    continuation.finish()
                    return
                }

                for container in containers {
                    if self.isCancelled { break }
                    let cacheDirs = [
                        "Data/Library/Caches",
                        "Data/Library/tmp",
                        "Data/tmp"
                    ]
                    for sub in cacheDirs {
                        let cachePath = container.appendingPathComponent(sub)
                        var isDir: ObjCBool = false
                        if fileManager.fileExists(atPath: cachePath.path, isDirectory: &isDir), isDir.boolValue {
                            let size = fileManager.directorySize(at: cachePath)
                            if size > 0 {
                                let item = ScanItem(
                                    url: cachePath,
                                    category: .containerCaches,
                                    subcategory: container.lastPathComponent,
                                    sizeBytes: size,
                                    isDirectory: true
                                )
                                continuation.yield(item)
                            }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Trash
    func scanTrash() async -> ScanItem? {
        let trashURL = URL.homeDirectory.appendingPathComponent(AppConstants.trashPath)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: trashURL.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        let size = fileManager.directorySize(at: trashURL)
        return ScanItem(
            url: trashURL,
            category: .trash,
            sizeBytes: size,
            isDirectory: true
        )
    }
}
