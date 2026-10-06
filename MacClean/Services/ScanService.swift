import Foundation
import os

/// 扫描服务。
///
/// 与旧实现的关键差异：
/// - 不再是 actor：取消状态用 OSAllocatedUnfairLock 保护，重活在 detached 任务里跑，
///   因此 cancel() 能立即生效，且不会阻塞任何 actor；
/// - 只产出细粒度条目（按应用/项目分组），不再把 ~/Library/Caches 这类大目录聚合成一条；
/// - 每个条目在产出前先过 CleanupPolicy，策略不允许的路径根本不会出现在结果里；
/// - 废纸篓产出的是内容，不是 .Trash 目录本身。
final class ScanService: Sendable {

    private let cancelFlag = OSAllocatedUnfairLock(initialState: false)

    func cancel() { cancelFlag.withLock { $0 = true } }
    func resetCancellation() { cancelFlag.withLock { $0 = false } }
    var isCancelled: Bool { cancelFlag.withLock { $0 } }

    private var fileManager: FileManager { .default }

    // MARK: - 流构造

    private func stream(
        _ work: @escaping @Sendable (AsyncStream<ScanItem>.Continuation) async -> Void
    ) -> AsyncStream<ScanItem> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task.detached(priority: .userInitiated) {
                await work(continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @discardableResult
    private func emit(_ items: [ScanItem], to continuation: AsyncStream<ScanItem>.Continuation) -> Bool {
        for item in items {
            if isCancelled { return false }
            continuation.yield(item)
        }
        return true
    }

    // MARK: - 通用工具

    private func childURLs(of directory: URL) -> [URL] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return children.filter { !CleanupPolicy.isSymbolicLink($0) }
    }

    private func size(of url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if isDirectory.boolValue {
            return fileManager.directorySize(at: url)
        }
        return (try? fileManager.attributesOfItem(atPath: url.path))?[.size] as? Int64 ?? 0
    }

    private func item(
        for url: URL,
        category: CleanupCategory,
        subcategory: String? = nil,
        size overrideSize: Int64? = nil,
        riskLevel: RiskLevel? = nil,
        isRemovable: Bool = true,
        notRemovableReason: String? = nil,
        lastModified: Date? = nil,
        requirePositiveSize: Bool = true,
        policy: (URL) -> PolicyDecision = CleanupPolicy.evaluate
    ) -> ScanItem? {
        let decision = policy(url)
        guard decision.isAllowed else {
            AppLog.denied(url.path, reason: decision.reason ?? "policy")
            return nil
        }
        let bytes = overrideSize ?? size(of: url)
        if requirePositiveSize && bytes <= 0 { return nil }
        var isDirectory: ObjCBool = false
        _ = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        let modified = lastModified
            ?? (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        return ScanItem(
            url: url,
            category: category,
            subcategory: subcategory,
            sizeBytes: bytes,
            isDirectory: isDirectory.boolValue,
            lastModified: modified,
            isSelected: (riskLevel ?? category.riskLevel) == .safe,
            riskLevel: riskLevel,
            isRemovable: isRemovable,
            notRemovableReason: notRemovableReason,
            requiresPrivilege: decision.requiresPrivilege
        )
    }

    private func childItems(
        of directory: URL,
        category: CleanupCategory,
        subcategoryPrefix: String? = nil,
        riskLevel: RiskLevel? = nil,
        requirePositiveSize: Bool = true,
        filter: (URL) -> Bool = { _ in true }
    ) -> [ScanItem] {
        childURLs(of: directory).compactMap { child in
            guard filter(child) else { return nil }
            let name = subcategoryPrefix.map { prefix in prefix + "/" + child.lastPathComponent } ?? child.lastPathComponent
            return item(for: child, category: category, subcategory: name, riskLevel: riskLevel, requirePositiveSize: requirePositiveSize)
        }
    }

    // MARK: - 用户缓存 / 日志

    func scanUserCaches() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let root = URL(fileURLWithPath: CleanupPolicy.home("Library/Caches"))
            guard !isCancelled else { return }
            emit(childItems(of: root, category: .userCaches), to: continuation)
        }
    }

    func scanUserLogs() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let root = URL(fileURLWithPath: CleanupPolicy.home("Library/Logs"))
            guard !isCancelled else { return }
            emit(childItems(of: root, category: .userLogs), to: continuation)
        }
    }

    // MARK: - 应用缓存（只取缓存叶子，绝不碰配置目录）

    func scanAppCaches() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            for anchor in AppConstants.appCacheAnchors {
                if isCancelled { return }
                let anchorURL = URL(fileURLWithPath: CleanupPolicy.home(anchor.path))
                guard fileManager.fileExists(atPath: anchorURL.path) else { continue }
                let leaves = cacheLeaves(under: anchorURL, maxDepth: 3, appName: anchor.name)
                if !emit(leaves, to: continuation) { return }
            }
        }
    }

    /// 深度受限地查找缓存叶子目录：命中 allowedCacheLeafNames 即收录且不再下探。
    private func cacheLeaves(under root: URL, maxDepth: Int, appName: String) -> [ScanItem] {
        var results: [ScanItem] = []
        var queue: [(URL, Int)] = [(root, 0)]

        while let entry = queue.popLast() {
            if isCancelled { break }
            let (directory, depth) = entry
            guard depth < maxDepth else { continue }
            for child in childURLs(of: directory) {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: child.path, isDirectory: &isDirectory) else { continue }
                let name = child.lastPathComponent.lowercased()
                if isDirectory.boolValue, CleanupPolicy.allowedCacheLeafNames.contains(name) {
                    if let scanItem = item(
                        for: child,
                        category: .appCaches,
                        subcategory: appName + " / " + child.lastPathComponent
                    ) {
                        results.append(scanItem)
                    }
                } else if isDirectory.boolValue {
                    queue.append((child, depth + 1))
                }
            }
        }
        return results
    }

    // MARK: - 容器缓存

    func scanContainerCaches() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let containers = URL(fileURLWithPath: CleanupPolicy.home("Library/Containers"))
            for container in childURLs(of: containers) {
                if isCancelled { return }
                let appName = container.lastPathComponent
                for relative in ["Data/Library/Caches", "Data/Library/tmp", "Data/tmp"] {
                    let directory = container.appendingPathComponent(relative)
                    guard fileManager.fileExists(atPath: directory.path) else { continue }
                    let items = childItems(of: directory, category: .containerCaches, subcategoryPrefix: appName)
                    if !emit(items, to: continuation) { return }
                }
            }
        }
    }

    // MARK: - Claude VM

    func scanClaudeVM() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let bundle = URL(fileURLWithPath: CleanupPolicy.home(AppConstants.claudeVMBundle))
            guard fileManager.fileExists(atPath: bundle.path) else { return }
            var items: [ScanItem] = []
            for image in ["rootfs.img", "sessiondata.img"] {
                let url = bundle.appendingPathComponent(image)
                guard fileManager.fileExists(atPath: url.path) else { continue }
                if let scanItem = item(
                    for: url,
                    category: .claudeVM,
                    subcategory: "Claude VM / " + image,
                    riskLevel: .caution
                ) {
                    items.append(scanItem)
                }
            }
            emit(items, to: continuation)
        }
    }

    // MARK: - Xcode / 模拟器

    func scanXcodeData() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let derived = URL(fileURLWithPath: CleanupPolicy.home(AppConstants.xcodeDerivedData))
            if fileManager.fileExists(atPath: derived.path) {
                let items = childItems(of: derived, category: .xcodeData, subcategoryPrefix: "DerivedData")
                if !emit(items, to: continuation) { return }
            }

            let deviceSupport = URL(fileURLWithPath: CleanupPolicy.home(AppConstants.xcodeDeviceSupport))
            if fileManager.fileExists(atPath: deviceSupport.path) {
                let items = childItems(of: deviceSupport, category: .xcodeData, subcategoryPrefix: "Device Support")
                if !emit(items, to: continuation) { return }
            }

            // Archives 是用户归档产物：标记为高风险，默认不勾选
            let archives = URL(fileURLWithPath: CleanupPolicy.home(AppConstants.xcodeArchives))
            if fileManager.fileExists(atPath: archives.path) {
                let items = childItems(
                    of: archives,
                    category: .xcodeData,
                    subcategoryPrefix: "Archives",
                    riskLevel: .warning
                )
                if !emit(items, to: continuation) { return }
            }
        }
    }

    // MARK: - 系统数据

    func scanSystemData(options: CleanupOptions = .standard) -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let systemCaches = URL(fileURLWithPath: "/Library/Caches")
            if fileManager.fileExists(atPath: systemCaches.path) {
                if !emit(childItems(of: systemCaches, category: .systemCaches), to: continuation) { return }
            }

            let systemLogs = URL(fileURLWithPath: "/Library/Logs")
            if fileManager.fileExists(atPath: systemLogs.path) {
                if !emit(childItems(of: systemLogs, category: .systemLogs), to: continuation) { return }
            }

            let varTmp = URL(fileURLWithPath: "/private/var/tmp")
            if fileManager.fileExists(atPath: varTmp.path) {
                if !emit(tempItems(in: varTmp, maxAgeDays: options.tempMaxAgeDays), to: continuation) { return }
            }

            let backups = URL(fileURLWithPath: CleanupPolicy.home(AppConstants.iOSBackupPath))
            if fileManager.fileExists(atPath: backups.path) {
                let items = childItems(of: backups, category: .systemData, subcategoryPrefix: "iOS Backups", riskLevel: .caution)
                if !emit(items, to: continuation) { return }
            }

            // 睡眠镜像由系统管理，仅展示不可删除
            let sleepImage = URL(fileURLWithPath: "/private/var/vm/sleepimage")
            if fileManager.fileExists(atPath: sleepImage.path) {
                if let infoOnly = item(
                    for: sleepImage,
                    category: .systemData,
                    subcategory: "Sleep Image",
                    riskLevel: .warning,
                    isRemovable: false,
                    notRemovableReason: "由系统管理，App 不支持删除"
                ) {
                    if !emit([infoOnly], to: continuation) { return }
                }
            }
        }
    }

    private func tempItems(in directory: URL, maxAgeDays: Int) -> [ScanItem] {
        let cutoff = Date().addingTimeInterval(-Double(max(1, maxAgeDays)) * 86_400)
        return childItems(of: directory, category: .systemTemp) { url in
            guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                return false
            }
            return modified < cutoff
        }
    }

    // MARK: - macOS 系统

    func scanMacOSSystem() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let cutoff = Date().addingTimeInterval(-7 * 86_400)
            let roots = [
                URL(fileURLWithPath: "/Library/Logs/DiagnosticReports"),
                URL(fileURLWithPath: CleanupPolicy.home("Library/Logs/DiagnosticReports")),
            ]
            for root in roots {
                guard fileManager.fileExists(atPath: root.path) else { continue }
                let items = childItems(of: root, category: .macOSSystem, subcategoryPrefix: "Diagnostic Reports") { url in
                    guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                        return false
                    }
                    return modified < cutoff
                }
                if !emit(items, to: continuation) { return }
            }
        }
    }

    // MARK: - 废纸篓（内容，而非目录）

    func scanTrash() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            let trash = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: CleanupPolicy.home(AppConstants.trashPath))
            guard fileManager.fileExists(atPath: trash.path) else { return }
            let items = childItems(of: trash, category: .trash, requirePositiveSize: false)
            emit(items, to: continuation)
        }
    }

    // MARK: - 开发者缓存

    /// 扫描开发者缓存（npm / pnpm / uv / Gradle / Cargo / CoreSimulator Caches ...）。
    func scanDeveloperCaches() -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            for entry in DeveloperCacheCatalog.entries {
                if isCancelled { return }
                for url in entry.urls {
                    guard fileManager.fileExists(atPath: url.path) else { continue }
                    guard let scanItem = item(
                        for: url,
                        category: .developerCaches,
                        subcategory: entry.tool,
                        riskLevel: entry.riskLevel,
                        requirePositiveSize: false,
                        policy: CleanupPolicy.evaluateDeveloperCache
                    ) else { continue }
                    if !emit([scanItem], to: continuation) { return }
                }
            }
        }
    }

    // MARK: - 大文件

    func scanLargeFiles(
        under roots: [URL],
        minimumSize: Int64,
        limit: Int = 200
    ) -> AsyncStream<ScanItem> {
        stream { [self] continuation in
            var found: [ScanItem] = []
            for root in roots {
                if isCancelled { return }
                guard let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                while let fileURL = enumerator.nextObject() as? URL {
                    if isCancelled { return }
                    guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey]),
                          values.isRegularFile == true,
                          let fileSize = values.fileSize,
                          Int64(fileSize) >= minimumSize
                    else { continue }
                    // 大文件位于用户标准文件夹，使用对应的策略（否则永远扫不出结果）
                    guard CleanupPolicy.evaluateUserSelectedFile(fileURL).isAllowed else { continue }
                    found.append(ScanItem(
                        url: fileURL,
                        category: .systemData,
                        subcategory: fileURL.lastPathComponent,
                        sizeBytes: Int64(fileSize),
                        isDirectory: false,
                        lastModified: values.contentModificationDate,
                        isSelected: false,
                        riskLevel: .caution
                    ))
                    if found.count >= limit { break }
                }
            }
            emit(found.sorted { $0.sizeBytes > $1.sizeBytes }, to: continuation)
        }
    }
}