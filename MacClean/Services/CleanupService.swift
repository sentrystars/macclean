import Foundation

actor CleanupService {
    private let fileManager = FileManager.default
    private var isCancelled = false

    func cancel() { isCancelled = true }

    // MARK: - Remove Items
    func removeItems(_ items: [ScanItem]) -> AsyncStream<CleanProgress> {
        AsyncStream { continuation in
            Task {
                let total = items.count
                var cleaned = 0
                var freed: Int64 = 0
                var errors: [String] = []

                for item in items {
                    if self.isCancelled { break }

                    let progress = CleanProgress(
                        phase: "Cleaning \(item.subcategory ?? item.category.displayName)...",
                        currentItem: item.url.lastPathComponent,
                        itemsCleaned: cleaned,
                        totalItems: total,
                        bytesFreed: freed
                    )
                    continuation.yield(progress)

                    do {
                        let size = item.sizeBytes
                        try self.fileManager.safeRemoveItem(at: item.url)
                        freed += size
                        cleaned += 1
                    } catch {
                        errors.append("\(item.url.lastPathComponent): \(error.localizedDescription)")
                        cleaned += 1
                    }
                }

                continuation.yield(CleanProgress(
                    phase: "Complete",
                    currentItem: "",
                    itemsCleaned: cleaned,
                    totalItems: total,
                    bytesFreed: freed
                ))
                continuation.finish()
            }
        }
    }

    // MARK: - Claude VM (keep .zst)
    func cleanClaudeVM() async throws -> CleanupResult {
        let vmBundle = URL.homeDirectory.appendingPathComponent(AppConstants.claudeVMBundle)
        guard fileManager.fileExists(atPath: vmBundle.path) else {
            return CleanupResult(category: .claudeVM, bytesFreed: 0, itemsRemoved: 0)
        }

        var freed: Int64 = 0
        var removed = 0

        for img in ["rootfs.img", "sessiondata.img"] {
            let imgPath = vmBundle.appendingPathComponent(img)
            guard fileManager.fileExists(atPath: imgPath.path) else { continue }

            // Check .zst exists before removing rootfs.img
            if img == "rootfs.img" {
                let zstPath = vmBundle.appendingPathComponent("rootfs.img.zst")
                guard fileManager.fileExists(atPath: zstPath.path) else { continue }
            }

            let attrs = try? fileManager.attributesOfItem(atPath: imgPath.path)
            let size = attrs?[.size] as? Int64 ?? 0
            try fileManager.safeRemoveItem(at: imgPath)
            freed += size
            removed += 1
        }

        return CleanupResult(
            category: .claudeVM,
            bytesFreed: freed,
            itemsRemoved: removed
        )
    }

    // MARK: - iOS Simulators
    func cleanIOSSimulators() async throws -> CleanupResult {
        guard Process.commandExists("xcrun") else {
            return CleanupResult(category: .iosSimulators, bytesFreed: 0, itemsRemoved: 0)
        }

        let simPath = URL.homeDirectory.appendingPathComponent(AppConstants.coreSimulator)
        let beforeSize = fileManager.directorySize(at: simPath)

        _ = try? await Process.runAsync(executable: "/usr/bin/xcrun", arguments: ["simctl", "delete", "unavailable"])

        let afterSize = fileManager.directorySize(at: simPath)
        let freed = beforeSize - afterSize

        return CleanupResult(
            category: .iosSimulators,
            bytesFreed: max(0, freed),
            itemsRemoved: freed > 0 ? 1 : 0
        )
    }

    // MARK: - Flush DNS
    func flushDNSCache() async throws -> CleanupResult {
        _ = try? await Process.runAsync(executable: "/usr/bin/dscacheutil", arguments: ["-flushcache"])
        _ = try? await Process.runAsync(executable: "/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])

        return CleanupResult(
            category: .dnsCache,
            bytesFreed: 0,
            itemsRemoved: 1
        )
    }
}
